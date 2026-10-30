# Roteiro do vídeo — Tech Challenge Fase 2 (máx. 20 min)

> Grave com tudo **já provisionado** (etapas 0 a 4 do passo a passo). No vídeo você **mostra e explica**, sem esperar o eksctl.
> Deixe 4 terminais abertos: (1) comandos, (2) `watch` de pods, (3) `watch` de HPA, (4) carga.
> Nunca mostre `.env`, `infra/cloud.env`, `~/.aws/credentials` ou a saída de `kubectl get secret -o yaml` dos bancos.

| # | Tempo | Bloco | O que mostrar | Item do enunciado |
|---|---|---|---|---|
| 1 | 0:00–1:30 | Abertura e arquitetura | Diagrama do README: 5 serviços, Ingress, data stores; por que a Opção B (conta pessoal) | "Breve explicação da arquitetura" |
| 2 | 1:30–2:30 | Correções no código | Tabela da seção 0.4 (go.mod inválido, imports, Werkzeug) | "Desafios encontrados" |
| 3 | 2:30–5:00 | Docker local | Um Dockerfile multi-stage; `docker compose up -d`; `docker compose ps` (**9 containers**); `scripts/teste-fluxo.sh local` | docker compose com 9 containers |
| 4 | 5:00–7:00 | Infra AWS | Console: EKS (node group 1/2/4), ECR (5 repos + scan), 3 RDS privados, ElastiCache, DynamoDB, SQS | Cluster provisionado |
| 5 | 7:00–9:30 | Kubernetes | `kubectl get ns`; um `deployment.yaml` (requests/limits, probes, securityContext); `kubectl get pods -A` (**5 microsserviços**); secret em base64 | Pods rodando |
| 6 | 9:30–11:00 | Ingress | `kubectl get ingress -A`; `curl http://$LB/auth/health`; `scripts/teste-fluxo.sh $LB` | Nginx Ingress funcionando |
| 7 | 11:00–14:00 | HPA evaluation | 3 terminais: `get hpa -w`, `get pods -w`, `carga-evaluation.sh`; TARGETS > 70% e réplicas subindo | HPA aumentando réplicas |
| 8 | 14:00–16:30 | KEDA analytics | `sqs-enviar-mensagens.sh 200`; pods do analytics de 0 → N; fila esvaziando | Mensagens na SQS + scaling |
| 9 | 16:30–17:30 | DynamoDB | Console → Explore table items; `scan --select COUNT` | Dados no DynamoDB |
| 10 | 17:30–19:30 | Explicações | 3 data stores; por que KEDA e não HPA por CPU; IRSA em vez de LabRole/Access Keys | Justificativas |
| 11 | 19:30–20:00 | Encerramento | Próximos passos (CI/CD, GitOps) | — |

---

## Falas sugeridas

### Bloco 1 — Arquitetura
"O MVP monolítico da Fase 1 foi dividido em cinco microsserviços. O cliente chama só o `/evaluate`, que é o hot path em Go com cache Redis. Flag e targeting guardam a configuração no PostgreSQL. O auth valida as API keys. Cada avaliação vira um evento na SQS, consumido pelo analytics, que grava no DynamoDB. Tudo roda no EKS, atrás de um NGINX Ingress exposto por um Network Load Balancer. Usamos uma conta AWS pessoal, a Opção B. Por isso não dependemos da LabRole: cada serviço tem a sua própria role IAM via IRSA, com o mínimo de permissões."

### Bloco 2 — Desafios
"O código recebido não compilava: o go.mod do auth declarava um módulo inexistente, havia imports não usados e um `os` faltando no evaluation, e o Flask 2.2 quebrava com o Werkzeug 3. Corrigimos só o necessário e atualizamos as dependências que tinham CVEs conhecidas."

### Bloco 10 — Os 3 data stores
| Store | Modelo | Por que neste serviço |
|---|---|---|
| **RDS PostgreSQL** (×3) | relacional, transações ACID, schema fixo | API keys, definições de flag e regras: dados críticos, consistentes, com unicidade (`UNIQUE name`). **Um banco por serviço** (database per service): cada microsserviço é dono dos seus dados e evolui o schema sem afetar os outros |
| **ElastiCache Redis** | chave-valor em memória, TTL | hot path do evaluation: leitura em sub-milissegundo e TTL de 30 s; evita chamar flag e targeting a cada requisição |
| **DynamoDB** | NoSQL serverless, escrita massiva | eventos de analytics: alto volume de escrita, sem joins, escala sem gerenciar servidor, cobrança por uso |

### Bloco 10 — Por que KEDA no analytics
"O analytics não recebe HTTP: ele consome a fila. A CPU só sobe depois que a fila já encheu, então o HPA por CPU reage atrasado. O KEDA olha direto a profundidade da fila: com 5 mensagens por pod ele escala de 0 até 5 e volta a 0 quando a fila esvazia, sem gastar recurso parado. Como estamos numa conta pessoal, o KEDA pôde ter a própria role IRSA com permissão apenas de `GetQueueAttributes`. No AWS Academy isso não seria possível, e o caminho seria HPA por CPU, que deixamos pronto em `k8s/alternativas`."

### Bloco 10 — Segurança (DevSecOps)
"Nenhuma Access Key dentro do cluster: IRSA. Imagens distroless e não-root, `readOnlyRootFilesystem`, Pod Security `restricted`, scan no ECR, Trivy e Hadolint antes do push, SBOM com Syft. Secrets em base64 lembrando que isso não é criptografia: em produção entraria um cofre."
