#!/usr/bin/env bash
# =============================================================================
# 00-subir-ambiente.sh
# Sobe TODO o ambiente AWS da Parte 2 com os mesmos comandos já testados no
# ROTEIRO_GRAVACAO.md (3.2 -> 5.3), já com as correções do apêndice (T1-T12).
# É idempotente: o que já existe é pulado, então pode rodar de novo após um erro.
#
# Uso (da raiz do projeto, no WSL):
#   scripts/00-subir-ambiente.sh                 -> todas as etapas (~40-60 min)
#   scripts/00-subir-ambiente.sh rds redis       -> só as etapas indicadas (gravar ao vivo)
# Etapas, em ordem: prereq cluster ecr rede rds redis dynamodb endpoints irsa ingress keda deploy teste
# Depois: scripts/07-validar-ambiente.sh
# =============================================================================

# Aborta em erro (-e), variável indefinida é erro (-u), pipe falha se parte falhar.
set -euo pipefail

# Vai para a raiz do projeto (caminhos "infra/...", "k8s/..." e "scripts/...").
cd "$(dirname "$0")/.."

# Grava/atualiza uma variável "export NOME=valor" no infra/cloud.env.
set_env() { sed -i "s|^export $1=.*|export $1=$2|" infra/cloud.env; }

# Imprime um cabeçalho de etapa (o mesmo nome usado no roteiro de apresentação).
etapa() { echo; echo "================ $1 ================"; }

# ---------------------------------------------------------------- cloud.env
# Cria o cloud.env a partir do exemplo e preenche o que estiver vazio (conta, senha, chaves).
[ -f infra/cloud.env ] || cp infra/cloud.env.example infra/cloud.env
grep -q '^export AWS_ACCOUNT_ID=[0-9]' infra/cloud.env || set_env AWS_ACCOUNT_ID "$(aws sts get-caller-identity --query Account --output text)"
grep -q '^export DB_PASSWORD=.\+'      infra/cloud.env || set_env DB_PASSWORD "$(openssl rand -hex 16)"
grep -q '^export MASTER_KEY=.\+'       infra/cloud.env || set_env MASTER_KEY "$(openssl rand -hex 16)"
grep -q '^export SERVICE_API_KEY=.\+'  infra/cloud.env || set_env SERVICE_API_KEY "tm_key_$(openssl rand -hex 32)"
source infra/cloud.env

# Descobre a rede criada pelo eksctl e os SGs dos bancos (usada por rede/rds/redis).
carregar_rede() {
  VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query cluster.resourcesVpcConfig.vpcId --output text)
  CLUSTER_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
  PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=tag:kubernetes.io/role/internal-elb,Values=1 \
    --query 'Subnets[].SubnetId' --output text)
  RDS_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-rds-sg Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text)
  REDIS_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-redis-sg Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text)
}

# ---------------------------------------------------------------- etapas
# Pré-requisitos da conta (T1) e a fila SQS (o 99-destruir apaga a fila no fim).
passo_prereq() {
  etapa "A0 Pré-requisitos: role do Auto Scaling + fila SQS"
  if ! aws iam get-role --role-name AWSServiceRoleForAutoScaling >/dev/null 2>&1; then
    aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com >/dev/null
    echo "  role criada; aguardando 2 min para propagar (T1)"; sleep 120
  fi
  # create-queue é idempotente com os mesmos atributos. Após apagar, a AWS exige 60 s para recriar o mesmo nome.
  aws sqs create-queue --queue-name togglemaster-events \
    --attributes VisibilityTimeout=30,MessageRetentionPeriod=86400 --query QueueUrl --output text
}

# Cluster EKS + node group (3.2). Se o cluster já existe e só o node group falta, cria só ele (T2/T3).
passo_cluster() {
  etapa "A1 Cluster EKS (eksctl, ~15-20 min)"
  grep instanceType infra/eksctl-cluster.yaml
  if aws eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "  cluster já existe"
  else
    eksctl create cluster -f infra/eksctl-cluster.yaml
  fi
  aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name ng-apps >/dev/null 2>&1 \
    || eksctl create nodegroup -f infra/eksctl-cluster.yaml
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null
  # O eksctl 0.231 já instala o metrics-server como addon (T5); só aplica se faltar.
  kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1 \
    || kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl get nodes -o wide
}

# 5 repositórios ECR + build/push das imagens (3.3). Precisa do Docker rodando.
passo_ecr() {
  etapa "A2 ECR: 5 repositórios + push das imagens"
  docker info >/dev/null 2>&1 || { echo "Docker não está rodando (abra o Docker Desktop)"; exit 1; }
  scripts/01-ecr-build-push.sh
}

