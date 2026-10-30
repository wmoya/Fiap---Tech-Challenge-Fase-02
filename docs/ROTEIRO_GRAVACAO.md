# Roteiro de gravação — comando · validação · fala

Para cada atividade: **Criar** (o comando que executa), **Validar** (o comando a mostrar na
gravação como prova) e **Fala no vídeo** (narração curta, em primeira pessoa). Siga na ordem.
Quando um passo usa um script, incluo também o **Objetivo do script** (o que ele faz e por quê) e um
bloco **"Sem o script — comandos equivalentes"** com os comandos crus que ele executa por dentro —
útil para entender o que roda e para narrar no vídeo. Rodar o script ou os comandos crus dá no mesmo.
Convenções: a região padrão já é `us-east-1` (gravada no `aws configure`), e as variáveis
`CLUSTER_NAME`, `AWS_REGION`, `AWS_ACCOUNT_ID` vêm do `infra/cloud.env` (Etapa 2.1).

> 🎥 = cena que precisa aparecer no vídeo. 🔐 = cuidado para não expor segredo/nº da conta na tela.

## Como o desafio (e o vídeo) se divide

O Tech Challenge Fase 2 é explicitamente dividido em duas partes, e o vídeo precisa mostrar **as duas**:

| | O que o enunciado pede | Blocos deste roteiro | Custo |
|---|---|---|---|
| **PARTE 1 — Local (Docker)** | Dockerfiles multi-stage dos 5 serviços + `docker-compose.yml` com os 9 containers rodando na máquina | Blocos 1 e 2 | de graça |
| **PARTE 2 — AWS (Kubernetes)** | O mesmo sistema na nuvem: EKS, 5 ECR, 3 RDS, ElastiCache, DynamoDB, SQS, Ingress, HPA e KEDA | Blocos 3 a 7 | cobra por hora |

A **mesma imagem** que sobe no `docker compose` (Parte 1) é a que vai para o ECR e roda no EKS (Parte 2) — por isso validamos o local primeiro: se funciona na máquina, derisca a nuvem. Grave a Parte 1 com calma; a Parte 2 é feita num bloco contínuo (subir → demonstrar → destruir) porque os recursos cobram por hora.

---

# PARTE 1 — LOCAL (Docker) · custo zero

## Bloco 1 — Ambiente local (Docker)

### O que o `docker compose up` vai executar (e de onde vêm os containers) 🎥

O `docker-compose.yml` sobe **9 containers**, que têm **duas origens diferentes** — vale mostrar e explicar isso na gravação:

**A) Os 5 microsserviços — construídos LOCALMENTE a partir do nosso código.** No compose cada um tem `build: ./services/<serviço>`, ou seja, o Docker lê o `Dockerfile` daquela pasta e **constrói a imagem na hora** (é o que o `--build` faz), gerando a tag `togglemaster/<serviço>:local`. Não baixamos de lugar nenhum: a imagem nasce do nosso código.

| Container | Imagem gerada | Vem de | Porta no host |
|---|---|---|---|
| auth-service | `togglemaster/auth-service:local` | build de `services/auth-service/Dockerfile` | 8001 |
| flag-service | `togglemaster/flag-service:local` | build de `services/flag-service/Dockerfile` | 8002 |
| targeting-service | `togglemaster/targeting-service:local` | build de `services/targeting-service/Dockerfile` | 8003 |
| evaluation-service | `togglemaster/evaluation-service:local` | build de `services/evaluation-service/Dockerfile` | 8004 |
| analytics-service | `togglemaster/analytics-service:local` | build de `services/analytics-service/Dockerfile` | 8005 |

**B) Os 4 de infraestrutura — imagens oficiais prontas, baixadas do Docker Hub (pull).** Não construímos nada; o Docker baixa a imagem publicada:

| Container | Imagem (Docker Hub) | Papel |
|---|---|---|
| postgres-auth | `postgres:16-alpine` | banco do auth (`auth_db`) |
| postgres-core | `postgres:16-alpine` | banco com `flags_db` + `targeting_db` |
| redis | `redis:7-alpine` | cache do evaluation |
| dynamodb-local | `amazon/dynamodb-local:latest` | emulador local do DynamoDB |

> **Fala no vídeo:** "O `docker compose up --build` faz duas coisas: **constrói** as imagens dos meus 5 serviços a partir do código, aqui em `services/`, cada um pelo seu Dockerfile; e **baixa** do Docker Hub as imagens prontas de apoio — PostgreSQL, Redis e o DynamoDB Local. A rede interna do compose liga tudo pelo nome do serviço (o evaluation acha o Redis em `redis://redis:6379`, por exemplo). A única coisa que **não** é container é a fila **SQS** — essa é a real, na AWS."

### 1.1 Criar a fila SQS ✅
- **Criar:**
  ```bash
  aws sqs create-queue --queue-name togglemaster-events --attributes VisibilityTimeout=30,MessageRetentionPeriod=86400
  SQS_URL=$(aws sqs get-queue-url --queue-name togglemaster-events --query QueueUrl --output text)
  ```
- **Validar (🎥):**
  ```bash
  aws sqs get-queue-attributes --queue-url "$SQS_URL" --attribute-names QueueArn ApproximateNumberOfMessages
  ```
  *(ou mostrar no Console: SQS → fila `togglemaster-events`).*
- **Fala no vídeo:** "Começo criando a fila SQS, a `togglemaster-events`. Ela é o canal assíncrono entre o serviço de avaliação, que **produz** eventos, e o de analytics, que os **consome**. É o único recurso AWS que já uso no ambiente local, porque o SDK do serviço de avaliação trabalha com a fila real."


### 1.2 Configurar o `.env`
- **Criar:**
  ```bash
  cp .env.example .env
  sed -i "s|^AWS_SQS_URL=.*|AWS_SQS_URL=${SQS_URL}|" .env
  sed -i "s|^PG_PASSWORD=.*|PG_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=')|" .env
  sed -i "s|^MASTER_KEY=.*|MASTER_KEY=$(openssl rand -hex 16)|" .env
  sed -i "s|^SERVICE_API_KEY=.*|SERVICE_API_KEY=tm_key_$(openssl rand -hex 32)|" .env
  ```
- **Validar:**
  ```bash
  grep -E '^(AWS_REGION|AWS_DYNAMODB_TABLE|PG_USER)=' .env   # mostra só o que NÃO é segredo
  ```
- **Fala no vídeo:** "As credenciais e senhas ficam no `.env`, que está no `.gitignore` e nunca vai pro repositório. Gero as senhas com o `openssl`, então nada fica hardcoded." 🔐 *(não mostre o `.env` inteiro na tela).*



### 1.3 Subir os 9 containers 🎥
- **Criar:**
  ```bash
  eval "$(aws configure export-credentials --format env)"   # ❗ PRIMEIRO isto
  echo "Credencial no shell? ${AWS_ACCESS_KEY_ID:+sim}"      # deve imprimir: sim
  docker compose up -d --build
  ```
- **Validar (🎥 — cena principal deste bloco):**
  ```bash
  docker compose ps
  docker compose exec analytics-service env | grep -i aws_ | sed 's/=.*/=<set>/'   # o container recebeu as credenciais?
  ```
- **Fala no vídeo:** "Subo toda a stack local com um único `docker compose up`. São **9 containers**: os 5 microsserviços — auth, flag, targeting, evaluation e analytics — mais **2 instâncias PostgreSQL** (uma só do auth, outra com os bancos de flag e targeting), o **Redis** de cache e o **DynamoDB Local**. Cada serviço tem seu Dockerfile multi-stage, então as imagens são pequenas e sem shell."

> ⚠️ **Ordem importa (erro comum):** o `eval "$(aws configure export-credentials --format env)"` tem que vir **antes** do `docker compose up`. O `docker-compose.yml` repassa as credenciais AWS a partir do **shell**; se o shell não as tiver no momento do `up`, o evaluation sobe sem conseguir **publicar** na SQS e o analytics sem conseguir **consumir** — o log mostra `Unable to locate credentials` e o DynamoDB fica com `Count: 0`.
> **Correção sem rebuild:** rode o `eval`, depois `docker compose up -d --force-recreate` (recria os containers já com as credenciais) e repita o teste de fluxo (1.5) para gerar eventos novos.

> 💡 **Fala extra (resiliência, bom citar no vídeo):** o worker do analytics **não trava** quando falha — ele registra o erro e tenta de novo a cada 10s. Por isso, assim que a credencial aparece, ele volta a consumir sozinho, sem precisar reiniciar o container. É o comportamento esperado de um consumidor de fila.



### 1.4 Criar a tabela no DynamoDB Local
- **Criar:**
  ```bash
  aws dynamodb create-table --endpoint-url http://localhost:8000 --table-name ToggleMasterAnalytics --attribute-definitions AttributeName=event_id,AttributeType=S --key-schema AttributeName=event_id,KeyType=HASH --billing-mode PAY_PER_REQUEST
  ```
- **Validar:**
  ```bash
  aws dynamodb list-tables --endpoint-url http://localhost:8000
  ```
- **Fala no vídeo:** "Crio a tabela `ToggleMasterAnalytics`, com `event_id` como chave. Repare que uso o comando `aws`, mas com `--endpoint-url http://localhost:8000` — isso aponta o CLI para o **DynamoDB Local**, o container que está rodando aqui na minha máquina, e não para a AWS. O `aws` é só um cliente: o que decide o destino é o endpoint. É a **mesma tabela** que vou criar na nuvem na Parte 2, só que lá, **sem** o `--endpoint-url`, o mesmo comando vai para o DynamoDB gerenciado. Ou seja: agora é local e custo zero."

