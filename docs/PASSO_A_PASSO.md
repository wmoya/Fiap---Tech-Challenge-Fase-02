# ToggleMaster — Tech Challenge Fase 2 — Passo a passo completo

> **Cenário:** conta AWS pessoal (**Opção B** do enunciado), região `us-east-1`.
> Todos os comandos são para **bash** (a VM Linux da Fase 1 ou o Ubuntu no WSL2).
> Os blocos marcados com 🎥 são os trechos que vão para o vídeo (até 20 min).
> As mensagens de commit, a estrutura de pastas e os comandos já estão prontos: é copiar, colar e conferir.

---

## Índice

| Etapa | O que entrega | Requisito do enunciado | Tempo estimado |
|---|---|---|---|
| 0 | Ferramentas e conta AWS | Pré-requisito | 30 min |
| 1 | Docker + docker compose (9 containers) | 1 - Análise e Conteinerização | 30 min |
| 2 | EKS, ECR, 3 RDS, ElastiCache, DynamoDB, SQS | 2 - Infraestrutura na nuvem | 40 min (boa parte esperando) |
| 3 | Metrics Server, Ingress NGINX, IRSA, KEDA | 3 - Configurando o Cluster | 20 min |
| 4 | Manifestos (Namespaces, Deployments, Services, Secrets, ConfigMaps, Ingress) | 4 - Orquestração e Implantação | 20 min |
| 5 | HPA no evaluation, KEDA no analytics | 5 - Escalabilidade | 15 min |
| 6 | Gravação do vídeo | Entregável | 20 min |
| 7 | Destruir tudo | Custo | 30 min (esperando) |

## Matriz de aderência ao enunciado (checklist 100%)

Marque cada linha quando a evidência estiver pronta. Se todas estiverem marcadas, a entrega cobre tudo o que o PDF da Fase 2 pede.

| # | Requisito do enunciado | Onde é feito | Evidência no vídeo / relatório | ✔ |
|---|---|---|---|---|
| 1 | Dockerfile otimizado (multi-stage) para cada um dos 5 serviços | `services/*/Dockerfile` (já pronto) | abrir 1 Dockerfile e explicar os 2 estágios | ☐ |
| 2 | Um único `docker-compose.yml` na raiz com 5 apps + 2 PostgreSQL + 1 Redis + 1 DynamoDB Local | `docker-compose.yml` (já pronto) | `docker compose ps` com **9 containers** | ☐ |
| 3 | Cluster Kubernetes na nuvem (Opção B: `eksctl create cluster`) | Etapa 2.2 | Console EKS + `kubectl get nodes` | ☐ |
| 4 | Node group com auto scaling (ex.: mín. 1 / desejado 2 / máx. 4) | `infra/eksctl-cluster.yaml` | aba Compute do EKS | ☐ |
| 5 | 5 repositórios ECR + imagens publicadas | Etapa 2.3 | Console ECR | ☐ |
| 6 | 3 RDS PostgreSQL independentes (auth, flag, targeting) | Etapa 2.5 | Console RDS | ☐ |
| 7 | 1 ElastiCache Redis (evaluation) | Etapa 2.6 | Console ElastiCache | ☐ |
| 8 | 1 tabela DynamoDB (analytics) com nome/chave do código | Etapa 2.7 | Console DynamoDB | ☐ |
| 9 | 1 fila SQS Standard (evaluation produz, analytics consome) | Etapa 1.2 | Console SQS | ☐ |
| 10 | Strings de conexão anotadas | Etapa 2.9 / `infra/cloud.env` | (não mostrar senhas) | ☐ |
| 11 | Metrics Server instalado | Etapa 3.2 | `kubectl top nodes` | ☐ |
| 12 | Nginx Ingress Controller (Opção B recomenda IRSA para gerenciar o LB) | Etapa 3.4 | `kubectl get svc -n ingress-nginx` com EXTERNAL-IP | ☐ |
| 13 | Manifestos: Namespace, Deployment (imagem ECR), Service ClusterIP, Secret, ConfigMap para os 5 | `k8s/` + Etapa 4 | `kubectl get all -n togglemaster-flag` | ☐ |
| 14 | Ingress com rotas (/auth, /flags...) | `k8s/*/ingress.yaml` | `kubectl get ingress -A` + `curl` no LB | ☐ |
| 15 | Requests e Limits | todos os Deployments | mostrar `resources:` | ☐ |
| 16 | Secrets em base64 | `scripts/05-gerar-secrets.sh` | `cat k8s/generated/flag-secret.yaml` (com cuidado) | ☐ |
| 17 | Readiness e/ou Liveness | todos os Deployments | mostrar `readinessProbe`/`livenessProbe` | ☐ |
| 18 | Aplicações separadas por Namespaces | `k8s/00-namespaces.yaml` | `kubectl get ns` | ☐ |
| 19 | HPA no evaluation-service por CPU | `k8s/04-evaluation/hpa.yaml` | carga + `kubectl get hpa -w` subindo réplicas | ☐ |
| 20 | analytics escalando (Opção B: KEDA por profundidade da fila, 0→N) | `k8s/05-analytics/keda-scaledobject.yaml` | mensagens na SQS + pods 0→N | ☐ |
| 21 | Dados aparecendo no DynamoDB | Etapa 5.3 | Explore table items | ☐ |
| 22 | Explicar arquitetura e desafios | `docs/ROTEIRO_VIDEO.md` blocos 1 e 2 | fala no vídeo | ☐ |
| 23 | Justificar HPA x KEDA no analytics | roteiro bloco 10 | fala no vídeo | ☐ |
| 24 | Diferença entre RDS, ElastiCache e DynamoDB | roteiro bloco 10 | fala no vídeo | ☐ |
| 25 | Vídeo de até 20 min | Etapa 6 | link no relatório | ☐ |
| 26 | Relatório .PDF ou .txt: nomes, RM, Discord, link dos repositórios, link do vídeo | `docs/RELATORIO_ENTREGA_FASE2.txt` | arquivo entregue | ☐ |
| 27 | (Extra +10) badge público do Google Cloud Skills Boost | link no relatório | — | ☐ |

