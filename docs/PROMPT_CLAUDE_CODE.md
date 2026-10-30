# Prompts para executar a Fase 2 com o Claude Code

## Como usar

1. No **terminal do Ubuntu (WSL2)**, depois da Etapa 0.0 do passo a passo:
   ```bash
   cd ~/ToggleMaster-Fase2
   claude
   ```
   (Se ainda não tiver o Claude Code no WSL: `curl -fsSL https://claude.ai/install.sh | bash`, ou siga a instalação oficial em docs.claude.com.)
2. O Claude Code lê sozinho o **`CLAUDE.md`** da raiz (regras de segurança, custo e forma de trabalhar).
3. Cole o **Prompt inicial** abaixo. Depois, a cada etapa, use os prompts curtos da seção seguinte (ou só responda "pode seguir").

---

## Prompt inicial (colar uma vez)

```text
Vamos executar o Tech Challenge Fase 2 do ToggleMaster (FIAP POSTECH DCLT) neste projeto.

Contexto:
- Siga as regras do CLAUDE.md e o roteiro docs/PASSO_A_PASSO.md, etapa por etapa, na ordem.
- Conta AWS pessoal (Opção B), região us-east-1. Estou no Ubuntu do WSL2 com Docker Desktop.
- Objetivo: deixar o ambiente pronto para gravar o vídeo (até 20 min) atendendo 100% do enunciado,
  usando a matriz de aderência de 27 itens do PASSO_A_PASSO.md como checklist.
- Eu sou pentester, não desenvolvedor: explique cada passo em português, em tabelas, no nível
  "o que vai rodar, por que, e o que o resultado significa".

Antes de qualquer etapa, faça o PRÉ-VOO (somente leitura, nada pago):
1. Leia CLAUDE.md, docs/PASSO_A_PASSO.md, docs/ROTEIRO_VIDEO.md e o PDF do enunciado se estiver em ../
2. Confira versões: docker, docker compose, aws, kubectl, eksctl, helm, git, jq, hey ou ab, openssl.
   Para o que faltar, mostre o comando de instalação da Etapa 0.1 e pergunte se pode instalar.
3. Rode `aws sts get-caller-identity` e confirme que NÃO é a conta root.
4. Confira se os scripts estão executáveis e sem CRLF (scripts/*.sh, local/*/*.sh); corrija se precisar.
5. Confira se .gitignore cobre .env, infra/cloud.env, k8s/generated/, reports/, *.pem.
6. Crie docs/EXECUCAO_LOG.md com o cabeçalho e o resultado do pré-voo.
7. Mostre a matriz de aderência (27 itens) com o status atual e o plano das etapas com tempo e custo.

Depois do pré-voo, PARE e espere eu dizer "pode seguir".
Regras inegociáveis: nunca mostrar segredos; pedir confirmação antes de criar recurso pago,
mexer em IAM ou apagar qualquer coisa; uma etapa por vez; registrar tudo no EXECUCAO_LOG.md.
```

---

## Prompts por etapa (opcionais: "pode seguir" também funciona)

### Etapa 1 — Docker local
```text
Execute a Etapa 1 do PASSO_A_PASSO.md.
- 1.2: crie a fila SQS togglemaster-events (peça confirmação) e grave a URL no .env.
- 1.3: gere PG_PASSWORD, MASTER_KEY e SERVICE_API_KEY com openssl direto no .env, sem exibir os valores.
- 1.4: exporte as credenciais AWS só na sessão e rode docker compose up -d --build.
  Se algum container falhar, leia os logs, explique a causa e proponha a correção mínima.
- 1.5 e 1.6: crie a tabela no DynamoDB Local e rode scripts/teste-fluxo.sh local.
- 1.7: rode scripts/devsecops-scan.sh e resuma os achados HIGH/CRITICAL em tabela.
No final: confirme os 9 containers saudáveis, atualize a matriz (itens 1, 2 e 9) e o log, e pare.
Deixe pronto para eu gravar o bloco 3 do ROTEIRO_VIDEO.md (comandos que eu mesmo vou digitar).
```