> 💡 **Reforço para a gravação (local × AWS):** o mesmo `aws dynamodb create-table` cria **local** (com `--endpoint-url http://localhost:8000`) ou **na nuvem** (sem ele). Prova rápida que dá para mostrar na tela: `aws dynamodb list-tables --endpoint-url http://localhost:8000` lista a tabela (local), enquanto `aws dynamodb list-tables` (sem endpoint) consulta a AWS e **não** mostra ela aqui na Parte 1. Exceção da Parte 1: a **SQS** é real desde já, porque o SDK do evaluation-service não aceita endpoint local; o **DynamoDB** tem emulador, então aqui é 100% local.




### 1.5 Testar o fluxo ponta a ponta 🎥
- **Objetivo do script `teste-fluxo.sh`:** fazer o caminho completo do produto numa tacada —
  criar uma API key, criar uma flag, criar uma regra de 50%, listar e avaliar 10 usuários. Cada
  avaliação gera um evento na SQS; serve para provar que todos os serviços conversam entre si.
- **Criar / rodar:**
  ```bash
  source .env && export MASTER_KEY
  scripts/teste-fluxo.sh local
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b> (local: auth 8001, flag 8002, targeting 8003, eval 8004)</summary>

  ```bash
  source .env && export MASTER_KEY
  FLAG=enable-new-dashboard
  # 1) health do auth
  curl -sf http://localhost:8001/health; echo
  # 2) criar API key com a MASTER_KEY e extrair o campo "key"
  KEY=$(curl -sf -X POST http://localhost:8001/admin/keys -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MASTER_KEY" -d '{"name":"demo-video"}' \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['key'])")
  # 3) validar a chave recém-criada
  curl -sf http://localhost:8001/validate -H "Authorization: Bearer $KEY"; echo
  # 4) criar a flag (habilitada)
  curl -s -X POST http://localhost:8002/flags -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KEY" -d "{\"name\":\"$FLAG\",\"description\":\"Novo dashboard\",\"is_enabled\":true}"; echo
  # 5) criar regra de 50% no targeting
  curl -s -X POST http://localhost:8003/rules -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KEY" -d "{\"flag_name\":\"$FLAG\",\"is_enabled\":true,\"rules\":{\"type\":\"PERCENTAGE\",\"value\":50}}"; echo
  # 6) listar as flags
  curl -sf http://localhost:8002/flags -H "Authorization: Bearer $KEY"; echo
  # 7) avaliar 10 usuários (cada chamada publica um evento na SQS)
  for u in $(seq 1 10); do curl -sf "http://localhost:8004/evaluate?user_id=user-$u&flag_name=$FLAG"; echo; done
  ```
  </details>
- **Validar (🎥):**
  ```bash
  docker compose logs --tail=20 analytics-service      # "Evento ... salvo no DynamoDB"
  aws dynamodb scan --endpoint-url http://localhost:8000 --table-name ToggleMasterAnalytics --select COUNT
  ```
- **Fala no vídeo:** "O script faz o caminho completo: cria uma API key, cria uma flag, define uma regra de segmentação e dispara avaliações. Cada avaliação vira um evento na fila; o analytics consome e grava no DynamoDB. O `scan` com contagem maior que zero prova que o fluxo assíncrono fechou de ponta a ponta."

---


## Bloco 2 — DevSecOps (OPCIONAL / diferencial · custo zero)

> ℹ️ **Não é exigido pelo enunciado** da Fase 2 — é um diferencial (shift-left). O scan obrigatório
> de verdade é o do **push no ECR** (já embutido no `01-ecr-build-push.sh`, Bloco 3.3). Dá para
> apenas **citar de passagem** no vídeo, ou pular, sem perder nada dos requisitos.

### 2.1 Varredura de segurança (opcional)
- **Objetivo do script `devsecops-scan.sh`:** passar quatro ferramentas de segurança (tudo via
  container, só precisa de Docker) e salvar os relatórios em `reports/` — *shift left*.
- **Rodar:**
  ```bash
  scripts/devsecops-scan.sh
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b></summary>

  ```bash
  mkdir -p reports
  SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"
  # 1) Hadolint: boas práticas em cada Dockerfile
  for svc in $SERVICES; do docker run --rm -i hadolint/hadolint < services/$svc/Dockerfile | tee reports/hadolint-$svc.txt; done
  # 2) Trivy (CVEs HIGH/CRITICAL) + 4) Syft (SBOM) em cada imagem local
  for svc in $SERVICES; do
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.cache/trivy:/root/.cache/" \
      aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed "togglemaster/$svc:local" | tee reports/trivy-$svc.txt
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/syft:latest \
      "togglemaster/$svc:local" -o spdx-json > reports/sbom-$svc.spdx.json
  done
  # 3) Trivy config: más configurações nos manifestos k8s
  docker run --rm -v "$PWD/k8s:/k8s:ro" aquasec/trivy:latest config /k8s | tee reports/trivy-k8s.txt
  # 5) Gitleaks: segredos vazados no repositório
  docker run --rm -v "$PWD:/repo:ro" zricethezav/gitleaks:latest detect --source /repo --no-banner -v | tee reports/gitleaks.txt
  ```
  </details>
- **Validar (🎥):**
  ```bash
  ls -1 reports/            # relatórios gerados
  ```
- **Fala no vídeo:** "Antes de publicar, rodo a esteira de segurança: **Hadolint** nos Dockerfiles, **Trivy** nas imagens e nos manifestos, **Syft** gerando o SBOM e **Gitleaks** procurando segredos vazados. Os relatórios ficam em `reports/`. A ideia é mover a segurança para o início do ciclo — *shift left*."

### 2.2 (conceito) Nenhum scan é obrigatório; o do ECR vem de brinde na Parte 2
Isto aqui é **só o conceito** — não tem comando para rodar agora, e **nenhum scan é exigido/pontuado**
pelo desafio. O que o enunciado exige de verdade é: na Parte 1, os **Dockerfiles + `docker compose`**;
na Parte 2, **criar os ECR e dar push** nas imagens.

O scan é sempre **extra**: no local, o Trivy/Hadolint (opcional, Bloco 2.1); e, quando você sobe a
imagem pro ECR (push, na nuvem), a AWS **escaneia automaticamente** porque os repositórios têm
`scanOnPush=true` — um **brinde** que vem ligado, mostrar é bônus. Como o ECR é um registro na nuvem,
**isso é Parte 2** (comandos no Bloco 3.3). Regra: **build é Parte 1; push/scan no ECR é Parte 2.**

---





# PARTE 2 — AWS (Kubernetes) · cobra por hora, faça num bloco contínuo

> A partir daqui os recursos cobram enquanto ligados (EKS, RDS, ElastiCache, NLB). Execute
> **Blocos 3 → 7 sem parar**: subir a infra, demonstrar a escalabilidade, gravar e **destruir** (Bloco 7.2).

## Pré-requisito da Parte 2 — conta AWS no plano PAGO (obrigatório)

O **plano Free** da AWS bloqueia este laboratório: só aceita EC2 *free-tier-eligible* (T4) e limita a **2 instâncias RDS**, mas o enunciado exige **3 RDS independentes** (T9). Por isso a conta precisa estar no **plano pago**. **Os créditos continuam valendo**: o custo sai deles primeiro, e o cartão só é cobrado depois que acabarem.

- **Fazer o upgrade:** Console → **Billing and Cost Management → Upgrade plan**.
- **Validar no Console:** **Billing and Cost Management** (página inicial ou **Free Tier**) → o plano aparece como **Paid** e os créditos continuam listados.
- **Validar na prática:** o teste definitivo é o 3º RDS do **3.4** ser criado sem `InstanceQuotaExceeded`.
- **Alerta de custo (recomendado):** **Billing → Budgets → Create budget**, por exemplo avisar quando passar de US$ 20.

**Estimativa de custo (us-east-1, tudo ligado):**
| Recurso | ~US$/hora |
|---|---|
| EKS (control plane) | 0,10 |
| 2 nós `m7i-flex.large` | 0,19 |
| NAT Gateway | 0,05 |
| 3 RDS `db.t3.micro` | 0,05 |
| ElastiCache `cache.t3.micro` | 0,02 |
| Load Balancer (NLB) | 0,02 |
| IPs públicos, discos e outros | 0,03 |
| **Total** | **~0,46/h (~US$ 11/dia)** |

Um dia de gravação (~8 h) custa **~US$ 4**, coberto pelos créditos. O custo só deixa de ser zero se o ambiente ficar ligado por semanas, por isso o **7.2 (destruir)** é obrigatório.

## Bloco 3 — Infraestrutura na AWS (começa a cobrar — tudo no mesmo dia)

### 3.1 Variáveis do laboratório
- **Criar:**
  ```bash
  cp infra/cloud.env.example infra/cloud.env
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  sed -i "s/^export AWS_ACCOUNT_ID=.*/export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}/" infra/cloud.env
  source infra/cloud.env
  ```
- **Validar:**
  ```bash
  echo "Região: $AWS_REGION | Cluster: $CLUSTER_NAME"   # sem mostrar o ACCOUNT_ID 🔐
  ```
- **Fala no vídeo:** "Centralizo as variáveis do laboratório no `cloud.env` — região, nome do cluster e número da conta — pra reaproveitar nos comandos seguintes."




### 3.2 Criar o cluster EKS 🎥 (demora ~15–20 min)
- **Contexto (ler antes de gravar — bom falar no vídeo):**

  - O enunciado exige **ter o cluster EKS**, mas **não impõe a ferramenta**. Dá para criar pelo Console, por Terraform ou pelo `eksctl`. Escolhemos o **`eksctl` (Opção B)** por ser o caminho mais simples e **reproduzível** (um comando, a partir de um arquivo declarativo).

  - O `eksctl`, por baixo, usa o **CloudFormation** (Infraestrutura como Código da AWS) para criar tudo. Isso **não é exigido** pelo desafio — é só o **mecanismo interno** da ferramenta. Não escrevemos CloudFormation; ele gera e gerencia as *stacks* por nós.

  - **Por que demora ~15–20 min:** ele cria uma infra inteira e espera cada parte: a **VPC** (subnets, rotas, NAT), o **control plane** do Kubernetes (redundante em várias zonas — o maior pedaço, ~10 min) e o **node group** (as EC2 dão boot e se registram). É infra de verdade, por isso é lento — não é travamento.


- **Tipo dos nós:** usamos **`m7i-flex.large`** (2 vCPU / 8 GB). Ele foi escolhido porque também é *free-tier-eligible* e funciona nos dois planos. No plano pago, o `t3.medium` também funcionaria. Se a conta ainda estiver no plano Free, confirme que o tipo está liberado (veja também o **Pré-requisito da Parte 2**):
  ```bash
  aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query "InstanceTypes[].InstanceType" --output text | tr '\t' '\n' | grep -x m7i-flex.large
  ```
  *(se não imprimir nada, escolha outro da lista com 2 vCPU e ≥ 4 GB — ex.: `c7i-flex.large` — e ajuste o `instanceType` no `infra/eksctl-cluster.yaml`).*

- **Pré-requisito (conta nova — rodar uma vez, antes do `eksctl`):** garantir que a *service-linked role* do Auto Scaling já existe e esperar ~2 min para propagar.
  ```bash
  aws iam get-role --role-name AWSServiceRoleForAutoScaling --query "Role.Arn" --output text \
    || { aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com && sleep 120; }
  ```
  > ⚠️ **Por quê:** em conta nova essa role é criada sozinha na primeira vez que um ASG nasce, mas demora a ficar utilizável. O EKS tenta usá-la antes da hora, o **ASG nunca é criado** e o node group fica preso em `CREATING` até o `eksctl` desistir com `exceeded max wait time for StackCreateComplete waiter`. Sintomas: `kubectl get nodes` → `No resources found`, nenhuma EC2 com a tag `eks:nodegroup-name=ng-apps`, e no CloudTrail o erro `ServiceLinkedRoleFailure: The Service-Linked Role for this Auto Scaling group is not yet ready for use.`


- **Criar:**
  ```bash
  eksctl create cluster -f infra/eksctl-cluster.yaml
  ```
  > 🛠️ **Se o node group travar mesmo assim** (status `CREATING` sem EC2), não precisa apagar o cluster — o control plane, a VPC e os addons já estão prontos. Crie a role acima e recrie só o node group:
  > ```bash
  > aws eks describe-nodegroup --cluster-name togglemaster --nodegroup-name ng-apps --query "nodegroup.status" --output text   # aguarde sair de CREATING
  > eksctl delete nodegroup --cluster togglemaster --name ng-apps --wait
  > eksctl create nodegroup -f infra/eksctl-cluster.yaml          # ~3–5 min
  > ```
  > Para achar a causa de qualquer falha de node group:
  > ```bash
  > aws cloudtrail lookup-events --max-results 50 --lookup-attributes AttributeKey=EventSource,AttributeValue=autoscaling.amazonaws.com --query "Events[].CloudTrailEvent" --output text | grep -o '"errorCode":"[^"]*","errorMessage":"[^"]*"' | sort -u
  > ```


  > 📕 **Deu erro neste passo?** Veja o **Apêndice — Troubleshooting do EKS**, no fim deste roteiro: os erros reais que pegamos (T1–T6), como diagnosticamos e como corrigimos.

- **Validar (🎥):**
  ```bash
  aws eks update-kubeconfig --name $CLUSTER_NAME > /dev/null   # 🔐 a saída mostra o nº da conta
  kubectl get nodes -o wide
  ```
  *(e no Console: EKS → cluster → aba **Compute** mostrando o node group com min 1 / desejado 2 / máx 4).*

- **Fala no vídeo:** "Pra criar o cluster, o enunciado deixa a ferramenta à escolha — eu uso o **`eksctl`**, que é a Opção B, porque com um comando e um arquivo declarativo eu subo tudo de forma reproduzível. Por baixo ele usa o CloudFormation da AWS pra orquestrar — isso é detalhe interno da ferramenta, não um requisito do desafio. Ele provisiona a VPC com subnets públicas e privadas, o node group com auto scaling de 1 a 4 nós — `m7i-flex.large`, que é elegível ao Free Tier — e já habilita o **OIDC**, que é o que destrava o IRSA mais à frente. Demora uns 15 a 20 minutos porque está nascendo um Kubernetes gerenciado redundante — os nós ficam em subnets privadas, por segurança."




### 3.3 Criar os 5 repositórios ECR + push das imagens 🎥

- **Objetivo do script `01-ecr-build-push.sh`:** criar os 5 repositórios no ECR (com scan no push),
  buildar a imagem de cada serviço forçando `linux/amd64` e publicar (push) com a tag `$IMAGE_TAG`.



- publicar as imagens no ECR

O que é: o ECR é o "Docker Hub privado" da AWS. O EKS vai baixar as imagens dos 5 serviços de lá. São as mesmas imagens que você rodou no docker compose na Parte 1.

O que o script 01-ecr-build-push.sh faz:
1. Login: autentica o Docker no ECR com uma senha temporária.
2. Depois, para cada um dos 5 serviços:
   - Cria o repositório, se ainda não existir. Ele vem com o scan de vulnerabilidades no push ligado (scanOnPush) e com criptografia AES256.
   - Faz o build da imagem para linux/amd64, a mesma arquitetura dos nós m7i-flex.large.
   - Faz o push da imagem para o repositório.
3. Lista as 5 imagens publicadas.





- **Criar:**
  ```bash
  scripts/01-ecr-build-push.sh
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b></summary>


  ```bash
  source infra/cloud.env            # precisa de AWS_ACCOUNT_ID, AWS_REGION, IMAGE_TAG
  REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  # autentica o docker no ECR (senha temporária via stdin)
  aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
  for svc in auth-service flag-service targeting-service evaluation-service analytics-service; do

    # cria o repositório só se ainda não existir, com scan automático no push
    aws ecr describe-repositories --repository-names "$svc" >/dev/null 2>&1 || \
      aws ecr create-repository --repository-name "$svc" --image-scanning-configuration scanOnPush=true
    docker build --platform linux/amd64 -t "$REGISTRY/$svc:$IMAGE_TAG" "services/$svc"
    docker push "$REGISTRY/$svc:$IMAGE_TAG"
  done
  ```
  </details>

- **Validar (🎥):**
  ```bash
  aws ecr describe-repositories --query 'repositories[].repositoryName' --output table
  ```
- **(Opcional, bônus) Mostrar o scan de vulnerabilidades no vídeo (🎥):** (não é exigido — ver Bloco 2.2)
  ```bash
  aws ecr describe-image-scan-findings --repository-name evaluation-service --image-id imageTag=${IMAGE_TAG} --query 'imageScanFindingsSummary'
  ```
  *(o scan leva alguns segundos após o push; se vier "SCAN_IN_PROGRESS", rode de novo em instantes.)*
- **Fala no vídeo:** "Este script cria os **5 repositórios ECR**, faz o build das imagens de cada serviço e dá push. Como os repositórios sobem com `scanOnPush` ligado, **toda imagem publicada é escaneada automaticamente** pela AWS — e, como bônus, com o `describe-image-scan-findings` eu trago o resumo dos achados por severidade direto do ECR. É segurança integrada ao pipeline de publicação, sem passo manual."





### 3.4 Criar os 3 RDS PostgreSQL 🎥

> ⚠️ **Rode o 3.4 e o 3.5 no MESMO terminal** — as variáveis `RDS_SG`/`REDIS_SG` criadas aqui só existem nele.

- **Criar — passo 1: senha do banco** (o `cloud.env.example` vem com `DB_PASSWORD=` vazio; use só letras e números — o RDS rejeita `/ @ "` e espaço):
  ```bash
  grep -q '^export DB_PASSWORD=.\+' infra/cloud.env || sed -i "s|^export DB_PASSWORD=.*|export DB_PASSWORD=$(openssl rand -hex 16)|" infra/cloud.env
  source infra/cloud.env
  ```




- **Criar — passo 2: rede dos bancos** (security groups que só aceitam o cluster + subnet groups nas subnets privadas; o Redis do 3.5 usa os mesmos):
  ```bash

  VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)
  CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
  PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:kubernetes.io/role/internal-elb,Values=1 --query 'Subnets[].SubnetId' --output text)
  RDS_SG=$(aws ec2 create-security-group --group-name togglemaster-rds-sg --description "PostgreSQL acessivel somente pelo EKS" --vpc-id $VPC_ID --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --source-group $CLUSTER_SG
  REDIS_SG=$(aws ec2 create-security-group --group-name togglemaster-redis-sg --description "Redis acessivel somente pelo EKS" --vpc-id $VPC_ID --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id $REDIS_SG --protocol tcp --port 6379 --source-group $CLUSTER_SG
  aws rds create-db-subnet-group --db-subnet-group-name togglemaster-db-subnets --db-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS
  aws elasticache create-cache-subnet-group --cache-subnet-group-name togglemaster-redis-subnets --cache-subnet-group-description "Subnets privadas do EKS" --subnet-ids $PRIVATE_SUBNETS
  ```
  *(descrição de Security Group **sem acento** — a AWS rejeita caracteres não ASCII).*



- **Criar — passo 3: os 3 bancos** (`db.t3.micro` = Free Tier) e aguardar ~5–10 min:
  ```bash
  for svc in auth:auth_db flag:flags_db targeting:targeting_db; do
    name=${svc%%:*}; db=${svc##*:}
    aws rds create-db-instance --db-instance-identifier togglemaster-$name-db \
      --engine postgres --db-instance-class db.t3.micro --allocated-storage 20 --storage-type gp3 \
      --master-username "$DB_USER" --master-user-password "$DB_PASSWORD" --db-name $db \
      --db-subnet-group-name togglemaster-db-subnets --vpc-security-group-ids $RDS_SG \
      --no-publicly-accessible --no-multi-az --backup-retention-period 0 --storage-encrypted \
      --tags Key=project,Value=togglemaster >/dev/null && echo "criando togglemaster-$name-db"
  done
  for n in auth flag targeting; do aws rds wait db-instance-available --db-instance-identifier togglemaster-$n-db; done
  ```
  > ⚠️ **Erro que pegamos (T7):** rodar só o `aws rds wait` dá `DBInstanceNotFound` — o `wait` **apenas espera**, não cria. Rode os passos 1–3 antes.



- **Validar (🎥):**
  ```bash
  aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' --output table
  ```
- **Fala no vídeo:** "Crio **três instâncias RDS PostgreSQL independentes** — uma para o auth, uma para o flag e uma para o targeting. O enunciado pede bancos separados porque cada microsserviço é dono do seu dado: é o padrão *database per service*. Os bancos só aceitam conexão do security group do cluster."





### 💡 Para que servem o Redis e o DynamoDB? (entenda antes do 3.5 e 3.6)

Pense num **restaurante**:

| Serviço | Analogia | O que faz no ToggleMaster | Tipo de dado |
|---|---|---|---|
| **RDS** (PostgreSQL) | o **estoque** | guarda os dados principais: usuários/API keys, flags e regras | permanente, relacional |
| **Redis** (ElastiCache) | a **bancada do cozinheiro** — os pratos mais pedidos já ficam prontos, à mão | **cache** do `evaluation-service`: guarda a resposta "a flag está ligada?" na memória, para não ir ao banco toda vez | temporário (se apagar, busca de novo no RDS) |
| **DynamoDB** | o **caderno de pedidos** — anota tudo o que foi servido | guarda **cada evento** de avaliação (usuário, flag, resultado, horário), gravado pelo `analytics-service` | permanente, muitos registros simples |

**Como os dados circulam:**
```
usuário → evaluation ──pergunta──▶ Redis (cache) ──se não tiver──▶ RDS
              │
              └─publica evento─▶ SQS ─▶ analytics ─grava─▶ DynamoDB
```

**Por que cada um:**
- **Redis:** o `evaluation` é chamado o tempo todo (*hot path*). Respondendo da memória, ele fica muito mais rápido e tira carga dos bancos.
- **DynamoDB:** os eventos são muitos e simples. Ele escala sozinho e cobra só pelo uso (*pay-per-request*). É ele que prova, no **6.3**, que o fluxo assíncrono funcionou.

> **Resumo em uma linha (bom para a fala 10 do vídeo):** "**RDS** guarda os dados principais, **Redis** responde rápido da memória e **DynamoDB** guarda o histórico de tudo o que aconteceu."

> ⏱️ **Ganhe tempo:** enquanto o `rds wait` do 3.4 está rodando (ele fica **calado** por ~5–10 min e só imprime a tabela no fim), abra **outro terminal** e faça o **3.5 e o 3.6**. Eles não dependem dos bancos.

### 3.5 Criar o ElastiCache Redis 🎥 (~5–10 min)
- **Criar** (funciona em terminal novo: recarrega as variáveis e recupera o `REDIS_SG` criado no 3.4, passo 2):
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  REDIS_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-redis-sg --query 'SecurityGroups[0].GroupId' --output text)
  aws elasticache create-replication-group --replication-group-id togglemaster-redis --replication-group-description "Cache do evaluation-service" --engine redis --cache-node-type cache.t3.micro --num-cache-clusters 1 --cache-subnet-group-name togglemaster-redis-subnets --security-group-ids $REDIS_SG --transit-encryption-enabled --at-rest-encryption-enabled --tags Key=project,Value=togglemaster >/dev/null && echo "criando redis"
  ```
  *(o `create-replication-group` cria o Redis; o `wait` abaixo só espera — ver T7).*
- **Validar (🎥):**
  ```bash
  aws elasticache wait replication-group-available --replication-group-id togglemaster-redis
  aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --query 'ReplicationGroups[0].Status'   # esperado: "available"
  ```
- **Fala no vídeo:** "O ElastiCache é o Redis gerenciado. O serviço de avaliação usa ele como cache do *hot path* — a resposta `true/false` sai do cache em vez de bater no banco toda hora. A conexão é via TLS (`rediss://`)."