## Cronograma sugerido

| Quando | O que | Custo AWS |
|---|---|---|
| **Dia 1** (sem AWS ligada) | Etapa 0 (instalações) + Etapa 1 (Docker local) + publicar o repositório no GitHub. Gravar o bloco do `docker compose` já neste dia | só a fila SQS (centavos) |
| **Dia 2** (dia da gravação) | Etapas 2 → 5 de manhã (~2 h com as esperas), ensaio rápido, gravação, Etapa 7 (destruir) no mesmo dia | ~US$ 3–5 no total |
| **Dia 3** | Editar o vídeo, subir no YouTube (não listado), preencher e gerar o relatório | zero |

> 💡 O vídeo pode ser gravado em partes e unido depois: o bloco local (Dia 1) não precisa estar na mesma sessão do bloco de nuvem.

> 💰 **Custo:** o ambiente custa aproximadamente **US$ 0,40 a 0,50 por hora** com tudo ligado
> (EKS US$ 0,10/h + 2× t3.medium + NAT Gateway + NLB + 3× db.t3.micro + cache.t3.micro).
> Faça as etapas 2 a 7 **no mesmo dia** e destrua logo após gravar. Confira os preços atuais no AWS Pricing Calculator.

---

## Etapa 0 — Pré-requisitos

### 0.0 Preparar o Windows (WSL2 + Docker Desktop)

Todos os scripts são bash. No Windows, o caminho mais simples é o **Ubuntu dentro do WSL2**, com o Docker Desktop integrado a ele. Se preferir, use a VM Linux da Fase 1; nesse caso pule para a 0.1.

1. **PowerShell como Administrador:**
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
   Reinicie o Windows. Ao abrir o "Ubuntu" no menu Iniciar, crie usuário e senha do Linux.
2. **Docker Desktop:** instale (docker.com/products/docker-desktop) e, em *Settings*:
   - *General* → **Use the WSL 2 based engine** ligado;
   - *Resources → WSL integration* → ligar **Ubuntu-24.04**;
   - *Resources* → memória de pelo menos **6 GB** (9 containers + builds).
3. **Teste no terminal do Ubuntu:**
   ```bash
   docker run --rm hello-world
   ```
4. **Trabalhe dentro do Linux, não no `C:`.** Copie o projeto para o seu home do Ubuntu (fica mais rápido e evita problemas de permissão e de fim de linha CRLF):
   ```bash
   cp -r "/mnt/c/Users/Kelly/OneDrive/Desktop/Tech Fiap/Fase 02/ToggleMaster-Fase2" ~/
   cd ~/ToggleMaster-Fase2
   find . -name '*.sh' -exec chmod +x {} \;
   sed -i 's/\r$//' scripts/*.sh local/*/*.sh     # remove CRLF caso o OneDrive tenha convertido
   ```
5. (Opcional) **VS Code** com a extensão *WSL*: no terminal do Ubuntu, `code .` abre o projeto já no Linux. As extensões *Kubernetes*, *YAML* e *Docker* ajudam a enxergar erros nos manifestos, como nas aulas.

### 0.1 Ferramentas (Ubuntu / WSL2)

```bash
# utilitários (apache2-utils traz o "ab", usado nas aulas de balanceamento; hey é a alternativa)
sudo apt update && sudo apt install -y git jq curl unzip openssl postgresql-client apache2-utils hey

# Docker (se ainda não tiver da Fase 1)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# AWS CLI v2
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip

# kubectl
curl -sSLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# eksctl
curl -sSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# conferência
docker --version; aws --version; kubectl version --client; eksctl version; helm version --short
```