# Security groups (só o cluster acessa) + subnet groups nas subnets privadas (3.4, passo 2).
passo_rede() {
  etapa "A3 Rede dos bancos: security groups + subnet groups"
  carregar_rede
  if [ "$RDS_SG" = "None" ]; then
    RDS_SG=$(aws ec2 create-security-group --group-name togglemaster-rds-sg \
      --description "PostgreSQL acessivel somente pelo EKS" --vpc-id "$VPC_ID" --query GroupId --output text)
    aws ec2 authorize-security-group-ingress --group-id "$RDS_SG" --protocol tcp --port 5432 --source-group "$CLUSTER_SG" >/dev/null
  fi
  if [ "$REDIS_SG" = "None" ]; then
    REDIS_SG=$(aws ec2 create-security-group --group-name togglemaster-redis-sg \
      --description "Redis acessivel somente pelo EKS" --vpc-id "$VPC_ID" --query GroupId --output text)
    aws ec2 authorize-security-group-ingress --group-id "$REDIS_SG" --protocol tcp --port 6379 --source-group "$CLUSTER_SG" >/dev/null
  fi
  aws rds describe-db-subnet-groups --db-subnet-group-name togglemaster-db-subnets >/dev/null 2>&1 \
    || aws rds create-db-subnet-group --db-subnet-group-name togglemaster-db-subnets \
         --db-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS >/dev/null
  aws elasticache describe-cache-subnet-groups --cache-subnet-group-name togglemaster-redis-subnets >/dev/null 2>&1 \
    || aws elasticache create-cache-subnet-group --cache-subnet-group-name togglemaster-redis-subnets \
         --cache-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS >/dev/null
  echo "  SGs e subnet groups prontos"
}

