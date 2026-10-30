#!/usr/bin/env bash
# =============================================================================
# 01-ecr-build-push.sh
# Cria os 5 repositórios no ECR (com scan de vulnerabilidades no push),
# faz o build das imagens Docker de cada microsserviço e as publica (push)
# com a tag definida em $IMAGE_TAG.
# Uso: source infra/cloud.env && scripts/01-ecr-build-push.sh
# =============================================================================

# 'set -e' aborta o script ao primeiro erro; '-u' trata variável não definida como erro;
# 'pipefail' faz um pipe falhar se QUALQUER comando dele falhar (não só o último).
set -euo pipefail

# Exige que as 3 variáveis existam. A sintaxe ${VAR:?mensagem} encerra o script
# com a mensagem se a variável estiver vazia/indefinida. O ':' é um comando "nada a fazer"
# que só serve para avaliar as expansões ${...} ao lado.
: "${AWS_ACCOUNT_ID:?rode: source infra/cloud.env}" "${AWS_REGION:?}" "${IMAGE_TAG:?}"

# Vai para a raiz do projeto (a pasta acima de scripts/), para os caminhos "services/..."
# funcionarem independente de onde o script foi chamado. $0 é o caminho do próprio script.
cd "$(dirname "$0")/.."

# Monta o endereço do registro privado do ECR: <conta>.dkr.ecr.<regiao>.amazonaws.com
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Lista dos 5 microsserviços (cada um tem uma pasta em services/ com seu Dockerfile).
SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

# Autentica o Docker no ECR: pega uma senha temporária da AWS e a passa ao 'docker login'
# via stdin (--password-stdin evita que a senha apareça no histórico/processos).
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

# Percorre cada serviço criando o repositório (se faltar), buildando e publicando a imagem.
for svc in $SERVICES; do
  echo "==> $svc"
  # Se o repositório já existe (describe-repositories tem sucesso), não faz nada.
  # Se NÃO existe (o '||' dispara), cria o repositório com:
  #   - scanOnPush=true  -> toda imagem publicada é escaneada por CVEs automaticamente;
  #   - MUTABLE          -> permite sobrescrever uma mesma tag (ex.: :v1) durante o lab;
  #   - AES256           -> imagens criptografadas em repouso no ECR.
  aws ecr describe-repositories --repository-names "$svc" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$svc" --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --image-tag-mutability MUTABLE \
      --encryption-configuration encryptionType=AES256 >/dev/null
  # Os nós do EKS são x86_64 (m7i-flex.large). --platform linux/amd64 garante a arquitetura certa
  # mesmo se o build for feito num Mac Apple Silicon (ARM), evitando "exec format error".
  docker build --platform linux/amd64 -t "$REGISTRY/$svc:$IMAGE_TAG" "services/$svc"
  # Envia a imagem para o repositório ECR correspondente.
  docker push "$REGISTRY/$svc:$IMAGE_TAG"
done

# Lista no final as 5 imagens publicadas (útil para conferir as tags antes do deploy).
echo "Imagens publicadas:"; for svc in $SERVICES; do echo "  $REGISTRY/$svc:$IMAGE_TAG"; done
