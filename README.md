# ToggleMaster — Fase 2 (POSTECH DCLT)

Ecossistema de 5 microsserviços de feature flags conteinerizado e implantado no **Amazon EKS**, com escalabilidade por **HPA** (CPU) e **KEDA** (fila SQS).

## Arquitetura

```mermaid
flowchart LR
  user([Cliente / curl / hey]) --> nlb[NLB internet-facing]
  nlb --> ing[NGINX Ingress Controller]
  subgraph EKS["Amazon EKS - togglemaster (nós privados t3.medium, 1-2-4)"]
    ing -- /auth/* --> auth[auth-service<br/>Go]
    ing -- /flags --> flag[flag-service<br/>Python]
    ing -- /rules --> targ[targeting-service<br/>Python]
    ing -- /evaluate --> eval[evaluation-service<br/>Go - HPA CPU 70%]
    flag -. valida key .-> auth
    targ -. valida key .-> auth
    eval -- cache miss --> flag
    eval -- cache miss --> targ
    ana[analytics-service<br/>Python - KEDA 0..5]
  end
  auth --> rds1[(RDS auth_db)]
  flag --> rds2[(RDS flags_db)]
  targ --> rds3[(RDS targeting_db)]
  eval --> redis[(ElastiCache Redis TLS)]
  eval -- evento --> sqs[[SQS togglemaster-events]]
  sqs --> ana
  ana --> ddb[(DynamoDB ToggleMasterAnalytics)]
  keda{{KEDA}} -. lê profundidade .-> sqs
  keda -. escala .-> ana
```

| Serviço | Porta | Linguagem | Dados | Rota no Ingress |
|---|---|---|---|---|
| auth-service | 8001 | Go | RDS PostgreSQL `auth_db` | `/auth/*` |
| flag-service | 8002 | Python | RDS PostgreSQL `flags_db` | `/flags` |
| targeting-service | 8003 | Python | RDS PostgreSQL `targeting_db` | `/rules` |
| evaluation-service | 8004 | Go | ElastiCache Redis + SQS (produz) | `/evaluate` |
| analytics-service | 8005 | Python | SQS (consome) + DynamoDB | — (worker) |

## Estrutura

```
services/        código dos 5 microsserviços + Dockerfile multi-stage de cada um
docker-compose.yml + local/   ambiente local (9 containers)
infra/           eksctl-cluster.yaml, políticas IAM (IRSA), cloud.env.example
k8s/             manifestos (namespaces, deployments, services, configmaps, secrets, ingress, HPA, KEDA, jobs de schema)
scripts/         build/push ECR, geração de secrets, deploy, testes, carga, SQS, DevSecOps, destruição
docs/            PASSO_A_PASSO.md, ROTEIRO_VIDEO.md, RELATORIO_ENTREGA_FASE2.txt
```

## Início rápido

```bash
# local
cp .env.example .env    # preencha
eval "$(aws configure export-credentials --format env)"
docker compose up -d --build && docker compose ps

# nuvem: siga docs/PASSO_A_PASSO.md
```

Código-fonte original: https://github.com/FIAP-TCs (as correções aplicadas estão em `docs/PASSO_A_PASSO.md`, seção 0.4).
