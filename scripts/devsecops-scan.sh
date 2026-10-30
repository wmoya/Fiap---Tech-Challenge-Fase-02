#!/usr/bin/env bash
# =============================================================================
# devsecops-scan.sh
# Verificações de segurança antes do push (abordagem "shift-left": segurança
# no início do ciclo). Tudo roda via container, então só exige Docker.
#   1) Hadolint  - boas práticas e falhas nos Dockerfiles
#   2) Trivy     - vulnerabilidades (CVEs) HIGH/CRITICAL nas imagens
#   3) Trivy     - erros de configuração (misconfig) nos manifestos Kubernetes
#   4) Syft      - SBOM (inventário de componentes) de cada imagem, em SPDX JSON
#   5) Gitleaks  - procura segredos (senhas/chaves) commitados por engano
# Os resultados ficam em reports/.
# Uso: scripts/devsecops-scan.sh   (depois do docker compose build)
# =============================================================================

# Obs.: aqui é 'set -uo pipefail' (sem o -e) de propósito: queremos que o scan
# continue mesmo que um serviço acuse vulnerabilidade (exit code != 0), gerando
# todos os relatórios em vez de parar no primeiro achado.
set -uo pipefail

# Vai para a raiz do projeto (caminhos "services/..." e "k8s/...").
cd "$(dirname "$0")/.."

# Cria a pasta onde os relatórios serão salvos.
mkdir -p reports

# Os 5 microsserviços a analisar.
SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

# (1) Hadolint em cada Dockerfile. O container lê o Dockerfile pela entrada padrão (< arquivo).
# 'tee' mostra na tela E grava no relatório ao mesmo tempo.
for svc in $SERVICES; do
  echo "==> Hadolint $svc"
  docker run --rm -i hadolint/hadolint < services/$svc/Dockerfile | tee reports/hadolint-$svc.txt
done

# (2) e (4) para cada imagem local (togglemaster/<svc>:local, criadas pelo docker compose build):
for svc in $SERVICES; do
  echo "==> Trivy image togglemaster/$svc:local"
  # Trivy escaneia a imagem:
  #   -v docker.sock -> deixa o Trivy enxergar as imagens do Docker do host;
  #   -v ~/.cache/trivy -> cache do banco de CVEs (acelera execuções seguintes);
  #   --severity HIGH,CRITICAL -> só o que importa priorizar;
  #   --ignore-unfixed -> ignora CVEs que ainda não têm correção disponível.
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.cache/trivy:/root/.cache/" \
    aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed "togglemaster/$svc:local" \
    | tee reports/trivy-$svc.txt
  echo "==> Syft SBOM $svc"
  # Syft gera o SBOM (lista de pacotes/licenças) da imagem no formato SPDX JSON.
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/syft:latest \
    "togglemaster/$svc:local" -o spdx-json > reports/sbom-$svc.spdx.json
done

# (3) Trivy no modo 'config': analisa os manifestos k8s em busca de más configurações
# (ex.: container rodando como root, sem limites). A pasta k8s é montada como :ro (somente leitura).
echo "==> Trivy config (manifestos k8s)"
docker run --rm -v "$PWD/k8s:/k8s:ro" aquasec/trivy:latest config /k8s | tee reports/trivy-k8s.txt

# (5) Gitleaks varre o repositório inteiro procurando segredos vazados no código/histórico.
echo "==> Gitleaks (segredos no repositório)"
docker run --rm -v "$PWD:/repo:ro" zricethezav/gitleaks:latest detect --source /repo --no-banner -v | tee reports/gitleaks.txt

echo "Relatórios em reports/"