### 3.6 Criar a tabela DynamoDB (nuvem) 🎥 (instantâneo)
- **Criar** (pode ser no mesmo terminal do 3.5; fica pronta na hora):
  ```bash
  aws dynamodb create-table --table-name ToggleMasterAnalytics --attribute-definitions AttributeName=event_id,AttributeType=S --key-schema AttributeName=event_id,KeyType=HASH --billing-mode PAY_PER_REQUEST
  ```
- **Validar (🎥):**
  ```bash
  aws dynamodb describe-table --table-name ToggleMasterAnalytics --query 'Table.TableStatus'   # esperado: "ACTIVE"
  ```
- **Fala no vídeo:** "A mesma tabela que rodou local agora é criada no DynamoDB gerenciado, em modo *pay-per-request* — pago só pelo que uso, sem provisionar capacidade."




### 3.7 Anotar as connection strings
- **O que é:** cada banco e o Redis têm um **endereço** (*endpoint*, ex.: `togglemaster-auth-db.xxxx.us-east-1.rds.amazonaws.com`). Gravamos esses endereços no `infra/cloud.env`, e no **5.1** o script de Secrets os entrega aos pods. As linhas de `MASTER_KEY`/`SERVICE_API_KEY` geram as chaves da aplicação, mas só se ainda estiverem vazias.
- **Fazer** (preenche tudo automaticamente):
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  set_env(){ sed -i "s|^export $1=.*|export $1=$2|" infra/cloud.env; }
  for n in auth flag targeting; do
    set_env RDS_${n^^}_ENDPOINT "$(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db --query 'DBInstances[0].Endpoint.Address' --output text)"
  done
  set_env REDIS_URL "rediss://$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text):6379"
  grep -q '^export MASTER_KEY=.\+' infra/cloud.env || set_env MASTER_KEY "$(openssl rand -hex 16)"
  grep -q '^export SERVICE_API_KEY=.\+' infra/cloud.env || set_env SERVICE_API_KEY "tm_key_$(openssl rand -hex 32)"
  source infra/cloud.env
  ```
- **Validar (🔐 sem expor valores):**
  ```bash
  grep -E '^export (RDS_|REDIS_|AWS_SQS_URL|MASTER_KEY|SERVICE_API_KEY)' infra/cloud.env | sed 's/=.*/=<preenchido>/'
  grep -E '^export (RDS_|REDIS_URL)' infra/cloud.env | grep -E 'None|=$|xxxx' || echo "OK: todos os endpoints preenchidos"
  ```
  > ⚠️ O 1º comando só prova que a **linha existe** (mostra `<preenchido>` até se o valor for `None`). O 2º é o que confirma: precisa imprimir `OK: todos os endpoints preenchidos`. Se listar alguma linha, aquele recurso ainda não estava `available`: espere e rode o **Fazer** de novo.
- **Fala no vídeo:** "Anoto os endpoints de cada recurso no `cloud.env`. Esses valores viram os **Secrets** do Kubernetes no próximo passo — nunca ficam no código."

---


O que é: os bancos e o Redis que você criou têm, cada um, um endereço (o endpoint), algo como togglemaster-auth-db.xxxx.us-east-1.rds.amazonaws.com. Os serviços no Kubernetes precisam saber esse endereço para se conectar.

No 3.7 você pega esses endereços na AWS e grava no infra/cloud.env. No 5.1, o script de Secrets lê esse arquivo e entrega os endereços aos pods.

Para preencher tudo automaticamente:

cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
set_env(){ sed -i "s|^export $1=.*|export $1=$2|" infra/cloud.env; }
for n in auth flag targeting; do
  set_env RDS_${n^^}_ENDPOINT "$(aws rds describe-db-instances --db-instance-identifier togglemaster-$n-db --query 'DBInstances[0].Endpoint.Address' --output text)"
done
set_env REDIS_URL "rediss://$(aws elasticache describe-replication-groups --replication-group-id togglemaster-redis --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text):6379"
grep -q '^export MASTER_KEY=.\+' infra/cloud.env || set_env MASTER_KEY "$(openssl rand -hex 16)"
grep -q '^export SERVICE_API_KEY=.\+' infra/cloud.env || set_env SERVICE_API_KEY "tm_key_$(openssl rand -hex 32)"
source infra/cloud.env

As linhas do MASTER_KEY e do SERVICE_API_KEY geram as chaves da aplicação, que também estavam vazias. Elas só geram se ainda não tiverem valor.

Validação (🎥, sem mostrar os valores):

grep -E '^export (RDS_|REDIS_|AWS_SQS_URL|MASTER_KEY|SERVICE_API_KEY)' infra/cloud.env | sed 's/=.*/=<preenchido>/'
Todas as linhas devem aparecer como <preenchido>. Se o comando que pega o endpoint de algum banco ou do Redis devolver None, aquele recurso ainda não está available. Espere e rode de novo.







## Bloco 4 — Preparar o cluster

### 4.1 kubeconfig + Metrics Server 🎥
- **Criar:**
  ```bash
  aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl -n kube-system rollout status deploy/metrics-server
  ```
- **Validar (🎥):**
  ```bash
  kubectl top nodes
  ```
- **Fala no vídeo:** "Conecto o `kubectl` ao cluster e instalo o **Metrics Server**, que coleta CPU e memória dos pods. Sem ele o HPA não tem como medir carga. O `kubectl top nodes` já mostrando consumo confirma que está funcionando."




### 4.2 IRSA — permissões dos serviços (melhor prática de segurança)

> ✅ **É exigido?** Não literalmente: o enunciado só **recomenda IRSA** para o controller do Ingress (4.3). Mas os pods **precisam de alguma credencial AWS** para falar com a SQS e o DynamoDB; sem ela dão `AccessDenied`, e as cenas de KEDA e DynamoDB (6.2/6.3) não funcionam. Escolhemos o IRSA por ser a **melhor prática**:
>
> | Opção | Funciona? | Segurança |
> |---|---|---|
> | **IRSA** (adotado) | ✅ | ✅ melhor prática: sem chave, credencial temporária, mínimo privilégio por serviço |
> | Access key dentro de um Secret | ✅ | ❌ chave fixa que pode vazar |
> | Permissão na role dos nós | ✅ | ⚠️ todos os pods do nó ganham o acesso |

- **O que é (simples):** alguns pods precisam acessar a AWS — o **evaluation** envia na SQS e o **analytics** lê a SQS e grava no DynamoDB. Em vez de colocar uma *access key* dentro do pod (inseguro), cada pod recebe um **"crachá"**: uma **role IAM** com só a permissão necessária, ligada à **service account** dele. A AWS entrega uma credencial **temporária**, que se renova sozinha. Isso funciona graças ao **OIDC** ligado no cluster (`withOIDC: true`). O IRSA do KEDA fica no **4.4**.


- **Criar** (namespaces → políticas IAM → service accounts com role):
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  kubectl apply -f k8s/00-namespaces.yaml
  for p in evaluation-sqs-send:TogglemasterEvaluationSQS analytics-sqs-dynamodb:TogglemasterAnalyticsSQSDynamo keda-sqs-read:TogglemasterKedaSQS; do
    f=${p%%:*}; n=${p##*:}
    sed "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" infra/iam/$f.json > /tmp/$f.json
    aws iam create-policy --policy-name $n --policy-document file:///tmp/$f.json >/dev/null && echo "policy $n criada"
  done
  eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace togglemaster-evaluation --name evaluation-service-sa --role-name togglemaster-evaluation-irsa --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterEvaluationSQS --override-existing-serviceaccounts --approve
  eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace togglemaster-analytics --name analytics-service-sa --role-name togglemaster-analytics-irsa --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterAnalyticsSQSDynamo --override-existing-serviceaccounts --approve
  ```
  > ⚠️ **Erro que pegamos (T10):** rodar só o **Validar** dá `namespaces "togglemaster-evaluation" not found` — os namespaces e as service accounts ainda não existiam. Rode o **Criar** antes.
  > *(Se a política já existir, o `create-policy` dá `EntityAlreadyExists`: pode ignorar.)*


