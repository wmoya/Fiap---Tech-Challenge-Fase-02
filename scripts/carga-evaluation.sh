#!/usr/bin/env bash
# =============================================================================
# carga-evaluation.sh
# Gera carga (muitas requisições) no evaluation-service para subir a CPU e,
# com isso, disparar o HPA (autoescala por CPU). Use durante a demo do vídeo.
# Uso: scripts/carga-evaluation.sh <URL-do-LoadBalancer> [segundos] [concorrência]
#   ex.: scripts/carga-evaluation.sh k8s-abc...elb.amazonaws.com 180 50
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Lê os argumentos:
#   $1 = DNS do Load Balancer (obrigatório; ${1:?...} encerra se faltar);
#   $2 = duração em segundos (padrão 180); $3 = concorrência (padrão 50).
LB=${1:?informe o DNS do Load Balancer}; DUR=${2:-180}; CONC=${3:-50}

# Monta a URL de avaliação com um usuário e uma flag fixos (o endpoint quente do serviço).
URL="http://${LB}/evaluate?user_id=user-carga&flag_name=enable-new-dashboard"

# Se o 'hey' estiver instalado no host, usa ele:
#   -z Ns -> dispara requisições por N segundos;  -c -> número de conexões simultâneas.
if command -v hey >/dev/null; then
  hey -z "${DUR}s" -c "$CONC" "$URL"
else
  # Caso o 'hey' não exista, usa a mesma ferramenta dentro de um container (sem instalar nada).
  echo "hey não encontrado; usando o container williamyeh/hey"
  docker run --rm williamyeh/hey -z "${DUR}s" -c "$CONC" "$URL"
fi
