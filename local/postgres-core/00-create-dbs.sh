#!/bin/bash
# Uma instância PostgreSQL local com dois bancos: flags_db (flag-service) e targeting_db (targeting-service).
# Na AWS cada um vira um RDS independente.
for db in flags_db targeting_db; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $db;"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" -f "/docker-entrypoint-initdb.d/sql/${db}.sql"
done
