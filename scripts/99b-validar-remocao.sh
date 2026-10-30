#!/usr/bin/env bash
# =============================================================================
# 99b-validar-remocao.sh
# Roda DEPOIS do 99-destruir-ambiente.sh e confere, recurso por recurso, que
# nada do laboratório ficou para trás cobrando — inclusive os "esquecidos"
# (NAT Gateway, Elastic IP, Load Balancer, EBS solto, stacks do CloudFormation).
# Uso: source infra/cloud.env && scripts/99b-validar-remocao.sh
# =============================================================================

# Sem -e: confere todos os itens mesmo que algum falhe.
set -uo pipefail

# Exige a região e o nome do cluster.
: "${AWS_REGION:?rode: source infra/cloud.env}" "${CLUSTER_NAME:?}"

OK=0; SOBROU=0
# vazio "<descrição>" '<comando que lista o recurso>': ✅ se a saída for vazia/None, ❌ se ainda listar algo.
vazio() {
  local out; out=$(bash -c "$2" 2>/dev/null | tr -d '[:space:]')
  if [ -z "$out" ] || [ "$out" = "None" ]; then echo "  ✅ $1"; OK=$((OK+1))
  else echo "  ❌ $1 → ainda existe: $(bash -c "$2" 2>/dev/null | tr '\n\t' '  ')"; SOBROU=$((SOBROU+1)); fi
}

echo "== Recursos principais =="
vazio "Cluster EKS $CLUSTER_NAME"   'aws eks list-clusters --query "clusters[?@==\`'"$CLUSTER_NAME"'\`]" --output text'
vazio "EC2 ligadas"                 'aws ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping --query "Reservations[].Instances[].InstanceId" --output text'
vazio "RDS togglemaster-*"          'aws rds describe-db-instances --query "DBInstances[?starts_with(DBInstanceIdentifier,\`togglemaster-\`)].[DBInstanceIdentifier,DBInstanceStatus]" --output text'
vazio "ElastiCache togglemaster-*"  'aws elasticache describe-replication-groups --query "ReplicationGroups[?starts_with(ReplicationGroupId,\`togglemaster\`)].[ReplicationGroupId,Status]" --output text'
vazio "DynamoDB ToggleMasterAnalytics" 'aws dynamodb list-tables --query "TableNames[?@==\`ToggleMasterAnalytics\`]" --output text'
vazio "SQS togglemaster-*"          'aws sqs list-queues --queue-name-prefix togglemaster --query QueueUrls --output text'
vazio "ECR (5 repositórios)"        'aws ecr describe-repositories --query "repositories[?ends_with(repositoryName,\`-service\`)].repositoryName" --output text'

echo "== Os 'esquecidos' que cobram sozinhos =="
vazio "NAT Gateway"                 'aws ec2 describe-nat-gateways --filter Name=state,Values=pending,available --query "NatGateways[].NatGatewayId" --output text'
vazio "Elastic IP solto"            'aws ec2 describe-addresses --query "Addresses[].PublicIp" --output text'
vazio "Load Balancer (NLB/ALB)"     'aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName" --output text'
vazio "Load Balancer clássico"      'aws elb describe-load-balancers --query "LoadBalancerDescriptions[].LoadBalancerName" --output text'
vazio "EBS solto (available)"       'aws ec2 describe-volumes --filters Name=status,Values=available --query "Volumes[].VolumeId" --output text'
vazio "Stacks eksctl-togglemaster-*" 'aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE CREATE_IN_PROGRESS DELETE_IN_PROGRESS DELETE_FAILED ROLLBACK_COMPLETE --query "StackSummaries[?starts_with(StackName,\`eksctl-'"$CLUSTER_NAME"'\`)].[StackName,StackStatus]" --output text'

echo "== Sobras sem custo (bom limpar) =="
vazio "Security groups togglemaster-*" 'aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-* --query "SecurityGroups[].GroupName" --output text'
vazio "Políticas IAM do laboratório"   'aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName,\`Togglemaster\`) || PolicyName==\`AWSLoadBalancerControllerIAMPolicy\`].PolicyName" --output text'
vazio "Roles IRSA togglemaster-*"      'aws iam list-roles --query "Roles[?starts_with(RoleName,\`togglemaster-\`)].RoleName" --output text'

echo
echo "Resultado: $OK removidos · $SOBROU ainda existem"
if [ "$SOBROU" -eq 0 ]; then
  echo "Custo zero: nada do laboratório ficou ligado. Confira o Billing/Cost Explorer amanhã."
else
  echo "Algo ficou para trás. Se estiver 'deleting', aguarde alguns minutos e rode de novo;"
  echo "se não, rode scripts/99-destruir-ambiente.sh novamente ou apague pelo Console."
fi
[ "$SOBROU" -eq 0 ]
