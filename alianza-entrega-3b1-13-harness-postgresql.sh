#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/lib/postgresql/16/bin:$PATH"
ROOT=$(mktemp -d /tmp/costing-rls-correction-XXXXXX)
SOCK="$ROOT/socket"
PORT=55444
APP=/home/ubuntu/work/alianza-ai-platform
initdb -D "$ROOT/data" -A trust --no-locale >/dev/null
printf "listen_addresses = '127.0.0.1'\nport = %s\nunix_socket_directories = '%s'\n" "$PORT" "$SOCK" >> "$ROOT/data/postgresql.conf"
mkdir -p "$SOCK"
pg_ctl -D "$ROOT/data" -o "-k $SOCK" -w start >/dev/null
trap 'pg_ctl -D "$ROOT/data" -m immediate -w stop >/dev/null 2>&1 || true; rm -rf "$ROOT"' EXIT
P="psql -h $SOCK -p $PORT -d postgres -v ON_ERROR_STOP=1"
$P <<'SQL'
CREATE ROLE anon LOGIN;
CREATE ROLE authenticated LOGIN;
CREATE ROLE app_runtime LOGIN NOBYPASSRLS NOSUPERUSER;
CREATE SCHEMA auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE SCHEMA private;
CREATE TABLE organizations (id varchar(32) PRIMARY KEY);
CREATE TABLE users (id integer PRIMARY KEY, "supabaseAuthId" uuid, name text);
CREATE TABLE organization_members (id serial PRIMARY KEY, "organizationId" varchar(32), "userId" integer, status text);
CREATE OR REPLACE FUNCTION public.rls_auto_enable() RETURNS void LANGUAGE sql AS $$ SELECT NULL::void $$;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ai_agents','ai_return_rules','ai_runs','alerts','audit_logs','automation_jobs','automations',
    'campaign_logs','campaign_metrics','campaign_recipients','campaigns','channels','companies',
    'contact_tags','contacts','conversation_events','conversations','crm_activities','custom_fields',
    'custom_role_permissions','custom_roles','deals','departments','follow_up_rules','handoffs',
    'integration_configs','kanban_boards','kanban_cards','kanban_columns','knowledge_chunks',
    'knowledge_documents','messages','organization_access_requests','organization_invitations',
    'pipeline_stages','pipelines','prompt_versions','service_queues','tags','webhook_deliveries',
    'webhook_endpoints'
  ] LOOP EXECUTE format('CREATE TABLE %I (id serial PRIMARY KEY, "organizationId" varchar(32))', t); END LOOP;
END $$;
INSERT INTO organizations VALUES ('org-a'), ('org-b');
INSERT INTO users VALUES
 (1, '00000000-0000-0000-0000-000000000001', 'A'),
 (2, '00000000-0000-0000-0000-000000000002', 'B');
INSERT INTO organization_members ("organizationId", "userId", status) VALUES
 ('org-a', 1, 'active'), ('org-b', 2, 'active');
SQL
$P -f "$APP/drizzle/pg/0036_costing_foundation.sql" >/dev/null
$P <<'SQL'
INSERT INTO cost_groups (id, "organizationId", name, "createdAt", "updatedAt") VALUES
 ('g-a', 'org-a', 'A', 'now', 'now'), ('g-b', 'org-b', 'B', 'now', 'now');
INSERT INTO cost_items (id, "organizationId", "groupId", name, "itemType", "referenceUnit", "manualUnitCost", "createdAt", "updatedAt") VALUES
 ('i-a', 'org-a', 'g-a', 'A', 'SIMPLE', 'un', 1, 'now', 'now'), ('i-b', 'org-b', 'g-b', 'B', 'SIMPLE', 'un', 2, 'now', 'now');
INSERT INTO cost_structures (id, "organizationId", "itemId", version, status, "outputQuantity", "createdAt", "updatedAt") VALUES
 ('s-a', 'org-a', 'i-a', 1, 'DRAFT', 1, 'now', 'now'), ('s-b', 'org-b', 'i-b', 1, 'DRAFT', 1, 'now', 'now');
INSERT INTO cost_structure_lines (id, "organizationId", "structureId", "componentItemId", quantity, "quantityUnit", "createdAt", "updatedAt") VALUES
 ('l-a', 'org-a', 's-a', 'i-a', 1, 'un', 'now', 'now'), ('l-b', 'org-b', 's-b', 'i-b', 1, 'un', 'now', 'now');
INSERT INTO cost_calculations (id, "organizationId", "itemId", "structureId", "exactCostNumerator", "exactCostDenominator", "displayUnitCost", "calculationSnapshot", "calculatedAt") VALUES
 ('c-a', 'org-a', 'i-a', 's-a', '1', '1', 1, '{"org":"a"}', 'now'), ('c-b', 'org-b', 'i-b', 's-b', '2', '1', 2, '{"org":"b"}', 'now');
INSERT INTO costing_gamma_settings (id, "organizationId", active, percentage, "createdAt", "updatedAt") VALUES
 ('gs-a', 'org-a', true, 1.2, 'now', 'now'), ('gs-b', 'org-b', true, 1.3, 'now', 'now');
INSERT INTO costing_gamma_groups ("organizationId", "groupId", "createdAt") VALUES
 ('org-a', 'g-a', 'now'), ('org-b', 'g-b', 'now');
SQL
for run in 1 2; do
  $P -f "$APP/drizzle/pg/rls_multitenant.sql" >/dev/null
  echo "rls_run_${run}=ok"