> Se o pacote `hey` não existir na sua versão do Ubuntu, o script de carga usa o container `williamyeh/hey` automaticamente.

### 0.2 Credenciais AWS (nunca use a conta root)

1. No Console → IAM → crie (ou reutilize) um usuário administrativo com **MFA**. Na Fase 1 vocês tinham o usuário `terraform` no grupo `terraform-admin`. Para criar EKS e IRSA ele precisa de permissões amplas (IAM, EC2, EKS, CloudFormation, RDS, ElastiCache, DynamoDB, SQS, ECR).
2. Configure o perfil:

```bash
aws configure            # Access Key, Secret, região us-east-1, saída json
aws sts get-caller-identity
```

> 🔐 As chaves ficam em `~/.aws/credentials`. Não mostre esse arquivo, o `.env` nem o `infra/cloud.env` no vídeo.

3. **Alarme de custo (faça antes de criar qualquer coisa):** Console → *Billing and Cost Management* → *Budgets* → *Create budget* → *Use a template* → **Monthly cost budget** → valor US$ 20 → seu e-mail. Se algo ficar ligado por engano, você recebe o aviso.

### 0.3 Repositório

```bash
# opção 1: usar a pasta que o Claude preparou (ToggleMaster-Fase2) e publicar no GitHub
cd ToggleMaster-Fase2
git init && git add . && git commit -m "ToggleMaster Fase 2: microsserviços, compose, k8s e infra"
# crie o repositório vazio no GitHub (ex.: togglemaster-fase2) e:
git remote add origin https://github.com/<usuario>/togglemaster-fase2.git
git branch -M main && git push -u origin main
```

> O `.gitignore` já impede o commit de `.env`, `infra/cloud.env`, `k8s/generated/`, `reports/` e `*.pem`.
> O link desse repositório vai no relatório ("Link dos repositórios").

### 0.4 O que foi corrigido no código-fonte original

O código da organização `FIAP-TCs` **não compila/roda como está**. Foram feitas apenas as correções necessárias (registre isso no vídeo e no relatório como "desafios encontrados"):

| Serviço | Problema | Correção |
|---|---|---|
| auth-service | `go.mod` com módulo inválido (`pgx/v4/stdlib v4.18.3`) | linha removida; o `stdlib` é um pacote do módulo `pgx/v4` |
| auth-service | `main.go` importa `stdlib` sem usar e `fmt` sem usar | import do driver virou `_ "github.com/jackc/pgx/v4/stdlib"`; `fmt` removido |
| auth-service | `handlers.go` e `key.go` com imports não usados (`crypto/sha256`, `encoding/hex`, `fmt`) | imports removidos |
| auth-service | sem `go.sum` | gerado no build (`go mod tidy` no Dockerfile) |
| evaluation-service | `go.sum` corrompido | regenerado no build |
| evaluation-service | `evaluator.go` usa `os.Getenv` sem importar `os` e importa `context` sem usar | imports corrigidos |
| flag / targeting / analytics | `Flask==2.2.2` sem pin do Werkzeug (o pip instala o Werkzeug 3, incompatível) e versões com CVEs conhecidas | atualizado para Flask 3.0.3 / Werkzeug 3.0.6 / gunicorn 23 / requests 2.32.3 |
| analytics-service | `boto3==1.26.50` não aceita endpoint por variável de ambiente (necessário para usar o DynamoDB Local) | `boto3==1.35.36` (aceita `AWS_ENDPOINT_URL_DYNAMODB`) |

---

## Etapa 1 — Conteinerização e ambiente local

### 1.1 Dockerfiles (já prontos em `services/*/Dockerfile`)

| Serviço | Linguagem | Build stage | Runtime stage | Usuário |
|---|---|---|---|---|
| auth-service | Go | `golang:1.22-alpine` | `distroless/static-debian12:nonroot` (sem shell) | 65532 |
| evaluation-service | Go | `golang:1.22-alpine` | `distroless/static-debian12:nonroot` | 65532 |
| flag-service | Python | `python:3.11-slim` (pip para `/install`) | `python:3.11-slim` + gunicorn | 10001 |
| targeting-service | Python | idem | idem | 10001 |
| analytics-service | Python | idem | idem | 10001 |

**Por que multi-stage?** O compilador Go e o cache do pip ficam no primeiro estágio; a imagem final leva só o binário (ou as libs). As imagens Go ficam com poucos MB e sem shell, o que reduz a superfície de ataque.

### 1.2 Criar a fila SQS (usada já no ambiente local)

O `evaluation-service` usa o AWS SDK Go v1, que **não aceita endpoint local**. Por isso, mesmo no `docker compose`, a fila é a **SQS real** (é o que o README do serviço indica). Ela custa centavos e é o **Recurso 6** da Etapa 2.

