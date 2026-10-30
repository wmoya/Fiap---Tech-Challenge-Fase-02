#!/usr/bin/env bash
# =============================================================================
# 05-gerar-secrets.sh
# Gera os arquivos de Secret do Kubernetes (valores codificados em base64 no
# campo "data") a partir das variáveis do infra/cloud.env. A saída vai para
# k8s/generated/ (que está no .gitignore). NADA é aplicado no cluster aqui —
# quem aplica é o 06-deploy-k8s.sh.
# Uso: source infra/cloud.env && scripts/05-gerar-secrets.sh
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Vai para a raiz do projeto para os caminhos "k8s/..." funcionarem.
cd "$(dirname "$0")/.."

# Confere que TODAS as variáveis necessárias estão preenchidas antes de gerar nada.
# ${!v} é "expansão indireta": pega o valor da variável cujo NOME está em $v.
# Se alguma estiver vazia, explica o que fazer e encerra com erro (exit 1).
for v in DB_USER DB_PASSWORD RDS_AUTH_ENDPOINT RDS_FLAG_ENDPOINT RDS_TARGETING_ENDPOINT REDIS_URL MASTER_KEY SERVICE_API_KEY AWS_SQS_URL; do
  [ -n "${!v:-}" ] || { echo "Variável $v vazia. Preencha infra/cloud.env e rode: source infra/cloud.env"; exit 1; }
done

# Cria a pasta de saída com permissão 700 (só o dono acessa), pois conterá segredos.
OUT=k8s/generated; mkdir -p "$OUT"; chmod 700 "$OUT"

# Função auxiliar que gera um Secret. Parâmetros:
#   $1 = nome do secret | $2 = namespace | $3 = arquivo de saída | demais = --from-literal=...
gen() { # gen <nome> <namespace> <arquivo> -- --from-literal=...
  local name=$1 ns=$2 file=$3; shift 3   # guarda os 3 primeiros e descarta-os de $@
  # 'kubectl create secret ... --dry-run=client -o yaml' NÃO cria no cluster:
  # só monta o YAML (com os valores já em base64) e grava no arquivo de saída.
  kubectl create secret generic "$name" -n "$ns" "$@" --dry-run=client -o yaml > "$OUT/$file"
  # Restringe o arquivo gerado (600 = só o dono lê/escreve) e avisa o caminho.
  chmod 600 "$OUT/$file"; echo "gerado: $OUT/$file"
}

# auth-service: string de conexão do RDS do auth + chave mestra + chave de serviço.
# sslmode=require força TLS entre o pod e o banco RDS.
gen auth-service-secret togglemaster-auth auth-secret.yaml \
  --from-literal=DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${RDS_AUTH_ENDPOINT}:5432/auth_db?sslmode=require" \
  --from-literal=MASTER_KEY="${MASTER_KEY}" \
  --from-literal=SERVICE_API_KEY="${SERVICE_API_KEY}"

# flag-service: só precisa da conexão com o SEU banco (flags_db) no RDS do flag.
gen flag-service-secret togglemaster-flag flag-secret.yaml \
  --from-literal=DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${RDS_FLAG_ENDPOINT}:5432/flags_db?sslmode=require"

# targeting-service: conexão com o banco targeting_db no RDS do targeting.
gen targeting-service-secret togglemaster-targeting targeting-secret.yaml \
  --from-literal=DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${RDS_TARGETING_ENDPOINT}:5432/targeting_db?sslmode=require"

# evaluation-service (hot path): URL do Redis (cache), chave de serviço (p/ chamar flag/targeting)
# e a URL da fila SQS (para onde ele PUBLICA os eventos de avaliação).
gen evaluation-service-secret togglemaster-evaluation evaluation-secret.yaml \
  --from-literal=REDIS_URL="${REDIS_URL}" \
  --from-literal=SERVICE_API_KEY="${SERVICE_API_KEY}" \
  --from-literal=AWS_SQS_URL="${AWS_SQS_URL}"

# analytics-service (worker): só a URL da fila SQS, de onde ele CONSOME os eventos.
# (As permissões de SQS/DynamoDB vêm via IRSA, não por chave — por isso não há chave AWS aqui.)
gen analytics-service-secret togglemaster-analytics analytics-secret.yaml \
  --from-literal=AWS_SQS_URL="${AWS_SQS_URL}"
