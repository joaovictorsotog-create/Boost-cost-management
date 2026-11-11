#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="/usr/lib/postgresql/16/bin:$PATH"
TEMP_ROOT=$(mktemp -d /tmp/alianza-costing-identity-XXXXXX)
SOCKET="$TEMP_ROOT/socket"
PORT="${COSTING_IDENTITY_PG_PORT:-55448}"
OLD_0039="$TEMP_ROOT/0039-before.sql"

git -C "$ROOT_DIR" show d9ff4dd7024674c54af128e4bdc816a0b459e22a:drizzle/pg/0039_costing_rls_security.sql > "$OLD_0039"
initdb -D "$TEMP_ROOT/data" -A trust --no-locale >/dev/null
printf "listen_addresses = '127.0.0.1'\nport = %s\nunix_socket_directories = '%s'\n" "$PORT" "$SOCKET" >> "$TEMP_ROOT/data/postgresql.conf"
mkdir -p "$SOCKET"
pg_ctl -D "$TEMP_ROOT/data" -o "-k $SOCKET" -w start >/dev/null
cleanup() {
  pg_ctl -D "$TEMP_ROOT/data" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

psql() { command psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 "$@"; }
psql <<'SQL'
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE app_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
SQL
for migration in 0000_eminent_mathemanic 0001_pink_pete_wisdom 0036_costing_foundation 0037_costing_correction_integrity 0038_costing_final_stabilization; do
  psql -f "$ROOT_DIR/drizzle/pg/$migration.sql" >/dev/null
done
psql -f "$OLD_0039" >/dev/null
psql <<'SQL'
INSERT INTO public.organizations ("id","name","slug","createdAt","updatedAt") VALUES
  ('org-identity-a','Identity A','identity-a',1,1),
  ('org-identity-b','Identity B','identity-b',1,1);
INSERT INTO public.users ("id","openId","name","supabaseAuthId") VALUES
  (301,'identity-user-a','Identity A','31111111-1111-1111-1111-111111111111'),
  (302,'identity-user-b','Identity B','32222222-2222-2222-2222-222222222222');
INSERT INTO public.organization_members ("id","organizationId","userId","role","status","createdAt","updatedAt") VALUES
  ('identity-membership-a','org-identity-a',301,'admin','active',1,1),
  ('identity-membership-b','org-identity-b',302,'admin','active',1,1);
INSERT INTO public.cost_groups ("id","organizationId","name","createdAt","updatedAt") VALUES
  ('identity-group-a','org-identity-a','A','now','now'),
  ('identity-group-b','org-identity-b','B','now','now');
INSERT INTO public.cost_items ("id","organizationId","groupId","name","itemType","referenceUnit","manualUnitCost","createdAt","updatedAt") VALUES
  ('identity-item-a','org-identity-a','identity-group-a','A','SIMPLE','kg','10','now','now'),
  ('identity-item-b','org-identity-b','identity-group-b','B','SIMPLE','kg','20','now','now');
SQL

printf '%s\n' '=== before correction: authenticated forges request.app_user_id=B ==='
before=$(psql -Atqc "SET ROLE authenticated; SELECT set_config('request.app_user_id','302',false); SELECT count(*) FROM public.cost_items WHERE \"organizationId\" = 'org-identity-b'; RESET ROLE;" | tail -1)
printf 'before_visible_org_b=%s\n' "$before"
[ "$before" = 1 ]

psql -f "$ROOT_DIR/drizzle/pg/0039_costing_rls_security.sql" >/dev/null
printf '%s\n' '=== after correction: JWT=A, request.app_user_id=B ==='
after=$(psql -Atqc "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','31111111-1111-1111-1111-111111111111',false); SELECT set_config('request.app_user_id','302',false); SELECT count(*) FROM public.cost_items WHERE \"organizationId\" = 'org-identity-a'; SELECT count(*) FROM public.cost_items WHERE \"organizationId\" = 'org-identity-b'; RESET ROLE;" | tail -2)
printf 'after_visible_counts_A_then_B=%s\n' "$after"
expected=$'1\n0'
[ "$after" = "$expected" ]
printf '%s\n' 'IDENTITY_BOUNDARY_TEST=PASS'