🎥 *Mostre no Console: SQS → Create queue → Standard → nome `togglemaster-events`.* Ou pela CLI:

```bash
aws sqs create-queue --queue-name togglemaster-events --region us-east-1 \
  --attributes VisibilityTimeout=30,MessageRetentionPeriod=86400
aws sqs get-queue-url --queue-name togglemaster-events --query QueueUrl --output text
```

### 1.3 Configurar o `.env`

```bash
cp .env.example .env
# gere valores fortes:
echo "PG_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=')"
echo "MASTER_KEY=$(openssl rand -hex 16)"
echo "SERVICE_API_KEY=tm_key_$(openssl rand -hex 32)"
nano .env     # cole os valores acima e a URL da fila em AWS_SQS_URL
```

> O `SERVICE_API_KEY` é a chave que o evaluation-service usa para chamar o flag e o targeting.
> O script `local/postgres-auth/02-seed-service-key.sh` cadastra o **hash SHA-256** dela no `auth_db` na criação do banco, do mesmo jeito que o endpoint `/admin/keys` faria. Assim não é preciso parar o compose para colar a chave.

### 1.4 Subir os 9 containers

```bash
# credenciais AWS só na memória do shell (não ficam em arquivo nem no compose)
eval "$(aws configure export-credentials --format env)"

docker compose up -d --build
docker compose ps
```

> 🔐 Opcional (mínimo privilégio): em vez das credenciais de admin, crie um usuário IAM só para o ambiente local com a política `infra/iam/local-dev-sqs.json` (acesso apenas à fila).

🎥 **Mostrar:** `docker compose ps` com **9 containers** rodando:

| Container | Papel | Porta no host |
|---|---|---|
| auth-service | API keys | 8001 |
| flag-service | CRUD de flags | 8002 |
| targeting-service | regras de segmentação | 8003 |
| evaluation-service | hot path (true/false) | 8004 |
| analytics-service | worker SQS → DynamoDB | 8005 |
| postgres-auth | PostgreSQL do auth (`auth_db`) | — |
| postgres-core | PostgreSQL com `flags_db` e `targeting_db` | — |
| redis | cache do evaluation | — |
| dynamodb-local | DynamoDB Local | 8000 |

> O enunciado pede **2 instâncias PostgreSQL locais**: uma é exclusiva do auth; a outra hospeda dois bancos separados (flag e targeting). Na nuvem cada banco vira um RDS independente.

### 1.5 Criar a tabela no DynamoDB Local

```bash
aws dynamodb create-table --endpoint-url http://localhost:8000 --region us-east-1 \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 1.6 Testar o fluxo completo localmente

```bash
source .env && export MASTER_KEY
scripts/teste-fluxo.sh local
docker compose logs --tail=20 analytics-service      # "Evento ... salvo no DynamoDB"
aws dynamodb scan --endpoint-url http://localhost:8000 --region us-east-1 \
  --table-name ToggleMasterAnalytics --select COUNT
```

🎥 **Mostrar:** o script criando key → flag → regra → avaliações, e o `scan` do DynamoDB Local contando os eventos.

### 1.7 (DevSecOps) Varredura de segurança antes de publicar

```bash
scripts/devsecops-scan.sh      # Hadolint, Trivy (imagens + manifestos), Syft (SBOM), Gitleaks
```

Os relatórios ficam em `reports/`. Se o Trivy apontar CVE HIGH/CRITICAL com correção disponível, atualize a dependência antes do push.

---

## Etapa 2 — Infraestrutura na AWS

### 2.1 Variáveis do laboratório

```bash
cp infra/cloud.env.example infra/cloud.env
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/^export AWS_ACCOUNT_ID=.*/export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}/" infra/cloud.env
# senha dos RDS e chaves (pode reaproveitar MASTER_KEY e SERVICE_API_KEY do .env)
echo "DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
nano infra/cloud.env
source infra/cloud.env
```

> Reabriu o terminal? Rode `source infra/cloud.env` de novo antes de continuar.

### 2.2 Cluster EKS com eksctl (comece por ele: demora ~15-20 min)

```bash
eksctl create cluster -f infra/eksctl-cluster.yaml
```

O que o `infra/eksctl-cluster.yaml` cria:

| Item | Configuração | Motivo |
|---|---|---|
| VPC | `10.20.0.0/16`, subnets públicas e privadas em 2 AZs, 1 NAT Gateway | isolamento; 1 NAT para economizar |
| OIDC provider | `withOIDC: true` | pré-requisito do IRSA |
| Managed Node Group `ng-apps` | t3.medium, **mín. 1 / desejado 2 / máx. 4** | escalabilidade pedida no enunciado |
| Nós | `privateNetworking: true` | nós sem IP público |

> 💡 Enquanto o cluster sobe, abra **outro terminal** (`source infra/cloud.env`) e faça a 2.3 (ECR).
> As etapas 2.4 a 2.6 dependem da VPC do cluster, então espere o eksctl terminar.

🎥 **Mostrar:** Console → EKS → cluster `togglemaster` → aba Compute (node group 1/2/4).

### 2.3 ECR: 5 repositórios + push das imagens

```bash
scripts/01-ecr-build-push.sh
aws ecr describe-repositories --query 'repositories[].repositoryName' --output table
```

O script cria os 5 repositórios com **scan on push** (o ECR analisa vulnerabilidades em cada push) e publica `:<IMAGE_TAG>` (padrão `v1`).

🎥 **Mostrar:** Console → ECR → os 5 repositórios e o resultado do scan de uma imagem.

### 2.4 Rede dos bancos (Security Groups e Subnet Groups)

```bash
source infra/cloud.env
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)
CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:kubernetes.io/role/internal-elb,Values=1 \
  --query 'Subnets[].SubnetId' --output text)