- **Validar:**
  ```bash
  kubectl get sa -n togglemaster-evaluation evaluation-service-sa -o jsonpath='{.metadata.annotations}'; echo
  ```
- **Fala no vídeo:** "Aqui uso **IRSA**: cada service account do Kubernetes é associada a um papel IAM via OIDC. Assim o pod do analytics acessa a SQS e o DynamoDB **sem chave nenhuma** — a credencial é temporária e injetada pela AWS. É o jeito seguro, sem *access key* dentro do cluster."




### 4.3 AWS Load Balancer Controller + NGINX Ingress 🎥
- **O que é:** o **NGINX Ingress** é a "portaria" do cluster: recebe todo o tráfego externo e encaminha cada rota (`/auth`, `/flags`...) ao serviço certo. Para ser acessível da internet, ele precisa de um **Load Balancer (NLB)** da AWS, e quem cria esse NLB é o **AWS Load Balancer Controller**, que usa IRSA (é a recomendação do enunciado).


- **Criar — passo 1: AWS Load Balancer Controller (com IRSA):**
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)
  curl -sSL -o /tmp/lbc-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/lbc-policy.json >/dev/null && echo "policy criada"
  eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace kube-system --name aws-load-balancer-controller --role-name togglemaster-lbc-irsa --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --approve
  helm repo add eks https://aws.github.io/eks-charts && helm repo update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=$CLUSTER_NAME --set region=$AWS_REGION --set vpcId=$VPC_ID --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
  kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
  ```


- **Criar — passo 2: NGINX Ingress exposto por NLB:**
  ```bash
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
  ```

  > **Plano B** (se o LB Controller der problema): `helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace`. Sem as anotações, a AWS cria um Load Balancer "clássico", o que já atende ao "Nginx Ingress funcionando".
  > ⚠️ **Erro que pegamos (T11):** rodar só o **Validar** dá `namespaces "ingress-nginx" not found`, porque o Ingress ainda não tinha sido instalado. Rode o **Criar** antes.


- **Validar (🎥):**
  ```bash
  kubectl -n ingress-nginx get svc ingress-nginx-controller   # espere o EXTERNAL-IP (DNS do NLB)
  ```

- **Fala no vídeo:** "Instalo o NGINX Ingress Controller, que a AWS expõe através de um Network Load Balancer. É esse o ponto único de entrada do cluster: todas as rotas externas passam por ele."







### 4.4 KEDA
- **Criar** (role IRSA do KEDA para ler a fila + instalação via Helm; a política `TogglemasterKedaSQS` foi criada no 4.2):
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace keda --name keda-operator --role-name togglemaster-keda-irsa --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TogglemasterKedaSQS --role-only --approve
  helm repo add kedacore https://kedacore.github.io/charts && helm repo update
  helm upgrade --install keda kedacore/keda -n keda --create-namespace --set podIdentity.aws.irsa.enabled=true --set podIdentity.aws.irsa.roleArn=arn:aws:iam::$AWS_ACCOUNT_ID:role/togglemaster-keda-irsa
  ```
