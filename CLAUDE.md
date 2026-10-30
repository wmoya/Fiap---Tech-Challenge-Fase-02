# CLAUDE.md — Regras do projeto ToggleMaster Fase 2 (FIAP POSTECH DCLT)

> O Claude Code lê este arquivo automaticamente ao abrir o projeto. Estas regras valem para a sessão inteira.

## Contexto
- Tech Challenge **Fase 2**: 5 microsserviços (auth e evaluation em Go; flag, targeting e analytics em Python) conteinerizados e implantados no **Amazon EKS**.
- Conta AWS **pessoal** (Opção B do enunciado), região **us-east-1**, cluster `togglemaster`.
- O roteiro oficial de execução é **`docs/PASSO_A_PASSO.md`**. Siga as etapas na ordem e use os comandos de lá; não invente caminhos alternativos sem avisar.
- O enunciado original está em `../POSTECH - Tech Challenge - Fase 2.pdf` (se existir). Em caso de conflito, **o enunciado prevalece**.
- Quem opera é um pentester, não desenvolvedor: explique cada passo no nível "o que vou rodar, por que, e o que o resultado significa", em **português do Brasil**, preferindo tabelas.

## Regras de segurança (obrigatórias)
1. **Nunca exiba segredos.** Não rode `cat`, `less`, `echo` ou `grep` que mostrem o conteúdo de `.env`, `infra/cloud.env`, `~/.aws/credentials`, `k8s/generated/*` ou `kubectl get secret -o yaml` de bancos. Para conferir se uma variável existe, use `[ -n "$VAR" ] && echo definida`.
2. Senhas e chaves são geradas com `openssl rand` e gravadas **direto no arquivo** (ex.: com `sed -i`), sem aparecer na saída.
3. Nunca faça `git add` de `.env`, `infra/cloud.env`, `k8s/generated/`, `reports/`, `*.pem`, `*.tfstate`. Antes de qualquer `git push`, rode o Gitleaks (`scripts/devsecops-scan.sh` ou só a parte do Gitleaks) e mostre o resultado.
4. SSH, quando existir, só para IP `/32`. Nada de `0.0.0.0/0` em porta administrativa.
5. Não use a conta root da AWS. Confira com `aws sts get-caller-identity` (pode mostrar o ARN do usuário IAM).

## Regras de custo e ações irreversíveis
- **Peça confirmação explícita ("posso executar?") antes de:**
  - qualquer comando que **crie recurso pago** na AWS (`eksctl create cluster`, `aws rds create-db-instance`, `aws elasticache create-replication-group`, `helm install` que cria Load Balancer, criação de NAT etc.);
  - qualquer comando que **apague** algo (`delete`, `destroy`, `uninstall`, `rm -rf`, `scripts/99-destruir-ambiente.sh`);
  - criação/alteração de **IAM** (políticas, roles, `eksctl create iamserviceaccount`).
- Ao iniciar a Etapa 2, anote o horário: a partir daí o ambiente custa ~US$ 0,45/h. A cada etapa concluída, informe há quanto tempo o ambiente está ligado.
- Ao final, **sempre** conduza a Etapa 7 (destruição) e rode os comandos de conferência até tudo voltar vazio.

## Forma de trabalhar
- **Uma etapa por vez.** Ao terminar uma etapa: mostre o resumo, atualize a matriz de aderência (itens 1–27 do `PASSO_A_PASSO.md`) e **pare** esperando o "pode seguir".
- Antes de cada comando longo (eksctl ~20 min, RDS ~10 min), diga quanto tempo deve levar e o que fazer em paralelo.
- Passos marcados com 🎥 no passo a passo são para **gravação**: prepare tudo, deixe o comando pronto e diga ao usuário para executá-lo ele mesmo no terminal que será gravado (não execute por ele, a menos que ele peça).
- Em erro: leia logs (`docker compose logs`, `kubectl logs`, `kubectl describe`, `kubectl get events -n <ns> --sort-by=.lastTimestamp`), consulte a tabela "Solução de problemas" do passo a passo, proponha a correção mínima e explique antes de aplicar.
- Mudanças de código nos microsserviços: **somente as mínimas necessárias**, sempre registradas no log.

## Registro (vira insumo do relatório e do Guia de Bolso)
- Mantenha **`docs/EXECUCAO_LOG.md`** atualizado a cada etapa, com: data/hora, etapa, comandos executados (sem segredos), resultado, problemas encontrados, causa, solução e decisões tomadas.
- Ao final, gere em `docs/` um resumo "Desafios e decisões" pronto para colar no `RELATORIO_ENTREGA_FASE2.txt`.

## Mapa do projeto
| Pasta/arquivo | Conteúdo |
|---|---|
| `services/` | código dos 5 serviços + Dockerfile multi-stage |
| `docker-compose.yml`, `local/` | ambiente local (9 containers) |
| `infra/` | `eksctl-cluster.yaml`, políticas IAM, `cloud.env.example` |
| `k8s/` | manifestos por serviço, HPA, KEDA, Jobs de schema |
| `scripts/` | build/push ECR, secrets, deploy, testes, carga, SQS, DevSecOps, destruição |
| `docs/` | `PASSO_A_PASSO.md`, `ROTEIRO_VIDEO.md`, relatório, log de execução |
