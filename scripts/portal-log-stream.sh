#!/usr/bin/env bash
# Envia ao geapp-portal, a cada 2s, os bytes novos de um arquivo de log, ate
# existir "<log>.done". Cada lote leva um `seq` crescente: se um POST falha, o
# mesmo lote e reenviado no proximo ciclo e o portal ignora duplicados.
#
# Uso: portal-log-stream.sh <arquivo-de-log>
# Requer: PORTAL_URL, RUN_ID e o job com `permissions: id-token: write`.
set -uo pipefail

LOG="$1"
CHUNK="$LOG.chunk"
MAX_BYTES=200000 # abaixo do limite de 256 KiB por lote no portal
SEQ=0
OFFSET=0

oidc_token() {
  curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$PORTAL_URL" | jq -r .value
}

send_pending() {
  local size
  size=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  while ((size > OFFSET)); do
    local n=$((size - OFFSET))
    ((n > MAX_BYTES)) && n=$MAX_BYTES
    # ponytail: corta por bytes, entao um caractere multibyte pode ser partido entre
    # lotes e virar U+FFFD; a saida do terraform com -no-color e quase toda ASCII.
    tail -c +$((OFFSET + 1)) "$LOG" | head -c "$n" >"$CHUNK"
    local token
    token=$(oidc_token) || return 0
    if jq -n --argjson seq "$SEQ" --rawfile body "$CHUNK" '{seq: $seq, body: $body}' |
      curl -sSf -o /dev/null -X POST \
        -H "Authorization: Bearer $token" -H 'content-type: application/json' \
        --data-binary @- "$PORTAL_URL/api/provisioning/runs/$RUN_ID/logs"; then
      OFFSET=$((OFFSET + n))
      SEQ=$((SEQ + 1))
    else
      return 0 # portal fora do ar: tenta de novo no proximo ciclo, sem perder linhas
    fi
  done
}

while [ ! -f "$LOG.done" ]; do
  send_pending
  sleep 2
done
send_pending