- **Validar:**
  ```bash
  kubectl -n keda get pods
  ```
- **Fala no vídeo:** "Instalo o **KEDA**, que é o que vai permitir o analytics escalar a partir do tamanho da fila SQS, inclusive descendo até **zero** pod quando não há evento."

---



## Bloco 5 — Deploy dos microsserviços

### 5.1 Gerar os Secrets
- **Objetivo do script `05-gerar-secrets.sh`:** montar os arquivos de Secret (valores em base64) de
  cada serviço a partir do `cloud.env`, gravando em `k8s/generated/` (no `.gitignore`). Não aplica nada.


- **Criar:**
  ```bash
  scripts/05-gerar-secrets.sh
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b> (exemplo do auth; o script faz um por serviço)</summary>

  ```bash

  source infra/cloud.env
  mkdir -p k8s/generated && chmod 700 k8s/generated
  # --dry-run=client NÃO cria no cluster: só gera o YAML (já em base64) no arquivo
  kubectl create secret generic auth-service-secret -n togglemaster-auth \
    --from-literal=DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${RDS_AUTH_ENDPOINT}:5432/auth_db?sslmode=require" \
    --from-literal=MASTER_KEY="${MASTER_KEY}" \
    --from-literal=SERVICE_API_KEY="${SERVICE_API_KEY}" \
    --dry-run=client -o yaml > k8s/generated/auth-secret.yaml
  # repetir para flag-service, targeting-service, evaluation-service e analytics-service
  # (cada um com suas variáveis — ver scripts/05-gerar-secrets.sh)

  </details>


- **Validar:**
  ```bash
  kubectl get secret -A | grep togglemaster
  ```
- **Fala no vídeo:** "Os Secrets são gerados a partir do `cloud.env` e aplicados em cada namespace, em base64. Faço questão de comentar: **base64 não é criptografia** — qualquer um com `kubectl get secret` decodifica. Por isso o acesso é restrito por RBAC e, em produção, entraria um cofre como o Secrets Manager."



### 5.2 Deploy dos 5 serviços 🎥

- **Objetivo do script `06-deploy-k8s.sh`:** aplicar todos os manifestos na ordem certa de
  dependência (namespaces → secrets → configmaps → jobs de tabela → deployments/services/ingress →
  HPA/KEDA), usando o `render.sh` para trocar os placeholders pelos valores reais.
