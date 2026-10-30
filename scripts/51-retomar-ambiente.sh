#!/usr/bin/env bash
# =============================================================================
# 51-retomar-ambiente.sh
# Desfaz o 50-pausar-ambiente.sh e devolve o mesmo cenário para a gravação:
#   RDS religados -> Redis recriado (endpoint atualizado no cloud.env e nos Secrets)
#   -> nós do EKS de volta (2) -> pods reiniciados.
# Os dados dos RDS e do DynamoDB, as flags e o DNS do Load Balancer continuam os mesmos.
# Uso: source infra/cloud.env && scripts/51-retomar-ambiente.sh   (~15-20 min)
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Vai para a raiz do projeto (caminhos "infra/..." e "scripts/...").
cd "$(dirname "$0")/.."

# Exige as variáveis do laboratório.
: "${AWS_REGION:?rode: source infra/cloud.env}" "${CLUSTER_NAME:?}"

# 1) Religa os 3 RDS (em paralelo) — é a etapa mais demorada.
echo "1/5 Religando os 3 RDS"
for n in auth flag targeting; do
  aws rds start-db-instance --db-instance-identifier togglemaster-$n-db --region "$AWS_REGION" >/dev/null \
    && echo "  religando togglemaster-$n-db" || echo "  togglemaster-$n-db já estava ligado"
done

# 2) Recria o Redis com a mesma configuração do 3.5 (mesmo SG e subnet group, TLS ligado).
#    Se o apagamento do 50-pausar ainda não terminou, espera ele sumir antes de recriar.
echo "2/5 Recriando o ElastiCache"
while [ "$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --region "$AWS_REGION" \
    --query 'ReplicationGroups[0].Status' --output text 2>/dev/null)" = "deleting" ]; do sleep 20; done
if ! aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --region "$AWS_REGION" >/dev/null 2>&1; then
  REDIS_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-redis-sg \
    --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION")
  aws elasticache create-replication-group --replication-group-id togglemaster-redis \
    --replication-group-description "Cache do evaluation-service" \
    --engine redis --cache-node-type cache.t3.micro --num-cache-clusters 1 \
    --cache-subnet-group-name togglemaster-redis-subnets --security-group-ids "$REDIS_SG" \
    --transit-encryption-enabled --at-rest-encryption-enabled \
    --tags Key=project,Value=togglemaster --region "$AWS_REGION" >/dev/null
fi

# 3) Volta os nós enquanto RDS e Redis sobem (ganha tempo).
echo "3/5 Node group ng-apps -> 2 nós"
eksctl scale nodegroup --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --name ng-apps \
  --nodes 2 --nodes-min 1 --nodes-max 4 --wait

# 4) Espera RDS e Redis ficarem disponíveis e atualiza o REDIS_URL (o endpoint pode mudar
#    ao recriar). Depois regenera e aplica os Secrets com o endpoint novo.
echo "4/5 Aguardando RDS e Redis e atualizando os Secrets"
for n in auth flag targeting; do
  aws rds wait db-instance-available --db-instance-identifier togglemaster-$n-db --region "$AWS_REGION"
done
aws elasticache wait replication-group-available --replication-group-id togglemaster-redis --region "$AWS_REGION"
REDIS_HOST=$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --region "$AWS_REGION" \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text)
sed -i "s|^export REDIS_URL=.*|export REDIS_URL=rediss://${REDIS_HOST}:6379|" infra/cloud.env
source infra/cloud.env
scripts/05-gerar-secrets.sh
kubectl apply -f k8s/generated/

# 5) Reinicia os Deployments para os pods lerem os Secrets atualizados.
echo "5/5 Reiniciando os serviços"
for ns in auth flag targeting evaluation analytics; do
  kubectl rollout restart deploy -n togglemaster-$ns
done
for ns in auth flag targeting evaluation; do
  kubectl rollout status deploy -n togglemaster-$ns --timeout=300s
done

# Mostra o estado final (o analytics fica em 0 pods até chegar mensagem na fila — KEDA).
kubectl get nodes
kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster
echo "Retomado. O DNS do Load Balancer é o mesmo de antes:"
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
