#!/usr/bin/env bash
# =============================================================================
# render.sh
# Substitui os placeholders de um manifesto Kubernetes pelos valores reais do
# ambiente e imprime o resultado no stdout (não aplica nada por si só).
# É usado pelo 06-deploy-k8s.sh, que faz: render.sh <arquivo> | kubectl apply -f -
# Placeholders tratados: ${AWS_ACCOUNT_ID} ${AWS_REGION} ${IMAGE_TAG} ${AWS_SQS_URL}
# Uso: scripts/render.sh k8s/04-evaluation/deployment.yaml | kubectl apply -f -
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar (pipefail).
set -euo pipefail

# Exige que as 4 variáveis existam (senão o manifesto sairia com valores vazios/errados).
: "${AWS_ACCOUNT_ID:?}" "${AWS_REGION:?}" "${IMAGE_TAG:?}" "${AWS_SQS_URL:?}"

# 'sed' troca cada placeholder pelo valor da variável correspondente e imprime o arquivo.
#   - o \$ escapa o cifrão para o sed enxergar o texto literal "${AWS_ACCOUNT_ID}";
#   - usamos '|' como separador (em vez de '/') porque a URL da SQS contém '/';
#   - 'g' troca todas as ocorrências na linha;
#   - "$1" é o arquivo de manifesto passado como argumento.
sed -e "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" \
    -e "s|\${AWS_REGION}|${AWS_REGION}|g" \
    -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
    -e "s|\${AWS_SQS_URL}|${AWS_SQS_URL}|g" "$1"