- **Criar:**
  ```bash
  scripts/06-deploy-k8s.sh
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b></summary>

  ```bash
  source infra/cloud.env
  R(){ scripts/render.sh "$1" | kubectl apply -f -; }   # render troca ${...} e aplica
  R k8s/00-namespaces.yaml
  kubectl apply -f k8s/generated/                       # secrets (já prontos, sem placeholder)
  for d in 01-auth 02-flag 03-targeting 04-evaluation 05-analytics; do R k8s/$d/configmap.yaml; done
  for d in 01-auth 02-flag 03-targeting; do R k8s/$d/db-init-job.yaml; done   # cria tabelas nos 3 RDS
  kubectl wait --for=condition=complete job/auth-service-db-init -n togglemaster-auth --timeout=180s
  # (idem para flag e targeting)
  for d in 01-auth 02-flag 03-targeting 04-evaluation 05-analytics; do
    R k8s/$d/deployment.yaml; R k8s/$d/service.yaml
    [ -f k8s/$d/ingress.yaml ] && R k8s/$d/ingress.yaml
  done
  R k8s/04-evaluation/hpa.yaml
  R k8s/05-analytics/keda-scaledobject.yaml   # ou k8s/alternativas/analytics-hpa-cpu.yaml se não houver KEDA
  ```
  </details>


- **Validar (🎥):**
  ```bash
  kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster
  kubectl get svc,ingress -A | grep togglemaster
  ```
- **Fala no vídeo:** "Aplico os manifestos: **Namespace** por serviço, **Deployment** apontando pra imagem do ECR, **Service ClusterIP**, **ConfigMap** com as URLs internas e **Ingress** com as rotas. Cada Deployment tem requests/limits e probes de readiness e liveness. Os pods ficando `Running` mostram que todos conectaram nos bancos e no Redis."




### 5.3 Testar pelo Load Balancer 🎥
- **Criar / rodar:**
  ```bash
  LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  curl -s http://$LB/auth/health
  ```
- **Validar (🎥):** a resposta de `health` de cada rota (`/auth`, `/flags`, `/rules`, `/evaluate`).
- **Fala no vídeo:** "Pego o DNS do Load Balancer e chamo as rotas via Ingress. Cada `/health` respondendo prova que o tráfego externo chega aos pods certos, roteado por caminho. É a arquitetura inteira respondendo pela porta da frente."

---



## Bloco 6 — Escalabilidade (a prova principal do vídeo)

### 6.1 HPA — escalar o evaluation por CPU 🎥
- **Rodar (em um terminal):**
  ```bash
  kubectl get hpa -n togglemaster-evaluation -w
  ```

- **Gerar carga (em outro terminal):**
  ```bash
  scripts/carga-evaluation.sh <DNS-do-LoadBalancer> 180 50
  ```
  <details><summary><b>Objetivo + sem o script</b></summary>

  **Objetivo do `carga-evaluation.sh`:** disparar muitas requisições ao `/evaluate` por N segundo  para subir a CPU do evaluation e acionar o HPA. Equivalente cru:
  
```bash
  LB=<DNS-do-LoadBalancer>
  hey -z 180s -c 50 "http://$LB/evaluate?user_id=user-carga&flag_name=enable-new-dashboard"
  # sem o hey instalado:
  # docker run --rm williamyeh/hey -z 180s -c 50 "http://$LB/evaluate?user_id=user-carga&flag_name=enable-new-dashboard"
  ```
  </details>


cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
LB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LB=$LB"
scripts/carga-evaluation.sh $LB 180 50





- **Validar (🎥):**
  ```bash
  kubectl get pods -n togglemaster-evaluation -w     # réplicas aumentando

  ```
- **Fala no vídeo:** "Agora a escalabilidade reativa. Jogo carga no serviço de avaliação com o `hey`. O HPA mede a CPU pelo Metrics Server e, ao passar de 70%, cria réplicas novas — de 1 até 6. É o modelo clássico: o serviço está sempre ligado e cresce conforme o processamento."



### 6.2 KEDA — escalar o analytics pela fila SQS 🎥
- **Rodar (em um terminal):**
  ```bash
  kubectl get scaledobject,hpa,pods -n togglemaster-analytics -w
  ```
- **Gerar carga (em outro terminal):**
  ```bash
  scripts/sqs-enviar-mensagens.sh 100          # 100 lotes de 10 = 1000 mensagens
  ```
  <details><summary><b>Objetivo + sem o script</b></summary>

  **Objetivo do `sqs-enviar-mensagens.sh`:** encher a fila SQS com mensagens no formato que o
  analytics espera, para o KEDA detectar o acúmulo e escalar de 0→N. O script manda em lotes de 10
  (`send-message-batch`) para ser rápido. Versão simples (1 por chamada):
  ```bash
  source infra/cloud.env
  for i in $(seq 1 500); do
    aws sqs send-message --queue-url "$AWS_SQS_URL" \
      --message-body "{\"user_id\":\"user-$i\",\"flag_name\":\"enable-new-dashboard\",\"result\":true,\"timestamp\":\"$(date -u +%FT%TZ)\"}" >/dev/null
  done
  aws sqs get-queue-attributes --queue-url "$AWS_SQS_URL" --attribute-names ApproximateNumberOfMessages
  ```
  </details>
- **Validar (🎥):** os pods do analytics saindo de **0** e subindo conforme as mensagens; depois voltando a 0.
- **Fala no vídeo:** "Aqui está o contraste. O analytics começa em **zero pod** — sem evento, não consome recurso nenhum. Eu encho a fila SQS de mensagens e o **KEDA** detecta o acúmulo e sobe os pods de 0 pra N, a cerca de 5 mensagens por pod. Quando a fila esvazia, ele volta pra zero. Escala **dirigida por evento**, não por CPU."


# Como executar o teste: 

terminar 1 :

cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
kubectl get pods -n togglemaster-analytics -w


terminar 2: 

root@OxCisco:/home/wmoya/ToggleMaster-Fase2# cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
scripts/sqs-enviar-mensagens.sh 300
lotes enviados: 300/300 (3000 mensagens)
----------------------------------------
|          GetQueueAttributes          |
+-------------------------------+------+
|  ApproximateNumberOfMessages  |  240 |
+-------------------------------+------+
root@OxCisco:/home/wmoya/ToggleMaster-Fase2#


Terminar 3: 

root@OxCisco:/home/wmoya/ToggleMaster-Fase2# aws dynamodb scan --table-name ToggleMasterAnalytics --select COUNT






### 6.3 Confirmar a gravação no DynamoDB 🎥
- **Validar (🎥):**
  ```bash
  aws dynamodb scan --table-name ToggleMasterAnalytics --select COUNT
  aws dynamodb scan --table-name ToggleMasterAnalytics --max-items 3
  ```
- **Fala no vídeo:** "Fecho mostrando que o que entrou na fila realmente virou registro: a contagem na tabela DynamoDB subiu e aqui estão alguns itens gravados pelo analytics."

---



## Bloco 7 — Encerramento

### 7.1 Explicação de arquitetura e decisões (falar, sem comando)

- **Fala no vídeo:** "Pra fechar: escolhi dois modelos de escala de propósito — **HPA por CPU** no avaliador, que é o hot path sempre ativo, e **KEDA por fila** no analytics, que é trabalho em lote e pode ficar em zero. Separei os dados por serviço: **RDS** para dados relacionais e transacionais, **ElastiCache** para cache de baixa latência e **DynamoDB** para os eventos de analytics, que são muitos e simples. A segurança está em camadas: imagens distroless não-root, Secrets por RBAC, IRSA sem chave fixa e scan de imagem no ECR."





### 7.2 Destruir o ambiente 🎥
- **Objetivo do script `99-destruir-ambiente.sh`:** remover TUDO que gera custo, na ordem certa de
  dependência (primeiro o Ingress, que apaga o NLB; por último o cluster, que leva VPC/subnets/roles).
- **Rodar:**
  ```bash
  scripts/99-destruir-ambiente.sh
  ```
  <details><summary><b>Sem o script — comandos equivalentes</b> (a ordem importa)</summary>

  ```bash
  source infra/cloud.env
  helm uninstall ingress-nginx -n ingress-nginx; sleep 60          # apaga o Load Balancer (NLB)
  kubectl delete ns togglemaster-auth togglemaster-flag togglemaster-targeting togglemaster-evaluation togglemaster-analytics
  helm uninstall keda -n keda; helm uninstall aws-load-balancer-controller -n kube-system
  for db in togglemaster-auth-db togglemaster-flag-db togglemaster-targeting-db; do
    aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups; done
  aws elasticache delete-replication-group --replication-group-id togglemaster-redis
  aws dynamodb delete-table --table-name ToggleMasterAnalytics
  aws sqs delete-queue --queue-url "$AWS_SQS_URL"
  for r in auth-service flag-service targeting-service evaluation-service analytics-service; do
    aws ecr delete-repository --repository-name $r --force; done
  eksctl delete cluster -f infra/eksctl-cluster.yaml --wait        # por último: VPC, subnets, roles IRSA
  ```
  </details>
- **Validar — confira recurso por recurso (🎥).** Cada comando abaixo deve voltar **vazio** (`[]`, `None` ou sem a linha do recurso). Rode todos:
  ```bash
  eksctl get cluster                                                                                   # sem o cluster togglemaster
  aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text             # vazio
  aws elasticache describe-replication-groups --query 'ReplicationGroups[].ReplicationGroupId' --output text  # vazio
  aws dynamodb list-tables --query 'TableNames' --output text                                          # sem ToggleMasterAnalytics
  aws sqs list-queues --queue-name-prefix togglemaster --query 'QueueUrls' --output text               # vazio (apaga a fila por último)
  aws ecr describe-repositories --query 'repositories[].repositoryName' --output text                  # vazio (os 5 repos)
  ```
- **⚠️ Os "esquecidos" que continuam cobrando sozinhos** (confira SEMPRE — cada um deve voltar vazio):
  ```bash
  aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId' --output text     # NAT Gateway cobra/hora
  aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].PublicIp' --output text                              # Elastic IP solto cobra
  aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text                               # NLB/ALB do Ingress
  aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text                      # LB clássico (se houver)
  aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text               # EBS órfão (disco solto)
  aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName,'eksctl-togglemaster')].StackName" --output text   # stacks do eksctl
  ```
  Se algum desses **não** voltar vazio, o recurso ficou pra trás — apague manualmente (ex.: `aws ec2 delete-nat-gateway --nat-gateway-id <id>`, `aws ec2 release-address --allocation-id <id>`, `aws ec2 delete-volume --volume-id <id>`) e rode o `99-destruir-ambiente.sh` de novo.

- **Checklist de custo zero (confirme todos ✅ antes de encerrar):**
  - [ ] `eksctl get cluster` sem o cluster
  - [ ] 0 instâncias EC2 ligadas (nós do cluster) — `aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==\`running\`].InstanceId' --output text` vazio
  - [ ] 0 RDS · 0 ElastiCache · 0 tabela DynamoDB · 0 fila SQS · 0 repositório ECR
  - [ ] 0 NAT Gateway · 0 Elastic IP solto · 0 Load Balancer · 0 EBS órfão
  - [ ] 0 stack `eksctl-togglemaster-*` no CloudFormation
  - [ ] **No dia seguinte:** conferir no Console → **Billing / Cost Explorer** que não há custo acumulando

- **Fala no vídeo:** "Por fim, destruo **tudo** que cobra por hora, na ordem certa — primeiro o Ingress, que remove o Load Balancer, depois apps, bancos e cache, e por último o cluster, que leva junto a VPC, as subnets e as roles. E não basta rodar o script: eu confirmo **recurso por recurso** que nada sobrou — incluindo os que costumam ficar esquecidos cobrando, como NAT Gateway, Elastic IP e discos EBS soltos. É a disciplina de custo que o laboratório exige."

---


