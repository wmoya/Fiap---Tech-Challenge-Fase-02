#!/usr/bin/env bash
# =============================================================================
# 06-deploy-k8s.sh
# Aplica TODOS os manifestos no cluster, na ordem correta de dependência:
# namespaces -> secrets -> configmaps -> jobs de criação de tabela -> deployments
# e services -> ingress -> escalabilidade (HPA e KEDA).
# Uso: source infra/cloud.env && scripts/06-deploy-k8s.sh
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Vai para a raiz do projeto (caminhos "k8s/..." e "scripts/...").
cd "$(dirname "$0")/.."

# Exige as variáveis necessárias para renderizar os manifestos (ver render.sh).
: "${AWS_ACCOUNT_ID:?rode: source infra/cloud.env}" "${AWS_REGION:?}" "${IMAGE_TAG:?}" "${AWS_SQS_URL:?}"

# Atalho: renderiza um manifesto (troca os placeholders) e aplica no cluster.
apply() { scripts/render.sh "$1" | kubectl apply -f -; }

# 1) Namespaces (um por serviço, com Pod Security 'restricted'). Precisam existir antes de tudo.
echo "==> Namespaces"; apply k8s/00-namespaces.yaml

# 2) Secrets já gerados pelo 05-gerar-secrets.sh (pasta k8s/generated/). Aplicados direto,
#    sem render (não têm placeholder).
echo "==> Secrets";    kubectl apply -f k8s/generated/

# 3) ConfigMaps de cada serviço (URLs internas, nomes de tabela etc.).
for d in 01-auth 02-flag 03-targeting 04-evaluation 05-analytics; do
  echo "==> $d: ConfigMap"; apply k8s/$d/configmap.yaml
done

# 4) Jobs que criam as tabelas nos 3 bancos RDS (auth, flag, targeting) antes de subir as apps.
echo "==> Criando tabelas nos 3 RDS (Jobs)"
for d in 01-auth 02-flag 03-targeting; do apply k8s/$d/db-init-job.yaml; done
# Espera cada Job terminar (condition=complete) com limite de 180s, para garantir que o
# schema existe antes do Deployment correspondente tentar conectar.
kubectl wait --for=condition=complete job/auth-service-db-init      -n togglemaster-auth      --timeout=180s
kubectl wait --for=condition=complete job/flag-service-db-init      -n togglemaster-flag      --timeout=180s
kubectl wait --for=condition=complete job/targeting-service-db-init -n togglemaster-targeting --timeout=180s

# 5) Deployment + Service de cada serviço (e Ingress, quando o serviço expõe rota externa).
for d in 01-auth 02-flag 03-targeting 04-evaluation 05-analytics; do
  echo "==> $d: Deployment + Service"
  apply k8s/$d/deployment.yaml
  apply k8s/$d/service.yaml
  # Nem todo serviço tem Ingress (o analytics, por ex., é interno). Só aplica se o arquivo existir.
  [ -f k8s/$d/ingress.yaml ] && apply k8s/$d/ingress.yaml
done

# 6) Escalabilidade.
echo "==> Escalabilidade"
# HPA do evaluation-service (escala por CPU). Sempre aplicado.
apply k8s/04-evaluation/hpa.yaml
# Para o analytics: se o CRD do KEDA existir no cluster, usa o ScaledObject (escala pela fila SQS, 0->N).
if kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  apply k8s/05-analytics/keda-scaledobject.yaml
else
  # Plano B (se o KEDA não estiver instalado): escala o analytics por CPU, via HPA comum.
  echo "KEDA não instalado: usando HPA por CPU no analytics-service"
  apply k8s/alternativas/analytics-hpa-cpu.yaml
fi

# Mostra todos os pods do projeto (label part-of=togglemaster) para conferir que subiram.
kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster
