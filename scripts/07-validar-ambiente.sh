#!/usr/bin/env bash
# =============================================================================
# 07-validar-ambiente.sh
# Confere, item por item, se TODO o ambiente AWS da Parte 2 foi criado e está
# funcionando. Imprime ✅/❌ por requisito do Tech Challenge e um resumo no fim.
# Não mostra ARNs nem o nº da conta (pode aparecer na gravação).
# Uso: source infra/cloud.env && scripts/07-validar-ambiente.sh
# =============================================================================

# Sem -e: um item com falha não interrompe a conferência dos demais.
set -uo pipefail

# Vai para a raiz do projeto.
cd "$(dirname "$0")/.."

# Exige as variáveis do laboratório.
: "${AWS_REGION:?rode: source infra/cloud.env}" "${CLUSTER_NAME:?}" "${IMAGE_TAG:?}" "${AWS_SQS_URL:?}"

OK=0; FALHA=0
# check "<descrição>" '<comando bash>': ✅ se o comando tiver sucesso, ❌ se falhar.
check() {
  if bash -c "$2" >/dev/null 2>&1; then echo "  ✅ $1"; OK=$((OK+1)); else echo "  ❌ $1"; FALHA=$((FALHA+1)); fi
}

LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
export LB

echo "== Cluster EKS =="
check "cluster $CLUSTER_NAME ACTIVE"               '[ "$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.status --output text)" = ACTIVE ]'
check "node group ng-apps ACTIVE"                  '[ "$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name ng-apps --query nodegroup.status --output text)" = ACTIVE ]'
check "nós Ready no Kubernetes"                    'kubectl get nodes --no-headers | grep -qw Ready'
check "Metrics Server respondendo (kubectl top)"   'kubectl top nodes'

echo "== ECR (5 repositórios com a imagem :$IMAGE_TAG) =="
for r in auth-service flag-service targeting-service evaluation-service analytics-service; do
  check "ECR $r:$IMAGE_TAG"                        "aws ecr describe-images --repository-name $r --image-ids imageTag=$IMAGE_TAG"
done

echo "== Bancos, cache, fila e tabela =="
for n in auth flag targeting; do
  check "RDS togglemaster-$n-db available"         "[ \"\$(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db --query 'DBInstances[0].DBInstanceStatus' --output text)\" = available ]"
done
check "RDS sem acesso público"                     '[ -z "$(aws rds describe-db-instances --query "DBInstances[?starts_with(DBInstanceIdentifier,\`togglemaster-\`) && PubliclyAccessible].DBInstanceIdentifier" --output text)" ]'
check "ElastiCache togglemaster-redis available"   '[ "$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --query "ReplicationGroups[0].Status" --output text)" = available ]'
check "DynamoDB ToggleMasterAnalytics ACTIVE"      '[ "$(aws dynamodb describe-table --table-name ToggleMasterAnalytics --query Table.TableStatus --output text)" = ACTIVE ]'
check "SQS togglemaster-events existe"             'aws sqs get-queue-attributes --queue-url "$AWS_SQS_URL" --attribute-names QueueArn'

echo "== Segurança (IRSA) e controladores =="
check "IRSA evaluation-service-sa (role ligada)"   'kubectl get sa -n togglemaster-evaluation evaluation-service-sa -o yaml | grep -q togglemaster-evaluation-irsa'
check "IRSA analytics-service-sa (role ligada)"    'kubectl get sa -n togglemaster-analytics analytics-service-sa -o yaml | grep -q togglemaster-analytics-irsa'
check "AWS Load Balancer Controller rodando"       'kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=10s'
check "NGINX Ingress com Load Balancer (DNS)"      '[ -n "$LB" ]'
check "KEDA operator rodando"                      'kubectl -n keda rollout status deploy/keda-operator --timeout=10s'

echo "== Microsserviços =="
check "5 Secrets aplicados"                        '[ "$(kubectl get secret -A --no-headers | grep -c -- -service-secret)" -ge 5 ]'
for s in auth flag targeting evaluation; do
  check "$s-service Running"                       "kubectl -n togglemaster-$s rollout status deploy/$s-service --timeout=10s"
done
check "analytics-service Deployment existe (KEDA 0..5)" 'kubectl -n togglemaster-analytics get deploy analytics-service'
check "Ingress /auth /flags /rules /evaluate"      '[ "$(kubectl get ingress -A --no-headers | grep -c togglemaster)" -ge 4 ]'

echo "== Escalabilidade =="
check "HPA do evaluation (CPU 70%, 1-6)"           'kubectl -n togglemaster-evaluation get hpa evaluation-service-hpa'
check "ScaledObject do analytics READY"            'kubectl -n togglemaster-analytics get scaledobject analytics-service-scaler -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" | grep -q True'

echo "== Tráfego pela porta da frente (Load Balancer) =="
check "GET /auth/health responde"                  'curl -sf --max-time 10 "http://$LB/auth/health"'
check "GET /evaluate responde (flag do teste-fluxo)" 'curl -sf --max-time 10 "http://$LB/evaluate?user_id=check&flag_name=enable-new-dashboard"'

echo
echo "Resultado: $OK OK · $FALHA com falha"
[ "$FALHA" -eq 0 ] && echo "Ambiente 100% pronto para a gravação." || echo "Corrija os itens ❌ (veja o apêndice do ROTEIRO_GRAVACAO.md) e rode de novo."
[ "$FALHA" -eq 0 ]
