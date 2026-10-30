#!/bin/bash
# Cadastra a chave de serviço usada pelo evaluation-service (SERVICE_API_KEY).
# O auth-service guarda apenas o SHA-256 da chave, igual ao que o endpoint /admin/keys faz.
# (sem "exit": o entrypoint do postgres pode executar este arquivo com "source")
if [ -n "${SERVICE_API_KEY:-}" ]; then
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v key="$SERVICE_API_KEY" <<'SQL'
INSERT INTO api_keys (name, key_hash)
VALUES ('evaluation-service', encode(sha256(convert_to(:'key', 'UTF8')), 'hex'))
ON CONFLICT (key_hash) DO NOTHING;
SQL
  echo "Chave de serviço do evaluation-service cadastrada."
else
  echo "SERVICE_API_KEY não definida: nenhuma chave de serviço cadastrada."
fi