# 3 RDS PostgreSQL independentes (3.4, passo 3). Não espera aqui: a espera fica no 'endpoints'.
passo_rds() {
  etapa "A4 RDS: 3 PostgreSQL (database per service)"
  carregar_rede
  for svc in auth:auth_db flag:flags_db targeting:targeting_db; do
    name=${svc%%:*}; db=${svc##*:}
    if aws rds describe-db-instances --db-instance-identifier togglemaster-$name-db >/dev/null 2>&1; then
      echo "  togglemaster-$name-db já existe"; continue
    fi
    aws rds create-db-instance --db-instance-identifier togglemaster-$name-db \
      --engine postgres --db-instance-class db.t3.micro --allocated-storage 20 --storage-type gp3 \
      --master-username "$DB_USER" --master-user-password "$DB_PASSWORD" --db-name $db \
      --db-subnet-group-name togglemaster-db-subnets --vpc-security-group-ids "$RDS_SG" \
      --no-publicly-accessible --no-multi-az --backup-retention-period 0 --storage-encrypted \
      --tags Key=project,Value=togglemaster >/dev/null && echo "  criando togglemaster-$name-db"
  done
}

# ElastiCache Redis com TLS (3.5).
passo_redis() {
  etapa "A5 ElastiCache Redis (cache do evaluation)"
  carregar_rede
  if aws elasticache describe-replication-groups --replication-group-id togglemaster-redis >/dev/null 2>&1; then
    echo "  togglemaster-redis já existe"; return
  fi
  aws elasticache create-replication-group --replication-group-id togglemaster-redis \
    --replication-group-description "Cache do evaluation-service" \
    --engine redis --cache-node-type cache.t3.micro --num-cache-clusters 1 \
    --cache-subnet-group-name togglemaster-redis-subnets --security-group-ids "$REDIS_SG" \
    --transit-encryption-enabled --at-rest-encryption-enabled \
    --tags Key=project,Value=togglemaster >/dev/null && echo "  criando togglemaster-redis"
}

# Tabela DynamoDB on-demand (3.6).
passo_dynamodb() {
  etapa "A6 DynamoDB ToggleMasterAnalytics"
  aws dynamodb describe-table --table-name ToggleMasterAnalytics >/dev/null 2>&1 \
    || aws dynamodb create-table --table-name ToggleMasterAnalytics \
         --attribute-definitions AttributeName=event_id,AttributeType=S --key-schema AttributeName=event_id,KeyType=HASH \
         --billing-mode PAY_PER_REQUEST --tags Key=project,Value=togglemaster >/dev/null
  aws dynamodb wait table-exists --table-name ToggleMasterAnalytics
  echo "  tabela ACTIVE"
}

# Espera RDS e Redis e grava os endpoints no cloud.env (3.7).
passo_endpoints() {
  etapa "A7 Aguardando RDS/Redis e gravando os endpoints no cloud.env"
  for n in auth flag targeting; do aws rds wait db-instance-available --db-instance-identifier togglemaster-$n-db; done
  aws elasticache wait replication-group-available --replication-group-id togglemaster-redis
  for n in auth flag targeting; do
    set_env RDS_${n^^}_ENDPOINT "$(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db \
      --query 'DBInstances[0].Endpoint.Address' --output text)"
  done
  set_env REDIS_URL "rediss://$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis \
    --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text):6379"
  source infra/cloud.env
  grep -E '^export (RDS_|REDIS_URL)' infra/cloud.env | grep -E 'None|=$|xxxx' && { echo "endpoint vazio"; exit 1; }
  echo "  endpoints gravados"
}

# Namespaces + políticas IAM + service accounts com role (IRSA) do evaluation e do analytics (4.2).
passo_irsa() {
  etapa "A8 IRSA: políticas IAM + service accounts"
  kubectl apply -f k8s/00-namespaces.yaml
  for p in evaluation-sqs-send:TogglemasterEvaluationSQS analytics-sqs-dynamodb:TogglemasterAnalyticsSQSDynamo keda-sqs-read:TogglemasterKedaSQS; do
    f=${p%%:*}; n=${p##*:}
    aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$n >/dev/null 2>&1 && continue
    sed "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" infra/iam/$f.json > /tmp/$f.json
    aws iam create-policy --policy-name $n --policy-document file:///tmp/$f.json >/dev/null && echo "  política $n criada"
  done
  eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --namespace togglemaster-evaluation \
    --name evaluation-service-sa --role-name togglemaster-evaluation-irsa \
    --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterEvaluationSQS --override-existing-serviceaccounts --approve
  eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --namespace togglemaster-analytics \
    --name analytics-service-sa --role-name togglemaster-analytics-irsa \
    --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterAnalyticsSQSDynamo --override-existing-serviceaccounts --approve
}

# AWS Load Balancer Controller (IRSA) + NGINX Ingress exposto por NLB (4.3).
passo_ingress() {
  etapa "A9 AWS Load Balancer Controller + NGINX Ingress (NLB)"
  carregar_rede
  if ! aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy >/dev/null 2>&1; then
    curl -sSL -o /tmp/lbc-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/lbc-policy.json >/dev/null
  fi
  eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --namespace kube-system \
    --name aws-load-balancer-controller --role-name togglemaster-lbc-irsa \
    --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --approve
  helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
    --set clusterName="$CLUSTER_NAME" --set region="$AWS_REGION" --set vpcId="$VPC_ID" \
    --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
  kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=300s
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
  # Espera o NLB receber o DNS (até ~5 min).
  for i in $(seq 1 30); do
    LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    [ -n "$LB" ] && break; sleep 10
  done
  echo "  Load Balancer: ${LB:-<ainda pendente>}"
}

# KEDA com IRSA para ler a fila (4.4).
passo_keda() {
  etapa "A10 KEDA (escala por fila SQS)"
  eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --namespace keda --name keda-operator \
    --role-name togglemaster-keda-irsa --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterKedaSQS --role-only --approve
  helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install keda kedacore/keda -n keda --create-namespace \
    --set podIdentity.aws.irsa.enabled=true \
    --set podIdentity.aws.irsa.roleArn=arn:aws:iam::$AWS_ACCOUNT_ID:role/togglemaster-keda-irsa
  kubectl -n keda rollout status deploy/keda-operator --timeout=300s
}

# Secrets (os 5 — T12) + deploy dos 5 serviços, HPA e ScaledObject (5.1 e 5.2).
passo_deploy() {
  etapa "A11 Secrets + deploy dos 5 microsserviços"
  scripts/05-gerar-secrets.sh
  [ "$(ls k8s/generated/*.yaml | wc -l)" -eq 5 ] || { echo "faltam secrets em k8s/generated/ (T12)"; exit 1; }
  scripts/06-deploy-k8s.sh
  for ns in auth flag targeting evaluation; do kubectl rollout status deploy -n togglemaster-$ns --timeout=300s; done
}

# Teste de ponta a ponta pelo Load Balancer (5.3): cria a flag usada no Bloco 6.
passo_teste() {
  etapa "A12 Teste de ponta a ponta pelo Load Balancer"
  LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "  LB=$LB"
  # O DNS do NLB pode levar alguns minutos para responder.
  for i in $(seq 1 30); do curl -sf "http://$LB/auth/health" >/dev/null && break; sleep 10; done
  export MASTER_KEY
  scripts/teste-fluxo.sh "$LB"
}

# ---------------------------------------------------------------- execução
TODAS="prereq cluster ecr rede rds redis dynamodb endpoints irsa ingress keda deploy teste"
for e in ${*:-$TODAS}; do
  declare -F "passo_$e" >/dev/null || { echo "etapa desconhecida: $e (use: $TODAS)"; exit 1; }
  "passo_$e"
done
echo; echo "Ambiente pronto. Confira tudo com: scripts/07-validar-ambiente.sh"
