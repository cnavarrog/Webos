#!/usr/bin/env bash
# Crea una VM Always Free VM.Standard.A1.Flex (2 OCPU / 12 GB, Ubuntu 24.04 ARM)
# y reintenta cada 60 s en todos los ADs hasta que haya capacidad.
# Uso: ./crear-vm-a1.sh ~/.ssh/id_ed25519.pub ./oracle-cloud-init.sh
set -uo pipefail

SSH_PUB="${1:?Ruta a tu clave SSH pública (.pub)}"
CLOUD_INIT="${2:?Ruta a oracle-cloud-init.sh}"
NAME="${NAME:-vm-a1-free}"
OCPUS="${OCPUS:-2}"; MEM="${MEM:-12}"; INTERVAL="${INTERVAL:-60}"

T=$(awk -F= '/^tenancy/{gsub(/ /,"",$2);print $2;exit}' ~/.oci/config)
C="${COMPARTMENT_ID:-$T}"
echo "Región: $(awk -F= '/^region/{print $2;exit}' ~/.oci/config) | Compartment: $C"

# --- Imagen Ubuntu 24.04 ARM más reciente (reintenta: una clave API recién subida
# puede tardar unos minutos en propagarse y dar 401 intermitentes)
IMG=""
for i in $(seq 1 30); do
IMG=$(oci compute image list -c "$C" --operating-system "Canonical Ubuntu" \
  --operating-system-version "24.04" --shape VM.Standard.A1.Flex \
  --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output 2>/dev/null) && [ -n "$IMG" ] && break
echo "  esperando autenticación/imagen ($i)..."; sleep 20
done
[ -z "$IMG" ] && { echo "No encontré imagen Ubuntu 24.04 ARM"; exit 1; }
echo "Imagen: $IMG"

# --- Red: reutiliza una subred pública o crea VCN + IGW + subred
SUBNET=$(oci network subnet list -c "$C" --all \
  --query 'data[?"prohibit-public-ip-on-vnic"==`false`] | [0].id' --raw-output 2>/dev/null)
if [ -z "$SUBNET" ] || [ "$SUBNET" = "null" ]; then
  echo "Creando VCN pública..."
  VCN=$(oci network vcn create -c "$C" --cidr-blocks '["10.0.0.0/16"]' --display-name vcn-free \
    --dns-label vcnfree --wait-for-state AVAILABLE --query data.id --raw-output)
  IGW=$(oci network internet-gateway create -c "$C" --vcn-id "$VCN" --is-enabled true \
    --display-name igw-free --wait-for-state AVAILABLE --query data.id --raw-output)
  RT=$(oci network vcn get --vcn-id "$VCN" --query 'data."default-route-table-id"' --raw-output)
  oci network route-table update --rt-id "$RT" --force \
    --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW\"}]" >/dev/null
  SUBNET=$(oci network subnet create -c "$C" --vcn-id "$VCN" --cidr-block 10.0.0.0/24 \
    --display-name subnet-public --dns-label pub --wait-for-state AVAILABLE \
    --query data.id --raw-output)
fi
echo "Subred: $SUBNET"

mapfile -t ADS < <(oci iam availability-domain list -c "$T" --query 'data[].name' --raw-output | tr -d '[]", ' | grep -v '^$')
echo "ADs: ${ADS[*]}"

n=0
while :; do
  for AD in "${ADS[@]}"; do
    n=$((n+1)); echo "[$(date '+%F %T')] intento $n en $AD"
    OUT=$(oci compute instance launch -c "$C" --availability-domain "$AD" \
      --shape VM.Standard.A1.Flex --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEM}" \
      --image-id "$IMG" --subnet-id "$SUBNET" --assign-public-ip true \
      --ssh-authorized-keys-file "$SSH_PUB" --user-data-file "$CLOUD_INIT" \
      --display-name "$NAME" --wait-for-state RUNNING --query data.id --raw-output 2>&1)
    if grep -q "ocid1\.instance" <<<"$OUT"; then
      ID=$(echo "$OUT" | grep -o 'ocid1\.instance[^ ]*' | head -1)
      IP=$(oci compute instance list-vnics --instance-id "$ID" --query 'data[0]."public-ip"' --raw-output)
      echo; echo "✅ VM creada: $ID"; echo "IP pública: $IP"
      echo "SSH: ssh -i ${SSH_PUB%.pub} ubuntu@$IP"
      exit 0
    elif grep -qi "capacity" <<<"$OUT"; then echo "  sin capacidad"
    elif grep -qi "TooManyRequests" <<<"$OUT"; then echo "  rate limit, esperando más"; sleep 30
    elif grep -qiE "LimitExceeded|QuotaExceeded" <<<"$OUT"; then echo "$OUT"; echo "Límite de cuenta alcanzado (¿ya tienes otra A1?)"; exit 1
    else echo "$OUT" | tail -5
    fi
  done
  sleep "$INTERVAL"
done
