#!/usr/bin/env bash
# =============================================================================
# 99-destruir-ambiente.sh
# Remove TUDO o que gera custo, na ordem certa de dependência. Rode logo após
# a gravação do vídeo para zerar os gastos por hora (EKS, RDS, ElastiCache, NLB).
# Uso: source infra/cloud.env && scripts/99-destruir-ambiente.sh
# =============================================================================

# Aqui usamos 'set -uo pipefail' SEM o -e de propósito: se um recurso já não existir,
# o comando falha, mas queremos CONTINUAR apagando os demais (não parar no 1º erro).
set -uo pipefail

# Vai para a raiz do projeto (precisa do infra/eksctl-cluster.yaml no passo 6).
cd "$(dirname "$0")/.."

# Exige ao menos a região (os demais nomes de recurso são fixos no script).
: "${AWS_REGION:?rode: source infra/cloud.env}"

# 1) Remove o Ingress Controller primeiro. Isso faz a AWS apagar o Load Balancer (NLB)
#    que ele criou. O 'sleep 60' dá tempo da AWS concluir a remoção do NLB.
echo "1/7 Removendo Ingress Controller (apaga o Load Balancer criado por ele)"
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null; sleep 60

# 2) Apaga os namespaces das aplicações (--wait=false: não bloqueia esperando terminar)
#    e desinstala KEDA e o AWS Load Balancer Controller.
echo "2/7 Removendo apps e KEDA"
kubectl delete ns togglemaster-auth togglemaster-flag togglemaster-targeting togglemaster-evaluation togglemaster-analytics --wait=false 2>/dev/null
helm uninstall keda -n keda 2>/dev/null
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null

# 3) Apaga os 3 bancos RDS. --skip-final-snapshot: não cria backup final (é lab);
#    --delete-automated-backups: remove também os backups automáticos (evita custo residual).
echo "3/7 RDS (sem snapshot final)"
for db in togglemaster-auth-db togglemaster-flag-db togglemaster-targeting-db; do
  aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups --region $AWS_REGION >/dev/null && echo "  apagando $db"
done

# 4) Apaga o grupo de réplicas do ElastiCache (Redis).
echo "4/7 ElastiCache"
aws elasticache delete-replication-group --replication-group-id togglemaster-redis --region $AWS_REGION >/dev/null && echo "  apagando togglemaster-redis"

# 5) Apaga DynamoDB, a fila SQS e os 5 repositórios ECR.
echo "5/7 DynamoDB, SQS e ECR"
aws dynamodb delete-table --table-name ToggleMasterAnalytics --region $AWS_REGION >/dev/null && echo "  tabela apagada"
aws sqs delete-queue --queue-url "$AWS_SQS_URL" --region $AWS_REGION && echo "  fila apagada"
# --force apaga o repositório mesmo contendo imagens.
for r in auth-service flag-service targeting-service evaluation-service analytics-service; do
  aws ecr delete-repository --repository-name $r --force --region $AWS_REGION >/dev/null && echo "  ECR $r apagado"
done

# Espera RDS e ElastiCache terminarem de ser apagados — eles seguram as subnets/subnet groups,
# que só podem ser removidos depois (senão daria erro de dependência).
echo "   aguardando RDS e ElastiCache terminarem (libera as subnets)..."
for db in togglemaster-auth-db togglemaster-flag-db togglemaster-targeting-db; do
  aws rds wait db-instance-deleted --db-instance-identifier $db --region $AWS_REGION
done
# Enquanto o grupo Redis ainda for encontrado, espera 20s e checa de novo.
while aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --region $AWS_REGION >/dev/null 2>&1; do sleep 20; done

# Agora dá para remover os subnet groups de RDS e ElastiCache.
aws rds delete-db-subnet-group --db-subnet-group-name togglemaster-db-subnets --region $AWS_REGION
aws elasticache delete-cache-subnet-group --cache-subnet-group-name togglemaster-redis-subnets --region $AWS_REGION

# E os security groups criados para RDS e Redis (busca o ID pelo nome; só apaga se existir).
for sg in togglemaster-rds-sg togglemaster-redis-sg; do
  id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$sg --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)
  [ "$id" != "None" ] && aws ec2 delete-security-group --group-id $id --region $AWS_REGION && echo "  SG $sg apagado"
done

# 6) Por último o cluster EKS: o eksctl remove node group, VPC, subnets e as roles do IRSA.
#    --disable-nodegroup-eviction acelera; --wait bloqueia até terminar (~10-15 min).
echo "6/7 Cluster EKS + VPC + roles IRSA (eksctl, ~10-15 min)"
eksctl delete cluster -f infra/eksctl-cluster.yaml --disable-nodegroup-eviction --wait

# 7) Remove as políticas IAM criadas só para o laboratório.
echo "7/7 Políticas IAM criadas para o laboratório"
for p in TogglemasterEvaluationSQS TogglemasterAnalyticsSQSDynamo TogglemasterKedaSQS AWSLoadBalancerControllerIAMPolicy; do
  arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/$p"
  aws iam delete-policy --policy-arn "$arn" 2>/dev/null && echo "  política $p apagada"
done

# Lembrete: conferir no Billing/Cost Explorer no dia seguinte se nada ficou cobrando.
echo "Pronto. Confira no Billing / Cost Explorer amanhã se não sobrou nada."
