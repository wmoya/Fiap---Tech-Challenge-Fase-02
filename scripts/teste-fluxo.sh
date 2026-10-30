#!/usr/bin/env bash
# =============================================================================
# teste-fluxo.sh
# Teste de ponta a ponta do ToggleMaster. Faz o caminho completo:
#   cria API key -> cria flag -> cria regra de 50% -> avalia 10 usuários ->
#   cada avaliação gera um evento na SQS -> o analytics grava no DynamoDB.
# Uso local (docker compose):  MASTER_KEY=... scripts/teste-fluxo.sh local
# Uso na nuvem (Ingress/NLB):  MASTER_KEY=... scripts/teste-fluxo.sh <dns-do-load-balancer>
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# $1 define o alvo: "local" ou o DNS do Load Balancer (obrigatório).
ALVO=${1:?use: local  ou  <dns-do-load-balancer>}

# A MASTER_KEY (chave mestra do auth) precisa estar exportada; é a mesma do .env/cloud.env.
: "${MASTER_KEY:?exporte MASTER_KEY (a mesma do .env ou do cloud.env)}"

# Nome da flag usada no teste (pode sobrescrever via variável FLAG). Padrão: enable-new-dashboard.
FLAG=${FLAG:-enable-new-dashboard}

# Define as URLs base de cada serviço conforme o alvo:
if [ "$ALVO" = "local" ]; then
  # Local: cada serviço responde numa porta própria exposta pelo docker compose.
  AUTH=http://localhost:8001; FLAGS=http://localhost:8002; RULES=http://localhost:8003; EVAL=http://localhost:8004
else
  # Nuvem: tudo passa pelo mesmo Load Balancer/Ingress, roteado por caminho (/auth etc.).
  AUTH=http://$ALVO/auth; FLAGS=http://$ALVO; RULES=http://$ALVO; EVAL=http://$ALVO
fi

# Função auxiliar 'j': lê um JSON do stdin e imprime um campo. Ex.: j "['key']" pega o campo "key".
j() { python3 -c "import sys,json; print(json.load(sys.stdin)$1)"; }

# 1) Verifica se o auth-service está de pé (-sf: silencioso e falha em erro HTTP).
echo "1) Health do auth-service";   curl -sf "$AUTH/health"; echo

# 2) Cria uma API key usando a MASTER_KEY como Bearer; extrai o campo "key" da resposta.
echo "2) Criando API key";          KEY=$(curl -sf -X POST "$AUTH/admin/keys" -H "Content-Type: application/json" \
                                       -H "Authorization: Bearer $MASTER_KEY" -d '{"name":"demo-video"}' | j "['key']")
# Mostra só os primeiros caracteres da chave (não expor a chave inteira na tela/vídeo).
echo "   chave criada: ${KEY:0:14}... (exibindo só o início)"

# 3) Valida a chave recém-criada chamando o endpoint /validate com ela.
echo "3) Validando a chave";         curl -sf "$AUTH/validate" -H "Authorization: Bearer $KEY"; echo

# 4) Cria a flag no flag-service (habilitada), autenticando com a API key.
echo "4) Criando flag '$FLAG'"
curl -s -X POST "$FLAGS/flags" -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d "{\"name\":\"$FLAG\",\"description\":\"Novo dashboard\",\"is_enabled\":true}"; echo

# 5) Cria uma regra de segmentação de 50% (metade dos usuários recebe true) no targeting-service.
echo "5) Criando regra de 50% no targeting-service"
curl -s -X POST "$RULES/rules" -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d "{\"flag_name\":\"$FLAG\",\"is_enabled\":true,\"rules\":{\"type\":\"PERCENTAGE\",\"value\":50}}"; echo

# 6) Lista as flags cadastradas (confirma que a flag foi criada).
echo "6) Listando flags";            curl -sf "$FLAGS/flags" -H "Authorization: Bearer $KEY"; echo

# 7) Avalia 10 usuários diferentes no hot path (usa cache Redis). Cada chamada gera um evento na SQS.
echo "7) Avaliando 10 usuários (hot path com cache Redis)"
for u in $(seq 1 10); do curl -sf "$EVAL/evaluate?user_id=user-$u&flag_name=$FLAG"; echo; done

# Mensagem final orientando onde conferir o resultado assíncrono (logs do analytics + DynamoDB).
echo "Pronto. Cada avaliação gerou um evento na SQS; confira os logs do analytics-service e a tabela no DynamoDB."
