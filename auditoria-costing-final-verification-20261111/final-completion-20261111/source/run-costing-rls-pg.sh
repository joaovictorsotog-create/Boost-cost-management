#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="/usr/lib/postgresql/16/bin:$PATH"
TEMP_ROOT=$(mktemp -d /tmp/alianza-costing-rls-pg-XXXXXX)
SOCKET="$TEMP_ROOT/socket"
PORT="${COSTING_RLS_PG_PORT:-55447}"

initdb -D "$TEMP_ROOT/data" -A trust --no-locale >/dev/null
printf "listen_addresses = '127.0.0.1'\nport = %s\nunix_socket_directories = '%s'\n" "$PORT" "$SOCKET" >> "$TEMP_ROOT/data/postgresql.conf"
mkdir -p "$SOCKET"
pg_ctl -D "$TEMP_ROOT/data" -o "-k $SOCKET" -w start >/dev/null
cleanup() {
  pg_ctl -D "$TEMP_ROOT/data" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE app_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
SQL

export SUPABASE_DATABASE_URL="postgres://$(whoami)@127.0.0.1:$PORT/postgres"
pnpm --dir "$ROOT_DIR" exec drizzle-kit migrate --config "$ROOT_DIR/drizzle.pg.config.ts"
pnpm --dir "$ROOT_DIR" exec drizzle-kit migrate --config "$ROOT_DIR/drizzle.pg.config.ts"

psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.organizations ("id","name","slug","createdAt","updatedAt") VALUES
  ('org-rls-a','RLS A','rls-a',extract(epoch from now())::bigint,extract(epoch from now())::bigint),
  ('org-rls-b','RLS B','rls-b',extract(epoch from now())::bigint,extract(epoch from now())::bigint);
INSERT INTO public.users ("id","openId","name","supabaseAuthId") VALUES
  (101,'rls-user-a','RLS User A','11111111-1111-1111-1111-111111111111'),
  (202,'rls-user-b','RLS User B','22222222-2222-2222-2222-222222222222');
INSERT INTO public.organization_members ("id","organizationId","userId","role","status","createdAt","updatedAt") VALUES
  ('membership-a','org-rls-a',101,'admin','active',extract(epoch from now())::bigint,extract(epoch from now())::bigint),
  ('membership-b','org-rls-b',202,'admin','active',extract(epoch from now())::bigint,extract(epoch from now())::bigint);
INSERT INTO public.cost_groups ("id","organizationId","name","createdAt","updatedAt") VALUES
  ('group-rls-a','org-rls-a','Group A','now','now'),
  ('group-rls-b','org-rls-b','Group B','now','now');
INSERT INTO public.cost_items ("id","organizationId","groupId","name","itemType","referenceUnit","manualUnitCost","createdAt","updatedAt") VALUES
  ('item-rls-a','org-rls-a','group-rls-a','Item A','SIMPLE','kg','10','now','now'),
  ('item-rls-b','org-rls-b','group-rls-b','Item B','SIMPLE','kg','20','now','now');
INSERT INTO public.cost_structures ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt") VALUES
  ('structure-rls-a','org-rls-a','item-rls-a',1,'ACTIVE','1','now','now'),
  ('structure-rls-b','org-rls-b','item-rls-b',1,'ACTIVE','1','now','now');
SQL

printf '%s\n' '=== physical RLS flags ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 -c "
SELECT count(*) AS protected_tables
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relname IN ('cost_groups','cost_items','cost_structure_version_counters','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups')
  AND relrowsecurity AND relforcerowsecurity;
" | tee /tmp/costing-rls-flags.txt

printf '%s\n' '=== app_runtime tenant A ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
SET ROLE app_runtime;
SELECT set_config('request.app_user_id','101',false);
DO $$
DECLARE visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count FROM public.cost_items;
  IF visible_count <> 1 THEN RAISE EXCEPTION 'tenant A expected one visible item, got %', visible_count; END IF;
  IF (SELECT count(*) FROM public.cost_items WHERE "organizationId" = 'org-rls-b') <> 0 THEN
    RAISE EXCEPTION 'tenant A can read tenant B';
  END IF;
END $$;
DO $$
BEGIN
  INSERT INTO public.cost_items ("id","organizationId","name","itemType","referenceUnit","manualUnitCost","createdAt","updatedAt")
  VALUES ('item-rls-a-new','org-rls-a','Item A New','SIMPLE','kg','11','now','now');
  BEGIN
    INSERT INTO public.cost_items ("id","organizationId","name","itemType","referenceUnit","manualUnitCost","createdAt","updatedAt")
    VALUES ('item-rls-b-forged','org-rls-b','Forged B','SIMPLE','kg','99','now','now');
    RAISE EXCEPTION 'cross-tenant INSERT was accepted';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
END $$;
DO $$
BEGIN
  UPDATE public.cost_items SET "name" = 'forged' WHERE "id" = 'item-rls-b';
  IF FOUND THEN RAISE EXCEPTION 'cross-tenant UPDATE was accepted'; END IF;
END $$;
DO $$
BEGIN
  DELETE FROM public.cost_items WHERE "id" = 'item-rls-b';
  IF FOUND THEN RAISE EXCEPTION 'cross-tenant DELETE was accepted'; END IF;
END $$;
DO $$
BEGIN
  INSERT INTO public.cost_calculations ("id","organizationId","itemId","exactCostNumerator","exactCostDenominator","displayUnitCost","calculationSnapshot","calculatedAt")
  VALUES ('snapshot-rls-a','org-rls-a','item-rls-a','10','1','10','{}','now');
  BEGIN
    UPDATE public.cost_calculations SET "displayUnitCost" = '99' WHERE "id" = 'snapshot-rls-a';
    RAISE EXCEPTION 'snapshot UPDATE was accepted';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE '%Cost calculation snapshots are immutable%' THEN
        RAISE;
      END IF;
  END;
END $$;
RESET ROLE;
SQL

printf '%s\n' '=== authenticated read-only tenant A ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
SET ROLE authenticated;
SELECT set_config('request.app_user_id','101',false);
DO $$
DECLARE visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count FROM public.cost_items;
  IF visible_count <> 2 THEN RAISE EXCEPTION 'authenticated expected two tenant A items, got %', visible_count; END IF;
END $$;
DO $$
BEGIN
  INSERT INTO public.cost_groups ("id","organizationId","name","createdAt","updatedAt")
  VALUES ('group-auth-forged','org-rls-a','forbidden','now','now');
  RAISE EXCEPTION 'authenticated INSERT was accepted';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END $$;
RESET ROLE;
SQL

printf '%s\n' '=== role and policy inventory ==='
psql -h "$SOCKET" -p "$PORT" -d postgres -P pager=off -c "
SELECT rolname, rolsuper, rolbypassrls
FROM pg_roles
WHERE rolname IN ('anon','authenticated','app_runtime')
ORDER BY rolname;
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename LIKE 'cost%'
ORDER BY tablename, policyname;
"

printf '%s\n' 'COSTING_RLS_TEST=PASS'
