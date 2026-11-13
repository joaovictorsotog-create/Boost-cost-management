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
$P -U app_runtime <<'SQL'
SELECT set_config('request.app_user_id','1',false);
INSERT INTO costing_gamma_groups ("organizationId","groupId","createdAt") VALUES ('org-a','g-a','now') ON CONFLICT DO NOTHING;
DO $$
DECLARE t text; own_count integer; other_count integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I WHERE "organizationId" = %L', t, 'org-a') INTO own_count;
    EXECUTE format('SELECT count(*) FROM public.%I WHERE "organizationId" = %L', t, 'org-b') INTO other_count;
    IF own_count <> 1 OR other_count <> 0 THEN RAISE EXCEPTION 'A isolation failed for %: own %, other %', t, own_count, other_count; END IF;
    RAISE NOTICE 'isolation role=app_runtime org=org-a table=% own=% other=%', t, own_count, other_count;
  END LOOP;
END $$;
SELECT 'runtime_org_a_all_seven=ok' AS result;
SQL

$P -U app_runtime <<'SQL'
SELECT session_user, current_user;
SELECT set_config('request.app_user_id','2',false);
DO $$
DECLARE t text; own_count integer; other_count integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I WHERE "organizationId" = %L', t, 'org-b') INTO own_count;
    EXECUTE format('SELECT count(*) FROM public.%I WHERE "organizationId" = %L', t, 'org-a') INTO other_count;
    IF own_count <> 1 OR other_count <> 0 THEN RAISE EXCEPTION 'B isolation failed for %: own %, other %', t, own_count, other_count; END IF;
    RAISE NOTICE 'isolation role=app_runtime org=org-b table=% own=% other=%', t, own_count, other_count;
  END LOOP;
END $$;
SELECT 'runtime_org_b_all_seven=ok' AS result;
SQL
$P -U app_runtime <<'SQL'
SELECT set_config('request.app_user_id','1',false);
DO $$
DECLARE t text; changed integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    BEGIN
      CASE t
        WHEN 'cost_groups' THEN EXECUTE 'UPDATE public.cost_groups SET name = ''cross'' WHERE "organizationId" = ''org-b''';
        WHEN 'cost_items' THEN EXECUTE 'UPDATE public.cost_items SET name = ''cross'' WHERE "organizationId" = ''org-b''';
        WHEN 'cost_structures' THEN EXECUTE 'UPDATE public.cost_structures SET status = ''INACTIVE'' WHERE "organizationId" = ''org-b''';
        WHEN 'cost_structure_lines' THEN EXECUTE 'UPDATE public.cost_structure_lines SET quantity = 9 WHERE "organizationId" = ''org-b''';
        WHEN 'cost_calculations' THEN EXECUTE 'UPDATE public.cost_calculations SET "displayUnitCost" = 9 WHERE "organizationId" = ''org-b''';
        WHEN 'costing_gamma_settings' THEN EXECUTE 'UPDATE public.costing_gamma_settings SET percentage = 9 WHERE "organizationId" = ''org-b''';
        WHEN 'costing_gamma_groups' THEN EXECUTE 'UPDATE public.costing_gamma_groups SET "groupId" = ''g-a'' WHERE "organizationId" = ''org-b''';
      END CASE;
      GET DIAGNOSTICS changed = ROW_COUNT;
      IF changed <> 0 THEN RAISE EXCEPTION 'cross update unexpectedly changed % rows in %', changed, t; END IF;
      RAISE NOTICE 'cross_update table=% blocked=no_visible_rows', t;
    EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'cross_update table=% blocked=permission_denied', t;
    END;
  END LOOP;
END $$;
DO $$
DECLARE t text; changed integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['cost_groups','cost_items','cost_structures','cost_structure_lines','cost_calculations','costing_gamma_settings','costing_gamma_groups'] LOOP
    BEGIN
      EXECUTE format('DELETE FROM public.%I WHERE "organizationId" = %L', t, 'org-b');
      GET DIAGNOSTICS changed = ROW_COUNT;
      IF changed <> 0 THEN RAISE EXCEPTION 'cross delete unexpectedly changed % rows in %', changed, t; END IF;
      RAISE NOTICE 'cross_delete table=% blocked=no_visible_rows', t;
    EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'cross_delete table=% blocked=permission_denied', t;
    END;
  END LOOP;
