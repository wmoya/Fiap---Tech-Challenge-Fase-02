#!/usr/bin/env bash
# =============================================================================
# 50-pausar-ambiente.sh
# Pausa o laboratório para reduzir o custo por hora SEM perder o cenário:
#   - nós do EKS escalados para 0 (sem EC2 ligada);
#   - os 3 RDS parados (dados preservados; a AWS religa sozinha após 7 dias);
#   - ElastiCache apagado (é só cache; o 51-retomar-ambiente.sh recria).
# Continuam cobrando (não dá para pausar): control plane do EKS, NAT Gateway e o
# Load Balancer (mantido para o DNS não mudar). Custo pausado: ~US$ 0,18/h.
# Uso: source infra/cloud.env && scripts/50-pausar-ambiente.sh
# Para voltar: scripts/51-retomar-ambiente.sh
# =============================================================================

# Sem o -e de propósito: se um recurso já estiver parado/apagado, segue para o próximo.
set -uo pipefail

# Vai para a raiz do projeto.
cd "$(dirname "$0")/.."

# Exige as variáveis do laboratório.
: "${AWS_REGION:?rode: source infra/cloud.env}" "${CLUSTER_NAME:?}"

# 1) Escala o node group para 0 nós. Os Deployments continuam declarados no cluster;
#    os pods só ficam Pending até os nós voltarem no 51-retomar-ambiente.sh.
echo "1/3 Node group ng-apps -> 0 nós"
eksctl scale nodegroup --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --name ng-apps \
  --nodes 0 --nodes-min 0 --nodes-max 4 --wait

# 2) Para os 3 RDS. O stop preserva os dados e o endpoint; só o disco continua cobrando.
#    Atenção: a AWS religa automaticamente uma instância parada há 7 dias.
echo "2/3 Parando os 3 RDS (dados preservados)"
for n in auth flag targeting; do
  aws rds stop-db-instance --db-instance-identifier togglemaster-$n-db --region "$AWS_REGION" >/dev/null \
    && echo "  parando togglemaster-$n-db"
done

# 3) Apaga o Redis: o ElastiCache não tem "stop". Como é só cache, nada se perde —
#    o evaluation volta a preencher o cache sozinho a partir do RDS.
echo "3/3 Apagando o ElastiCache (cache; será recriado ao retomar)"
aws elasticache delete-replication-group --replication-group-id togglemaster-redis --region "$AWS_REGION" >/dev/null \
  && echo "  apagando togglemaster-redis"

# Espera os RDS chegarem em 'stopped' para confirmar que pararam de cobrar por hora.
echo "   aguardando os RDS pararem..."
for n in auth flag targeting; do
  until [ "$(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db --region "$AWS_REGION" \
      --query 'DBInstances[0].DBInstanceStatus' --output text)" = "stopped" ]; do sleep 20; done
  echo "  togglemaster-$n-db: stopped"
done

echo "Pausado. Continuam cobrando: EKS (control plane), NAT Gateway e o Load Balancer (~US\$ 0,18/h)."
echo "Para retomar: source infra/cloud.env && scripts/51-retomar-ambiente.sh"
