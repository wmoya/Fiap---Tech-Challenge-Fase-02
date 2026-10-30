#!/usr/bin/env bash
# =============================================================================
# sqs-enviar-mensagens.sh
# Envia mensagens manualmente para a fila SQS, no mesmo formato que o
# analytics-service espera. Serve para encher a fila e demonstrar o KEDA
# escalando o analytics de 0 -> N pods conforme o acúmulo de mensagens.
# Uso: source infra/cloud.env && scripts/sqs-enviar-mensagens.sh [lotes]
#   (cada "lote" envia 10 mensagens de uma vez; padrão = 100 lotes = 1000 msgs)
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Exige a URL da fila e a região (vêm do infra/cloud.env).
: "${AWS_SQS_URL:?rode: source infra/cloud.env}" "${AWS_REGION:?}"

# Quantidade de lotes (1º argumento; padrão 100). Total de mensagens = LOTES * 10.
LOTES=${1:-100}

# Laço externo: um envio em lote por iteração.
for ((b=1; b<=LOTES; b++)); do
  # Começa a montar o array JSON de entradas do batch.
  ENTRIES="["
  # Laço interno: monta 10 mensagens (o máximo por send-message-batch da SQS).
  for i in $(seq 1 10); do
    # Timestamp UTC no formato ISO-8601.
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Corpo de cada mensagem (JSON). As barras \\\" produzem aspas escapadas corretamente
    # dentro da string que será, por sua vez, um JSON passado ao aws-cli.
    body="{\\\"user_id\\\":\\\"user-$b-$i\\\",\\\"flag_name\\\":\\\"enable-new-dashboard\\\",\\\"result\\\":true,\\\"timestamp\\\":\\\"$ts\\\"}"
    # Adiciona a entrada {Id, MessageBody} ao array; coloca vírgula entre elas (menos na última).
    ENTRIES+="{\"Id\":\"m$i\",\"MessageBody\":\"$body\"}"; [ $i -lt 10 ] && ENTRIES+=","
  done
  # Fecha o array JSON.
  ENTRIES+="]"
  # Envia as 10 mensagens de uma vez (1 chamada de API por lote = mais barato e rápido).
  aws sqs send-message-batch --queue-url "$AWS_SQS_URL" --region "$AWS_REGION" --entries "$ENTRIES" >/dev/null
  # Mostra o progresso na mesma linha (\r volta ao início da linha).
  printf "\rlotes enviados: %d/%d (%d mensagens)" "$b" "$LOTES" "$((b*10))"
done
echo

# Ao final, consulta quantas mensagens estão aproximadamente na fila (o KEDA usa essa métrica).
aws sqs get-queue-attributes --queue-url "$AWS_SQS_URL" --region "$AWS_REGION" \
  --attribute-names ApproximateNumberOfMessages --query Attributes --output table