END $$;
SELECT 'runtime_cross_update_delete_all_seven=ok' AS result;
SQL
$P -U app_runtime <<'SQL'
SELECT set_config('request.app_user_id','1',false);
INSERT INTO costing_gamma_groups ("organizationId","groupId","createdAt") VALUES ('org-a','g-a','now') ON CONFLICT DO NOTHING;
DO $$
DECLARE state text; message text; succeeded boolean;
BEGIN
  succeeded := false; BEGIN INSERT INTO cost_groups (id,"organizationId",name,"createdAt","updatedAt") VALUES ('cross-g-rls','org-b','X','now','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert cost_groups unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=cost_groups sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded cost_groups'; END IF;
  succeeded := false; BEGIN INSERT INTO cost_items (id,"organizationId","groupId",name,"itemType","referenceUnit","createdAt","updatedAt") VALUES ('cross-i-rls','org-b','g-b','X','SIMPLE','un','now','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert cost_items unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=cost_items sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded cost_items'; END IF;
  succeeded := false; BEGIN INSERT INTO cost_structures (id,"organizationId","itemId",version,status,"outputQuantity","createdAt","updatedAt") VALUES ('cross-s-rls','org-b','i-b',2,'DRAFT',1,'now','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert cost_structures unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=cost_structures sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded cost_structures'; END IF;
  succeeded := false; BEGIN INSERT INTO cost_structure_lines (id,"organizationId","structureId","componentItemId",quantity,"quantityUnit","createdAt","updatedAt") VALUES ('cross-l-rls','org-b','s-b','i-b',1,'un','now','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert cost_structure_lines unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=cost_structure_lines sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded cost_structure_lines'; END IF;
  succeeded := false; BEGIN INSERT INTO cost_calculations (id,"organizationId","itemId","structureId","exactCostNumerator","exactCostDenominator","displayUnitCost","calculationSnapshot","calculatedAt") VALUES ('cross-c-rls','org-b','i-b','s-b','1','1',1,'{}','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert cost_calculations unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=cost_calculations sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded cost_calculations'; END IF;
  succeeded := false; BEGIN INSERT INTO costing_gamma_settings (id,"organizationId",active,percentage,"createdAt","updatedAt") VALUES ('cross-gs-rls','org-b',true,1,'now','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert costing_gamma_settings unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=costing_gamma_settings sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded costing_gamma_settings'; END IF;
  succeeded := false; BEGIN INSERT INTO costing_gamma_groups ("organizationId","groupId","createdAt") VALUES ('org-b','g-b','now'); succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'cross insert costing_gamma_groups unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'cross_insert table=costing_gamma_groups sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'cross insert succeeded costing_gamma_groups'; END IF;
  RAISE NOTICE 'cross_insert all_seven blocked_by_rls';
END $$;
SELECT 'runtime_cross_insert_all_seven=ok' AS result;
SQL
$P -U app_runtime <<'SQL'
SELECT set_config('request.app_user_id','1',false);
INSERT INTO costing_gamma_groups ("organizationId","groupId","createdAt") VALUES ('org-a','g-a','now') ON CONFLICT DO NOTHING;
DO $$
DECLARE state text; message text; succeeded boolean; visible integer;
BEGIN
  SELECT count(*) INTO visible FROM cost_groups WHERE id='g-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture cost_groups not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE cost_groups SET "organizationId"='org-b' WHERE id='g-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer cost_groups unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=cost_groups sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded cost_groups'; END IF;
  SELECT count(*) INTO visible FROM cost_items WHERE id='i-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture cost_items not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE cost_items SET "organizationId"='org-b' WHERE id='i-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer cost_items unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=cost_items sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded cost_items'; END IF;
  SELECT count(*) INTO visible FROM cost_structures WHERE id='s-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture cost_structures not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE cost_structures SET "organizationId"='org-b' WHERE id='s-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer cost_structures unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=cost_structures sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded cost_structures'; END IF;
  SELECT count(*) INTO visible FROM cost_structure_lines WHERE id='l-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture cost_structure_lines not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE cost_structure_lines SET "organizationId"='org-b' WHERE id='l-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer cost_structure_lines unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=cost_structure_lines sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded cost_structure_lines'; END IF;
  SELECT count(*) INTO visible FROM cost_calculations WHERE id='c-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture cost_calculations not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE cost_calculations SET "organizationId"='org-b' WHERE id='c-a'; succeeded := true; EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE 'permission denied for table%' THEN RAISE EXCEPTION 'transfer cost_calculations unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=cost_calculations sqlstate=% origin=privilege message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded cost_calculations'; END IF;
  SELECT count(*) INTO visible FROM costing_gamma_settings WHERE id='gs-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture costing_gamma_settings not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE costing_gamma_settings SET "organizationId"='org-b' WHERE id='gs-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer costing_gamma_settings unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=costing_gamma_settings sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded costing_gamma_settings'; END IF;
  SELECT count(*) INTO visible FROM costing_gamma_groups WHERE "organizationId"='org-a' AND "groupId"='g-a'; IF visible <> 1 THEN RAISE EXCEPTION 'transfer fixture costing_gamma_groups not visible: %', visible; END IF;
  succeeded := false; BEGIN UPDATE costing_gamma_groups SET "organizationId"='org-b' WHERE "organizationId"='org-a' AND "groupId"='g-a'; succeeded := true; EXCEPTION WHEN others THEN GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT; IF state <> '42501' OR message NOT LIKE '%row-level security policy%' THEN RAISE EXCEPTION 'transfer costing_gamma_groups unexpected SQLSTATE=% message=%', state, message; END IF; RAISE NOTICE 'transfer table=costing_gamma_groups sqlstate=% origin=rls message=%', state, message; END; IF succeeded THEN RAISE EXCEPTION 'transfer update succeeded costing_gamma_groups'; END IF;
  RAISE NOTICE 'transfer_update all_seven blocked_with_origin';
END $$;
SELECT 'runtime_org_transfer_updates_blocked=ok' AS result;
SQL
echo 'postgresql_rls_correction=PASS'