echo "VPC=$VPC_ID  CLUSTER_SG=$CLUSTER_SG  SUBNETS=$PRIVATE_SUBNETS"

# SG do RDS: 5432 liberado SOMENTE para o security group do cluster (pods/nós)
RDS_SG=$(aws ec2 create-security-group --group-name togglemaster-rds-sg \
  --description "PostgreSQL acessivel somente pelo EKS" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --source-group $CLUSTER_SG

# SG do ElastiCache: 6379 liberado SOMENTE para o cluster
REDIS_SG=$(aws ec2 create-security-group --group-name togglemaster-redis-sg \
  --description "Redis acessivel somente pelo EKS" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $REDIS_SG --protocol tcp --port 6379 --source-group $CLUSTER_SG

# Subnet groups nas subnets PRIVADAS
aws rds create-db-subnet-group --db-subnet-group-name togglemaster-db-subnets \
  --db-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS
aws elasticache create-cache-subnet-group --cache-subnet-group-name togglemaster-redis-subnets \
  --cache-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS
```

> Lição da Fase 1: descrições de Security Group **sem acento** (a AWS rejeita caracteres não ASCII).

### 2.5 RDS: 3 instâncias PostgreSQL independentes (Recursos 1, 2 e 3)

```bash
for svc in auth:auth_db flag:flags_db targeting:targeting_db; do
  name=${svc%%:*}; db=${svc##*:}
  aws rds create-db-instance \
    --db-instance-identifier togglemaster-$name-db \
    --engine postgres --db-instance-class db.t3.micro \
    --allocated-storage 20 --storage-type gp3 \
    --master-username "$DB_USER" --master-user-password "$DB_PASSWORD" \
    --db-name $db \
    --db-subnet-group-name togglemaster-db-subnets \
    --vpc-security-group-ids $RDS_SG \
    --no-publicly-accessible --no-multi-az \
    --backup-retention-period 0 --storage-encrypted \
    --tags Key=project,Value=togglemaster >/dev/null && echo "criando togglemaster-$name-db"
done
# ~5-10 min. Enquanto isso faça a 2.6 e a 2.7 em outro terminal.
for n in auth flag targeting; do aws rds wait db-instance-available --db-instance-identifier togglemaster-$n-db; done
for n in auth flag targeting; do
  echo "$n: $(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db --query 'DBInstances[0].Endpoint.Address' --output text)"
done
```

Copie os 3 endpoints para `RDS_AUTH_ENDPOINT`, `RDS_FLAG_ENDPOINT` e `RDS_TARGETING_ENDPOINT` no `infra/cloud.env`.

> 🔐 A senha passa por variável de ambiente e não aparece no vídeo. Em produção o ideal seria `--manage-master-user-password` (senha no Secrets Manager) + External Secrets Operator.

### 2.6 ElastiCache for Redis (Recurso 4)

```bash
aws elasticache create-replication-group \
  --replication-group-id togglemaster-redis \
  --replication-group-description "Cache do evaluation-service" \
  --engine redis --cache-node-type cache.t3.micro --num-cache-clusters 1 \
  --cache-subnet-group-name togglemaster-redis-subnets \
  --security-group-ids $REDIS_SG \
  --transit-encryption-enabled --at-rest-encryption-enabled \
  --tags Key=project,Value=togglemaster >/dev/null
aws elasticache wait replication-group-available --replication-group-id togglemaster-redis
aws elasticache describe-replication-groups --replication-group-id togglemaster-redis \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text
```

Coloque no `infra/cloud.env`: `REDIS_URL=rediss://<endpoint>:6379` (**rediss** com dois "s" = TLS, porque ligamos a criptografia em trânsito).

### 2.7 DynamoDB (Recurso 5)

Nome e chave vêm do código do analytics-service: tabela `ToggleMasterAnalytics`, partition key `event_id` (String).

```bash
aws dynamodb create-table --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --tags Key=project,Value=togglemaster
```

> On-demand (PAY_PER_REQUEST) evita throttling durante o teste de carga e não cobra nada parado.

### 2.8 SQS (Recurso 6)

Já criada na etapa 1.2 (`togglemaster-events`, Standard).

### 2.9 Strings de conexão anotadas

```bash
source infra/cloud.env
echo "SQS:        $AWS_SQS_URL"
echo "DynamoDB:   $AWS_DYNAMODB_TABLE"
echo "RDS auth:   $RDS_AUTH_ENDPOINT"
echo "RDS flag:   $RDS_FLAG_ENDPOINT"
echo "RDS target: $RDS_TARGETING_ENDPOINT"
echo "Redis:      ${REDIS_URL%%:6379}"
```

🎥 **Mostrar:** Console com os 3 RDS (não públicos), o ElastiCache, a tabela e a fila.

---

## Etapa 3 — Configurando o cluster

### 3.1 kubeconfig

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get nodes -o wide
```

### 3.2 Metrics Server (necessário para o HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes            # pode levar ~1 min para aparecer
```

### 3.3 IRSA para os microsserviços (sem Access Keys dentro do cluster)

Na conta pessoal **não usamos a LabRole**. Cada serviço que fala com a AWS recebe **a própria role IAM, com o mínimo de permissões**, ligada à ServiceAccount do Kubernetes (IRSA). Nenhuma Access Key vai para Secret, imagem ou variável de ambiente.

```bash
kubectl apply -f k8s/00-namespaces.yaml

# políticas IAM (o arquivo tem <ACCOUNT_ID> como placeholder)
for p in evaluation-sqs-send:TogglemasterEvaluationSQS analytics-sqs-dynamodb:TogglemasterAnalyticsSQSDynamo keda-sqs-read:TogglemasterKedaSQS; do
  f=${p%%:*}; n=${p##*:}
  sed "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" infra/iam/$f.json > /tmp/$f.json
  aws iam create-policy --policy-name $n --policy-document file:///tmp/$f.json --query Policy.Arn --output text
done

# evaluation-service: só SendMessage na fila
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace togglemaster-evaluation --name evaluation-service-sa \
  --role-name togglemaster-evaluation-irsa \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterEvaluationSQS \
  --override-existing-serviceaccounts --approve

# analytics-service: consumir a fila + PutItem na tabela
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace togglemaster-analytics --name analytics-service-sa \
  --role-name togglemaster-analytics-irsa \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterAnalyticsSQSDynamo \
  --override-existing-serviceaccounts --approve

kubectl get sa -n togglemaster-evaluation evaluation-service-sa -o jsonpath='{.metadata.annotations}'; echo
```

| Permissão | evaluation | analytics | KEDA |
|---|---|---|---|
| `sqs:SendMessage` | ✔ | | |
| `sqs:ReceiveMessage` / `DeleteMessage` | | ✔ | |
| `sqs:GetQueueAttributes` | ✔ | ✔ | ✔ (só isso) |
| `dynamodb:PutItem` | | ✔ | |

### 3.4 Ingress NGINX (com Load Balancer gerenciado via IRSA)

O enunciado (Opção B) recomenda IRSA para o controller que cria o Load Balancer. Para isso, instalamos o **AWS Load Balancer Controller** com IRSA e ele cria o NLB na frente do NGINX:

```bash
# 1) AWS Load Balancer Controller com IRSA
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)
curl -sSL -o /tmp/lbc-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/lbc-policy.json
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller \
  --role-name togglemaster-lbc-irsa \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts --approve
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=$CLUSTER_NAME --set region=$AWS_REGION --set vpcId=$VPC_ID \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller

# 2) NGINX Ingress Controller (mesmo comando do nginx_ic.sh da Aula 3, + annotations do NLB)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
  --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip \
  --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
kubectl -n ingress-nginx get svc ingress-nginx-controller -w    # espere aparecer o EXTERNAL-IP (DNS do NLB); Ctrl+C
```

> **Plano B (se o LB Controller der problema):** use exatamente o comando da aula, sem annotations. O Kubernetes cria um Load Balancer "clássico" pelo controlador nativo da AWS, o que já atende ao "Nginx Ingress funcionando":
> ```bash
> helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
> ```

### 3.5 KEDA (escala por fila SQS) com IRSA

```bash
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace keda --name keda-operator --role-name togglemaster-keda-irsa \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterKedaSQS \
  --role-only --approve
helm repo add kedacore https://kedacore.github.io/charts && helm repo update
helm upgrade --install keda kedacore/keda -n keda --create-namespace \
  --set podIdentity.aws.irsa.enabled=true \
  --set podIdentity.aws.irsa.roleArn=arn:aws:iam::$AWS_ACCOUNT_ID:role/togglemaster-keda-irsa
kubectl -n keda get pods
```

---

## Etapa 4 — Manifestos e implantação

### 4.1 Estrutura dos manifestos

```
k8s/
├── 00-namespaces.yaml            # 5 namespaces (um por microsserviço), Pod Security "restricted"
├── 01-auth/        configmap · secret.example · deployment · service · ingress · db-init-job
├── 02-flag/        configmap · secret.example · deployment · service · ingress · db-init-job
├── 03-targeting/   configmap · secret.example · deployment · service · ingress · db-init-job
├── 04-evaluation/  configmap · secret.example · deployment · service · ingress · hpa
├── 05-analytics/   configmap · secret.example · deployment · service · keda-scaledobject
├── alternativas/   analytics-hpa-cpu.yaml   (HPA por CPU, caso não use KEDA)
└── generated/      secrets reais gerados pelo script (fora do Git)
```

Boas práticas exigidas no enunciado e onde estão:

| Exigência | Onde |
|---|---|
| Requests e Limits | `resources` em todos os Deployments e Jobs |
| Secrets em base64 | campo `data:` gerado por `kubectl create secret --dry-run=client -o yaml` |
| Readiness e Liveness | `httpGet /health` em todos os Deployments |
| Separação por Namespaces | `togglemaster-auth`, `-flag`, `-targeting`, `-evaluation`, `-analytics` |
| Imagens do ECR | `image: <conta>.dkr.ecr.us-east-1.amazonaws.com/<serviço>:v1` |
| Service ClusterIP | `service.yaml` de cada serviço |
| ConfigMap com URLs internas | ex.: `AUTH_SERVICE_URL=http://auth-service.togglemaster-auth.svc.cluster.local:8001` |

Extras de segurança (DevSecOps): `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities: drop ALL`, `seccompProfile: RuntimeDefault`, Pod Security Admission `restricted` nos namespaces e `automountServiceAccountToken: false` onde o pod não usa a API do Kubernetes.

### 4.2 Gerar os Secrets

```bash
source infra/cloud.env
scripts/05-gerar-secrets.sh
cat k8s/generated/flag-secret.yaml       # 🎥 mostre que está em base64 (só este, com cuidado)
```

> 🎥 Comentário para o vídeo: **base64 não é criptografia**, qualquer um com `kubectl get secret` decodifica. Por isso o acesso aos Secrets fica restrito por RBAC e, em produção, entraria um cofre (Secrets Manager + External Secrets, ou o Vault).

### 4.3 Aplicar tudo

```bash
scripts/06-deploy-k8s.sh
```

O script aplica, nesta ordem: namespaces → secrets → configmaps → **Jobs que criam as tabelas nos 3 RDS** → deployments → services → ingress → HPA → KEDA.

> Os bancos RDS nascem vazios. O Job `*-db-init` roda o `init.sql` de cada serviço com `psql` dentro do cluster, porque o RDS não é acessível de fora da VPC. O Job do auth também cadastra o hash da `SERVICE_API_KEY`.

### 4.4 Verificar

```bash
kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster     # 🎥 os 5 microsserviços
kubectl get svc,ingress -A | grep togglemaster
kubectl get jobs -A | grep db-init
kubectl logs -n togglemaster-auth deploy/auth-service             # "Conectado ao PostgreSQL com sucesso!"
kubectl logs -n togglemaster-evaluation deploy/evaluation-service # "Conectado ao Redis com sucesso!"
```

> O analytics-service começa com **0 pods** se o KEDA estiver ativo e a fila vazia. Isso é esperado: ele sobe quando chegam mensagens.

### 4.5 Testar pelo Load Balancer (Ingress)

| Rota no Ingress | Vai para | Exemplo |
|---|---|---|
| `/auth/*` (com rewrite) | auth-service | `/auth/health`, `/auth/admin/keys`, `/auth/validate` |
| `/flags` | flag-service | `/flags`, `/flags/<nome>` |
| `/rules` | targeting-service | `/rules`, `/rules/<flag>` |
| `/evaluate` | evaluation-service | `/evaluate?user_id=..&flag_name=..` |

```bash
LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $LB
curl -s http://$LB/auth/health
MASTER_KEY=$MASTER_KEY scripts/teste-fluxo.sh $LB            # 🎥
```

> O DNS do NLB pode levar 2 a 3 minutos para responder depois de criado.

> 📚 É o mesmo padrão do `ingress-path-routing.yaml` da Aula 3 (parte 2): `use-regex` + `rewrite-target: /$2` no `/auth`. A diferença é que aqui não há `host:` (qualquer domínio, inclusive o DNS do NLB, cai nas regras) e cada serviço tem o Ingress no próprio namespace.
>
> 🩺 Diagnóstico (Aula 3): se o LB não responder, teste o serviço direto com port-forward:
> `kubectl port-forward -n togglemaster-flag svc/flag-service 8002:8002` e, em outro terminal, `curl localhost:8002/health`.

---

## Etapa 5 — Escalabilidade

### 5.1 HPA do evaluation-service (CPU 70%)

Terminal 1:
```bash
kubectl get hpa -n togglemaster-evaluation -w
```
Terminal 2:
```bash
kubectl get pods -n togglemaster-evaluation -w
```
Terminal 3:
```bash
scripts/carga-evaluation.sh $LB 180 50       # 3 min, 50 conexões simultâneas
# alternativa com o "ab" das aulas de balanceamento:
# ab -n 200000 -c 50 "http://$LB/evaluate?user_id=user-carga&flag_name=enable-new-dashboard"
```

🎥 **Mostrar:** a coluna `TARGETS` passando de 70% e `REPLICAS` subindo de 1 para várias. Depois da carga, ele volta a 1 em cerca de 1 minuto.

> Cada avaliação também gera um evento na SQS, então essa carga aciona o analytics-service ao mesmo tempo.

### 5.2 KEDA no analytics-service (profundidade da fila)

Terminal 1:
```bash
kubectl get scaledobject,hpa -n togglemaster-analytics
kubectl get pods -n togglemaster-analytics -w
```
Terminal 2:
```bash
source infra/cloud.env
scripts/sqs-enviar-mensagens.sh 200          # 2.000 mensagens manuais
```

🎥 **Mostrar:** os pods do analytics saindo de **0 para N** (até 5) conforme a fila enche, e voltando a 0 depois de esvaziar (`cooldownPeriod: 60s`).

### 5.3 Dados no DynamoDB

```bash
aws dynamodb scan --table-name ToggleMasterAnalytics --select COUNT
aws dynamodb scan --table-name ToggleMasterAnalytics --max-items 3
```
🎥 Console → DynamoDB → `ToggleMasterAnalytics` → **Explore table items**.

---

## Etapa 6 — Gravação

Siga o `docs/ROTEIRO_VIDEO.md` (tempos e falas sugeridas). Antes de gravar:

- [ ] `docker compose ps` com 9 containers saudáveis
- [ ] `kubectl get pods -A` sem `CrashLoopBackOff`
- [ ] `curl http://$LB/auth/health` respondendo
- [ ] fila vazia: `aws sqs purge-queue --queue-url $AWS_SQS_URL`
- [ ] terminal sem histórico com senhas (`history -c`) e sem `.env` ou `cloud.env` abertos na tela

---

## Etapa 7 — Destruir o ambiente (obrigatório para não gerar custo)

```bash
source infra/cloud.env
scripts/99-destruir-ambiente.sh
docker compose down -v                       # ambiente local
```

Conferência final (tudo deve voltar vazio):

```bash
aws eks list-clusters
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws elasticache describe-replication-groups --query 'ReplicationGroups[].ReplicationGroupId'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```

---

## Solução de problemas

| Sintoma | Causa provável | Como resolver |
|---|---|---|
| `ImagePullBackOff` | tag errada ou imagem não publicada | `aws ecr list-images --repository-name <svc>`; confira `IMAGE_TAG` |
| auth/flag/targeting em `CrashLoopBackOff` com erro de conexão | SG do RDS sem a regra do cluster SG ou endpoint errado | revise a 2.4; `kubectl logs`; teste com `kubectl run psql --rm -it --image=postgres:16-alpine -- psql "<url>"` |
| `relation "flags" does not exist` | Job de init não rodou | `kubectl logs job/flag-service-db-init -n togglemaster-flag` |
| evaluation: `Não foi possível conectar ao Redis` | `redis://` com TLS ligado (ou o contrário) | use `rediss://` quando a criptografia em trânsito estiver ativa |
| evaluation: `AccessDenied` ao enviar para a SQS | IRSA não aplicado | `kubectl describe sa evaluation-service-sa -n togglemaster-evaluation` (deve ter `eks.amazonaws.com/role-arn`) e recrie o pod |
| HPA mostra `<unknown>/70%` | Metrics Server não pronto ou pod sem `requests` | `kubectl top pods -A`; aguarde 1 a 2 min |
| KEDA não escala | role do operator sem `GetQueueAttributes` ou URL errada | `kubectl logs -n keda deploy/keda-operator`; `kubectl describe scaledobject -n togglemaster-analytics` |
| `EXTERNAL-IP` fica `<pending>` | LB Controller sem permissão ou subnets sem tag | `kubectl logs -n kube-system deploy/aws-load-balancer-controller`; use o Plano B da 3.4 |
| Ingress 404 em `/auth` | annotation de rewrite | a rota é `/auth/health`, não `/health` |