### Checklist de cenas que o vídeo precisa conter (pág. 9 do PDF)
1. 🎥 `docker compose ps` com 9 containers
2. 🎥 Cluster EKS no console + `kubectl get nodes`
3. 🎥 `kubectl get pods` com os 5 microsserviços
4. 🎥 `curl` no Load Balancer passando pelo Ingress
5. 🎥 Carga no evaluation → HPA/pods subindo
6. 🎥 Mensagens na SQS → KEDA escalando o analytics de 0 a N
7. 🎥 Itens na tabela DynamoDB
8. 🎥 Fala: arquitetura e desafios
9. 🎥 Fala: por que KEDA no analytics
10. 🎥 Fala: diferença entre RDS, ElastiCache e DynamoDB

---


# Apêndice — Troubleshooting do EKS (erros reais que pegamos)

Registro dos problemas encontrados ao executar o **Bloco 3.2** (27/10/2026, eksctl 0.231, conta AWS pessoal recém-criada), na ordem em que aconteceram: **sintoma → diagnóstico → causa → correção**.

> 💡 **Fala extra (opcional, vale ponto em "desafios"):** "Na primeira subida o node group travou: o cluster nasceu, mas nenhuma máquina subiu. Investigando pelo CloudTrail, descobri que a *service-linked role* do Auto Scaling ainda não estava pronta numa conta nova. Criei a role antes e recriei só o node group, sem precisar apagar o cluster."

### Kit de diagnóstico do node group (rodar nesta ordem)
Cada comando responde uma pergunta. **Copie cada um numa linha só** (ver T6).
```bash
# 1) Qual o status e há issues de saúde?
aws eks describe-nodegroup --cluster-name togglemaster --nodegroup-name ng-apps --query "nodegroup.{status:status,asg:resources.autoScalingGroups[0].name,issues:health.issues}"
# 2) Há quanto tempo está criando? (createdAt vem em -03:00; o date em UTC)
aws eks describe-nodegroup --cluster-name togglemaster --nodegroup-name ng-apps --query "nodegroup.createdAt" --output text; date -u
# 3) Alguma EC2 do node group existe?
aws ec2 describe-instances --filters "Name=tag:eks:nodegroup-name,Values=ng-apps" --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
# 4) Os nós entraram no Kubernetes?
aws eks update-kubeconfig --name togglemaster > /dev/null && kubectl get nodes -o wide
# 5) O que o Auto Scaling registrou no CloudTrail (últimos 30 min)? — chamadas e erros
aws cloudtrail lookup-events --start-time $(date -u -d '30 min ago' +%FT%TZ) --lookup-attributes AttributeKey=EventSource,AttributeValue=autoscaling.amazonaws.com --query "Events[].CloudTrailEvent" --output text | grep -o '"eventName":"[^"]*"\|"errorCode":"[^"]*","errorMessage":"[^"]*"' | sort | uniq -c
# 6) O ASG tentou lançar EC2 e falhou? (erro de lançamento NÃO aparece no CloudTrail, só aqui)
ASG=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName,'ng-apps')].AutoScalingGroupName | [0]" --output text); echo "ASG: $ASG"; aws autoscaling describe-scaling-activities --auto-scaling-group-name "$ASG" --max-items 5 --query "Activities[].[StartTime,StatusCode,StatusMessage]" --output table
# 7) Eventos com falha da stack do CloudFormation
aws cloudformation describe-stack-events --stack-name eksctl-togglemaster-nodegroup-ng-apps --query "StackEvents[?contains(ResourceStatus,'FAILED')].[LogicalResourceId,ResourceStatusReason]" --output table
# 8) Pré-requisitos da conta: roles vinculadas e cota de vCPU On-Demand (m7i-flex.large x2 = 4 vCPU)
aws iam get-role --role-name AWSServiceRoleForAmazonEKSNodegroup --query "Role.Arn" --output text
aws iam get-role --role-name AWSServiceRoleForAutoScaling --query "Role.Arn" --output text
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --query "Quota.Value"
```

**Como ler (árvore de decisão):**
| O que o kit mostrou | Onde parou | Próximo passo |
|---|---|---|
| `kubectl get nodes` com nós `Ready` | nada travou — só lento | aguardar `ACTIVE` e seguir |
| `asg: null` + sem EC2 + erro no CloudTrail (5) | o EKS **não conseguiu criar o ASG** | ver **T1** |
| ASG existe, sem EC2, `Failed` nas atividades (6) | o ASG **não conseguiu lançar a EC2** | ver **T4** |
| EC2 `running`, mas nenhum nó no `kubectl` | a EC2 **não alcança o cluster** (NAT/rotas/SG) | conferir NAT e rotas das subnets privadas |
| nós aparecem `NotReady` | rede dos pods (vpc-cni) | `kubectl get pods -n kube-system` |

---

### T1 — Node group preso em `CREATING` → `exceeded max wait time` ✅ resolvido
- **Sintoma:** o control plane e os addons sobem, mas o eksctl fica ~25 min em `waiting for CloudFormation stack "eksctl-togglemaster-nodegroup-ng-apps"` e termina com:
  ```
  [✖]  exceeded max wait time for StackCreateComplete waiter
  Error: failed to create cluster "togglemaster"
  ```
- **Diagnóstico (o que o kit mostrou):**
  - (1) `status: CREATING`, `issues: []` → não falhou, ficou parado.
  - (3) nenhuma EC2 · (4) `No resources found` · e o nome do ASG veio `None` → o **ASG nem foi criado**: o problema é **antes** de lançar máquina, então não é rede/NAT.
  - (8) role do EKS nodegroup **existe** · cota de vCPU **16** (sobra) → descartados.
  - (5) CloudTrail revelou a causa:
    ```
    "errorCode":"ServiceLinkedRoleFailure","errorMessage":"The Service-Linked Role for this Auto Scaling group is not yet ready for use."
    ```
- **Causa:** em conta nova a *service-linked role* `AWSServiceRoleForAutoScaling` é criada na hora do primeiro ASG, mas leva um tempo até ficar utilizável. O EKS tentou criar o ASG antes disso.
- **Correção:** garantir a role, esperar propagar e recriar **só o node group** (o cluster fica):
  ```bash
  aws iam get-role --role-name AWSServiceRoleForAutoScaling --query "Role.Arn" --output text || { aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com && sleep 120; }
  eksctl create nodegroup -f infra/eksctl-cluster.yaml
  ```
- **Prevenção:** já entrou como **pré-requisito do 3.2** (rodar antes do `eksctl create cluster`).

### T2 — `AlreadyExistsException` ao rodar `create cluster` de novo ✅ resolvido
- **Sintoma:**
  ```
  AlreadyExistsException: Stack [eksctl-togglemaster-cluster] already exists
  ```
- **Causa:** o **cluster já tinha sido criado** na primeira tentativa (só o node group falhou). O `create cluster` tenta recriar tudo e para sem alterar nada — não causa dano.
- **Correção:** **não** rodar `create cluster` de novo. Quando só o node group falhou, use `eksctl create nodegroup -f infra/eksctl-cluster.yaml`.

### T3 — `ResourceNotFoundException` ao apagar o node group ✅ resolvido
- **Sintoma:** `describe-nodegroup` e `eksctl delete nodegroup` respondem:
  ```
  ResourceNotFoundException: The requested resource does not exist.
  ```
- **Causa:** depois da falha, a AWS **removeu o node group sozinha**. Não há o que apagar no EKS.
- **Correção:** conferir se ficou **stack órfã** no CloudFormation (senão o `create nodegroup` dá `AlreadyExists`) e apagá-la antes de recriar:
  ```bash
  aws cloudformation describe-stacks --stack-name eksctl-togglemaster-nodegroup-ng-apps --query "Stacks[0].StackStatus" --output text
  # se NÃO vier "does not exist" (ex.: ROLLBACK_COMPLETE, CREATE_FAILED):
  aws cloudformation delete-stack --stack-name eksctl-togglemaster-nodegroup-ng-apps && aws cloudformation wait stack-delete-complete --stack-name eksctl-togglemaster-nodegroup-ng-apps
  eksctl create nodegroup -f infra/eksctl-cluster.yaml
  ```
- **Regra:** o `delete nodegroup` **não funciona** enquanto o status é `CREATING` — espere virar `CREATE_FAILED` (ou sumir).

### T4 — ASG criado, mas nenhuma EC2 sobe ✅ causa encontrada (conta no plano Free)
- **Sintoma:** na 2ª tentativa, o CloudTrail (5) mostra `CreateAutoScalingGroup`, `EnableMetricsCollection` e `PutNotificationConfiguration` **sem erro** — ou seja, o T1 foi resolvido —, mas após ~23 min continua sem EC2 e sem nós.
- **Diagnóstico:** erros de **lançamento** de EC2 não aparecem no CloudTrail; ficam nas **atividades do ASG** → comando (6) do kit.
- **Causas prováveis pela mensagem de `Failed`:**
  | Mensagem | Causa | Correção |
  |---|---|---|
  | `Your account is currently being verified` / `PendingVerification` | conta nova ainda em ativação | aguardar a AWS liberar (pode levar horas) ou abrir caso no Support; enquanto isso **apagar o cluster** para não pagar |
  | `VcpuLimitExceeded` | cota de vCPU insuficiente | pedir aumento em Service Quotas (`L-1216C47A`) |
  | `Unsupported` / `InsufficientInstanceCapacity` | `t3.medium` indisponível na AZ | trocar o tipo (ex.: `t3a.medium`) ou as AZs no YAML |
  | erro de launch template / AMI | configuração do node group | recriar o node group |
- **Resultado (causa real):** o comando 6 mostrou
  ```
  Could not launch On-Demand Instances. InvalidParameterCombination - The specified instance type is not eligible for Free Tier.
  ```
  A conta está no **plano gratuito (Free plan)** da AWS: ela só deixa lançar EC2 de tipos *free-tier-eligible*, e o `t3.medium` não é um deles. O nodegroup espera para sempre por máquinas que o ASG nunca consegue criar.
