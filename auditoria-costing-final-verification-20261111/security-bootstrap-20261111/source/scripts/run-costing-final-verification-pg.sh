#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="/usr/lib/postgresql/16/bin:$PATH"
TEMP_ROOT=$(mktemp -d /tmp/alianza-costing-final-verification-pg-XXXXXX)
SOCKET="$TEMP_ROOT/socket"
PORT="${COSTING_VERIFICATION_PG_PORT:-55446}"
initdb -D "$TEMP_ROOT/data" -A trust --no-locale >/dev/null
printf "listen_addresses = '127.0.0.1'\nport = %s\nunix_socket_directories = '%s'\n" "$PORT" "$SOCKET" >> "$TEMP_ROOT/data/postgresql.conf"
mkdir -p "$SOCKET"
pg_ctl -D "$TEMP_ROOT/data" -o "-k $SOCKET" -w start >/dev/null
cleanup() {
  pg_ctl -D "$TEMP_ROOT/data" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT
DATABASE_URL="postgres://$(whoami)@127.0.0.1:$PORT/postgres"
export SUPABASE_DATABASE_URL="$DATABASE_URL"

psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE app_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
SQL

printf '%s\n' '=== drizzle runner: first execution ==='
pnpm --dir "$ROOT_DIR" exec drizzle-kit migrate --config "$ROOT_DIR/drizzle.pg.config.ts"
printf '%s\n' '=== drizzle runner: second execution ==='
pnpm --dir "$ROOT_DIR" exec drizzle-kit migrate --config "$ROOT_DIR/drizzle.pg.config.ts"
printf '%s\n' '=== migration journal rows ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -Atc 'select hash from drizzle.__drizzle_migrations order by created_at'
printf '%s\n' '=== Costing tables ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -Atc "select tablename from pg_tables where schemaname='public' and tablename like 'cost_%' order by tablename"
printf '%s\n' '=== CRUD edit service harness ==='
pnpm --dir "$ROOT_DIR" exec tsx "$ROOT_DIR/scripts/costing-crud-edit-pg.ts"
printf '%s\n' '=== independent mutation/publication harness ==='
pnpm --dir "$ROOT_DIR" exec tsx "$ROOT_DIR/scripts/costing-final-verification-pg.ts"