### Publicar o repositório
```text
Prepare o repositório git para publicar no GitHub: git init, revise o que vai entrar no commit
(liste os arquivos), rode o Gitleaks e só então faça o commit. Me diga os comandos para eu criar
o repositório no GitHub e fazer o push. Não faça push sem eu confirmar.
```

### Etapa 2 — Infraestrutura AWS (início da cobrança)
```text
Execute a Etapa 2. Anote o horário de início (começa a cobrança).
Ordem: 2.1 cloud.env (gere senhas sem exibir) -> 2.2 eksctl create cluster (peça confirmação;
enquanto roda, faça a 2.3 ECR em paralelo) -> 2.4 SGs e subnet groups -> 2.5 três RDS ->
2.6 ElastiCache -> 2.7 DynamoDB. Grave endpoints no infra/cloud.env sem mostrar senhas.
Ao final mostre a tabela "strings de conexão" (2.9) sem segredos, atualize a matriz (itens 3 a 10)
e o log, diga há quanto tempo o ambiente está ligado e pare.
```

### Etapa 3 — Configuração do cluster
```text
Execute a Etapa 3: kubeconfig, Metrics Server, políticas e roles IRSA (peça confirmação para IAM),
AWS Load Balancer Controller + ingress-nginx com NLB (se falhar, use o Plano B da 3.4), e KEDA com IRSA.
Valide cada componente (pods Running, EXTERNAL-IP do ingress, kubectl top nodes).
Atualize a matriz (itens 11 e 12) e o log, e pare.
```

### Etapa 4 — Manifestos e deploy
```text
Execute a Etapa 4: gerar secrets (sem exibir conteúdo), scripts/06-deploy-k8s.sh, verificar Jobs
de schema, pods, services e ingress; depois rode scripts/teste-fluxo.sh no DNS do Load Balancer.
Se algo falhar, diagnostique com logs/describe/events e use port-forward para isolar app x ingress.
Atualize a matriz (itens 13 a 18) e o log, e pare.
```

### Etapa 5 — Ensaio da escalabilidade (antes de gravar)
```text
Faça um ENSAIO rápido da Etapa 5 para garantir que vai funcionar na gravação:
- carga curta (60 s) no evaluation e confirme que o HPA sobe réplicas;
- envie 50 lotes para a SQS e confirme o KEDA escalando o analytics de 0 para N;
- confirme itens no DynamoDB.
Depois espere tudo voltar ao estado inicial (HPA em 1 réplica, analytics em 0, fila vazia;
use purge-queue se precisar). Atualize a matriz (itens 19 a 21) e o log.
Por fim, me entregue a "folha de cola" da gravação: os comandos de cada bloco do ROTEIRO_VIDEO.md
já com o DNS do LB e as variáveis preenchidas (sem segredos), na ordem em que vou digitar.
```

### Checklist pré-gravação
```text
Rode o checklist pré-gravação da Etapa 6: compose com 9 containers, pods sem CrashLoopBackOff,
curl no /auth/health pelo LB, fila vazia, analytics em 0 pods, HPA em 1 réplica.
Me lembre de limpar o histórico do terminal e fechar arquivos com segredos. Responda com uma
tabela OK / NÃO OK e o que corrigir.
```

### Etapa 7 — Destruição (fim da cobrança)
```text
Gravação concluída. Execute a Etapa 7: peça confirmação, rode scripts/99-destruir-ambiente.sh,
acompanhe até o fim e rode TODOS os comandos de conferência (EKS, RDS, ElastiCache, NAT, ELB,
Elastic IPs, roles e políticas IAM do laboratório). Liste qualquer sobra e proponha como remover.
Informe o tempo total ligado e uma estimativa de custo. Atualize o log.
```

### Fechamento (relatório + guia de bolso)
```text
Com base no docs/EXECUCAO_LOG.md:
1. Gere docs/DESAFIOS_E_DECISOES.md pronto para o relatório.
2. Atualize docs/RELATORIO_ENTREGA_FASE2.txt com o link do repositório e do vídeo que eu informar.
3. Gere docs/GUIA_DE_BOLSO_FASE2.md: passo a passo enxuto com todos os comandos completos
   (sem segredos), explicações curtas e a tabela de troubleshooting com os erros reais que tivemos.
```