done
$P <<'SQL'
DO $$
DECLARE n integer; t text;
BEGIN
  IF (SELECT count(*) FROM pg_class WHERE relname IN ('cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups') AND relrowsecurity) <> 7 THEN RAISE EXCEPTION 'RLS count'; END IF;
  IF (SELECT count(*) FROM pg_class WHERE relname IN ('cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups') AND relforcerowsecurity) <> 7 THEN RAISE EXCEPTION 'FORCE count'; END IF;
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname='costing_app_runtime_read' AND roles @> ARRAY['app_runtime'::name] AND cmd='SELECT') THEN RAISE EXCEPTION 'missing runtime select policy for %', t; END IF;
  END LOOP;
END $$;
SELECT has_schema_privilege('app_runtime','private','USAGE') AS runtime_private_usage,
       has_function_privilege('app_runtime','private.has_organization_access(character varying)','EXECUTE') AS runtime_helper_execute,
       has_function_privilege('public','private.has_organization_access(character varying)','EXECUTE') AS public_helper_execute,
       has_function_privilege('anon','private.has_organization_access(character varying)','EXECUTE') AS anon_helper_execute;
SQL
$P -U app_runtime <<'SQL'
SELECT session_user, current_user;
SELECT set_config('request.app_user_id', '1', false);
DO $$
DECLARE t text; n integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
    IF n <> 1 THEN RAISE EXCEPTION 'runtime own-tenant read failed for %: %', t, n; END IF;
  END LOOP;
END $$;
SELECT 'runtime_read_own_tenant=ok' AS result;
DO $$ BEGIN
  INSERT INTO cost_groups (id, "organizationId", name, "createdAt", "updatedAt") VALUES ('g-a2','org-a','A2','now','now');
  UPDATE cost_groups SET name='A2-updated' WHERE id='g-a2';
  DELETE FROM cost_groups WHERE id='g-a2';
  INSERT INTO cost_items (id, "organizationId", "groupId", name, "itemType", "referenceUnit", "createdAt", "updatedAt") VALUES ('i-a2','org-a','g-a','A2','SIMPLE','un','now','now');
  UPDATE cost_items SET name='A2-updated' WHERE id='i-a2';
  DELETE FROM cost_items WHERE id='i-a2';
  INSERT INTO cost_structures (id, "organizationId", "itemId", version, status, "outputQuantity", "createdAt", "updatedAt") VALUES ('s-a2','org-a','i-a',2,'DRAFT',1,'now','now');
  UPDATE cost_structures SET status='INACTIVE' WHERE id='s-a2';
  DELETE FROM cost_structures WHERE id='s-a2';
  INSERT INTO cost_structure_lines (id, "organizationId", "structureId", "componentItemId", quantity, "quantityUnit", "createdAt", "updatedAt") VALUES ('l-a2','org-a','s-a', 'i-a', 2,'un','now','now');
  UPDATE cost_structure_lines SET quantity=3 WHERE id='l-a2';
  DELETE FROM cost_structure_lines WHERE id='l-a2';
  INSERT INTO costing_gamma_groups ("organizationId", "groupId", "createdAt") VALUES ('org-a','g-a','now') ON CONFLICT DO NOTHING;
  DELETE FROM costing_gamma_groups WHERE "organizationId"='org-a' AND "groupId"='g-a';
  UPDATE costing_gamma_settings SET percentage=1.25 WHERE "organizationId"='org-a';
  UPDATE costing_gamma_settings SET percentage=1.20 WHERE "organizationId"='org-a';
END $$;
SELECT 'runtime_authorized_writes=ok' AS result;
SQL
if $P -U app_runtime <<'SQL' >/tmp/snapshot-update.out 2>/tmp/snapshot-update.err
UPDATE cost_calculations SET "displayUnitCost"=9 WHERE id='c-a';
SQL
then
  echo 'snapshot_update=unexpected_success'; exit 1
else
  echo 'snapshot_update=blocked'; cat /tmp/snapshot-update.err
fi
if $P -U app_runtime <<'SQL' >/tmp/snapshot-delete.out 2>/tmp/snapshot-delete.err
DELETE FROM cost_calculations WHERE id='c-a';
SQL
then
  echo 'snapshot_delete=unexpected_success'; exit 1
else
  echo 'snapshot_delete=blocked'; cat /tmp/snapshot-delete.err
fi
$P -U app_runtime <<'SQL'
SELECT set_config('request.app_user_id','1',false);
DO $$ DECLARE n integer; BEGIN SELECT count(*) INTO n FROM cost_items WHERE "organizationId"='org-b'; IF n <> 0 THEN RAISE EXCEPTION 'runtime cross-tenant read: %', n; END IF; END $$;
SELECT 'runtime_cross_tenant_isolation=ok' AS result;
SQL
$P -U authenticated <<'SQL'
SELECT session_user, current_user;
SELECT set_config('request.app_user_id', '2', false);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
DO $$ DECLARE n integer; BEGIN SELECT count(*) INTO n FROM cost_items; IF n <> 1 OR NOT EXISTS (SELECT 1 FROM cost_items WHERE "organizationId"='org-a') THEN RAISE EXCEPTION 'authenticated identity/GUC isolation failed: %', n; END IF; END $$;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$ DECLARE n integer; BEGIN SELECT count(*) INTO n FROM cost_items; IF n <> 0 THEN RAISE EXCEPTION 'JWT absent access: %', n; END IF; END $$;
SELECT 'authenticated_identity_and_no_jwt=ok' AS result;
SQL
if $P -U anon -c 'SELECT count(*) FROM cost_items' >/tmp/anon-rls.out 2>/tmp/anon-rls.err; then
  echo 'anon_access=unexpected_success'; cat /tmp/anon-rls.out; exit 1
else
  echo 'anon_access=blocked'; cat /tmp/anon-rls.err
fi
echo 'postgresql_rls_correction=PASS'