- **Correção (escolha uma):**
  - **A — adotada neste projeto (continuar no Free Tier):** trocar o `instanceType` no `infra/eksctl-cluster.yaml` por um tipo elegível. Para listar os tipos: `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query "InstanceTypes[].InstanceType" --output text`. Prefira um com 2 vCPU e pelo menos 4 GB, como `m7i-flex.large` ou `c7i-flex.large`. Os `micro` e `small` têm pouca memória para 5 serviços + KEDA + Ingress. → **Usamos `m7i-flex.large`.**
  - **B — se aparecer outro bloqueio do plano Free:** mudar a conta para o **plano pago** (Console → **Billing and Cost Management → Upgrade plan**). Os créditos continuam valendo; o cartão só é cobrado depois que acabarem.
  - Depois de qualquer uma: `eksctl delete nodegroup --cluster togglemaster --name ng-apps --wait` e `eksctl create nodegroup -f infra/eksctl-cluster.yaml`.
- **Prevenção:** antes do 3.2, confirme que a conta está no plano pago, ou que o `instanceType` aparece na lista de tipos elegíveis.

### T5 — Avisos do eksctl que **não** são erro (podem ser ignorados)
- `recommended policies were found for "vpc-cni" addon, but since OIDC is disabled...` → aparece porque os addons são criados **antes** de associar o OIDC; logo depois o log mostra `deploying stack "eksctl-togglemaster-addon-vpc-cni"` e `addon "vpc-cni" active` (o IRSA do CNI foi configurado).
- `Auto Mode will be enabled by default in an upcoming release of eksctl` → no futuro o eksctl deixará de criar node groups gerenciados por padrão. Para garantir o comportamento atual, dá para acrescentar `autoModeConfig: { enabled: false }` no `infra/eksctl-cluster.yaml`.
- `default addons metrics-server were not specified, will install them as EKS addons` → o eksctl 0.231 **já instala o metrics-server**. No **4.1**, rode `kubectl -n kube-system get deploy metrics-server`: se existir, pule o `kubectl apply` e vá direto ao `kubectl top nodes`.

### T7 — `DBInstanceNotFound` no 3.4 ✅ resolvido
- **Sintoma:**
  ```
  Waiter DBInstanceAvailable failed: An error occurred (DBInstanceNotFound): DBInstance togglemaster-auth-db not found.
  ```
  (o mesmo para `flag-db` e `targeting-db`).
- **Causa:** foi rodado só o `aws rds wait db-instance-available`, que **apenas espera** os bancos ficarem prontos. Os bancos nunca tinham sido criados (o 3.4 estava resumido e os comandos de criação ficavam no `PASSO_A_PASSO.md`).
- **Correção:** rodar os passos 1–3 do **3.4** (senha → rede → `create-db-instance`) e só então o `wait`. O mesmo vale para o `elasticache wait` do 3.5.

### T8 — `ScanNotFoundException` no scan do ECR (bônus do 3.3)
- **Sintoma:** `describe-image-scan-findings` responde `Image scan does not exist for the image with '{imageDigest:'null', imageTag:'v1'}'`.
- **Diagnóstico:**
  ```bash
  aws ecr describe-images --repository-name evaluation-service --query 'imageDetails[].[join(`,`,imageTags||[`-`]),imageManifestMediaType,imageScanStatus.status]' --output table
  ```
- **Correção:** se o tipo for `...image.manifest...`/`...v2+json` (repositório criado sem `scanOnPush`), disparar à mão: `aws ecr start-image-scan --repository-name evaluation-service --image-id imageTag=$IMAGE_TAG`. Se for `...image.index...`/`manifest.list` (Docker publicou índice multi-arquitetura), refazer o build com `--provenance=false` e o push. O scan é **bônus** — dá para pular.

### T9 — `InstanceQuotaExceeded` no 3º RDS (limite do plano Free) ✅ resolvido
- **Sintoma:** `auth-db` e `flag-db` são criados; o `targeting-db` falha com
  ```
  InstanceQuotaExceeded: You reached the maximum number of instances available with free plan accounts. To remove all limitations, upgrade your account plan.
  ```
- **Causa:** o plano Free limita a quantidade de instâncias RDS, e o enunciado exige **3 RDS independentes** (*database per service*).
- **Correção:** fazer o upgrade para o **plano pago** (veja o **Pré-requisito da Parte 2**). Depois, criar só o banco que faltou. Se o terminal tiver sido fechado, recupere antes `DB_*` e `RDS_SG`:
  ```bash
  source infra/cloud.env; RDS_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=togglemaster-rds-sg --query 'SecurityGroups[0].GroupId' --output text)
  aws rds create-db-instance --db-instance-identifier togglemaster-targeting-db --engine postgres --db-instance-class db.t3.micro --allocated-storage 20 --storage-type gp3 --master-username "$DB_USER" --master-user-password "$DB_PASSWORD" --db-name targeting_db --db-subnet-group-name togglemaster-db-subnets --vpc-security-group-ids $RDS_SG --no-publicly-accessible --no-multi-az --backup-retention-period 0 --storage-encrypted --tags Key=project,Value=togglemaster >/dev/null && echo "OK: plano pago ativo"
  ```
  - `OK: plano pago ativo` → upgrade validado, banco sendo criado.
  - `InstanceQuotaExceeded` de novo → o upgrade ainda não propagou; espere alguns minutos e repita.
- **Aguardar e conferir os 3:**
  ```bash
  for n in auth flag targeting; do aws rds wait db-instance-available --db-instance-identifier togglemaster-$n-db; done
  aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' --output table
  ```
- **Prevenção:** fazer o upgrade **antes do 3.2**, o que também evita o T4.

### T10 — `namespaces "togglemaster-evaluation" not found` no 4.2 ✅ resolvido
- **Sintoma:** o `kubectl get sa -n togglemaster-evaluation evaluation-service-sa ...` responde `Error from server (NotFound): namespaces "togglemaster-evaluation" not found`.
- **Causa:** foi rodado só o **Validar**. O 4.2 estava resumido ("ver PASSO_A_PASSO"), então os namespaces, as políticas IAM e as service accounts nunca tinham sido criados.
- **Correção:** rodar o **Criar** do 4.2 (`kubectl apply -f k8s/00-namespaces.yaml` → `create-policy` → `eksctl create iamserviceaccount`). Na validação, o esperado é aparecer a anotação `eks.amazonaws.com/role-arn`.

### T11 — `namespaces "ingress-nginx" not found` no 4.3 ✅ resolvido
- **Sintoma:** `kubectl -n ingress-nginx get svc ingress-nginx-controller` responde `Error from server (NotFound): namespaces "ingress-nginx" not found`.
- **Causa:** a mesma do T7 e do T10: foi rodado só o **Validar**. O 4.3 (e o 4.4) estavam resumidos ("ver PASSO_A_PASSO"), e o Ingress nunca tinha sido instalado.
- **Correção:** rodar o **Criar** do 4.3 (LB Controller → NGINX Ingress) e só depois o **Validar**. O 4.4 (KEDA) também ganhou os comandos completos.
- **Lição geral:** se um comando de validação disser `not found`, confira primeiro se o **Criar** daquele passo foi executado.

### T12 — `CreateContainerConfigError` nos pods (5.2) ✅ resolvido
- **Sintoma:** depois do `06-deploy-k8s.sh`, só o auth fica `Running`. Flag, targeting, evaluation e analytics ficam em `CreateContainerConfigError`, e o `kubectl get secret -A | grep togglemaster` mostra só o secret do auth.
- **Diagnóstico:**
  ```bash
  kubectl -n togglemaster-evaluation describe pod -l app=evaluation-service | tail -5
  ls -1 k8s/generated/
  ```
  → `Error: secret "evaluation-service-secret" not found`, e na pasta só existia o `auth-secret.yaml`.
- **Causa:** no **5.1** foi rodado o **exemplo manual** do bloco "Sem o script", que gera **apenas o secret do auth**, em vez do `scripts/05-gerar-secrets.sh`, que gera os **5**. Sem secret, o pod não consegue montar as variáveis e nem inicia. Os Jobs que criam as tabelas do flag e do targeting também ficaram presos.
- **Correção:** gerar os 5 secrets, refazer o deploy (é idempotente e destrava os Jobs) e recriar os pods:
  ```bash
  cd /home/wmoya/ToggleMaster-Fase2 && source infra/cloud.env
  scripts/05-gerar-secrets.sh && ls -1 k8s/generated/          # 5 arquivos
  scripts/06-deploy-k8s.sh
  for ns in auth flag targeting evaluation analytics; do kubectl rollout restart deploy -n togglemaster-$ns; done
  kubectl get pods -A -l app.kubernetes.io/part-of=togglemaster -w
  ```
- **Prevenção:** no 5.1, use sempre o **script**, porque o bloco "Sem o script" é só um exemplo de **um** serviço. Antes do 5.2, confira se há **5 arquivos** em `k8s/generated/`.

### T6 — Pegadinhas de terminal
- **Comando quebrado de linha ao colar:** um `--query "...'FAILED` + Enter + `')]..."` vira outra string e o resultado volta **vazio sem erro** — parece "nada falhou", mas a busca nem rodou. Cole cada comando **numa linha só**.
- **Terminal sem AWS CLI/credencial:** rode o diagnóstico no **mesmo terminal/usuário** onde o `eksctl` foi executado (aqui: WSL Ubuntu como `root`). Em outro shell dá `aws: command not found` ou `NoCredentials`.
- **🔐 Nº da conta na tela:** `update-kubeconfig`, `get-role` e ARNs em geral imprimem o account ID — na gravação use `> /dev/null` ou `--query` que não retorne ARN.
