#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="/usr/lib/postgresql/16/bin:$PATH"
TEMP_ROOT=$(mktemp -d /tmp/alianza-costing-correction-pg-XXXXXX)
SOCKET="$TEMP_ROOT/socket"
PORT="${COSTING_PG_PORT:-55443}"

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
CREATE TABLE "organizations" ("id" varchar(32) PRIMARY KEY);
INSERT INTO "organizations" VALUES ('org-correction-a'), ('org-correction-b');
SQL
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 -f "$ROOT_DIR/drizzle/pg/0036_costing_foundation.sql" >/dev/null
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO "cost_groups" ("id","organizationId","name","createdAt","updatedAt") VALUES
  ('group-a','org-correction-a','Artificial selected group','now','now'),
  ('group-b','org-correction-b','Artificial foreign group','now','now');
INSERT INTO "cost_items" ("id","organizationId","groupId","name","itemType","referenceUnit","manualUnitCost","active","createdAt","updatedAt") VALUES
  ('source-a','org-correction-a','group-a','Artificial source A','SIMPLE','un','100',true,'now','now'),
  ('target-a','org-correction-a',NULL,'Artificial target A','COMPOSITE','un',NULL,true,'now','now'),
  ('target-c','org-correction-a',NULL,'Artificial target C','COMPOSITE','un',NULL,true,'now','now'),
  ('target-empty','org-correction-a',NULL,'Artificial empty target','COMPOSITE','un',NULL,true,'now','now'),
  ('target-one','org-correction-a',NULL,'Artificial one-version target','COMPOSITE','un',NULL,true,'now','now'),
  ('target-gap','org-correction-a',NULL,'Artificial gap target','COMPOSITE','un',NULL,true,'now','now'),
  ('target-failing','org-correction-a',NULL,'Artificial rollback target','COMPOSITE','un',NULL,true,'now','now'),
  ('source-b','org-correction-b','group-b','Artificial foreign source B','SIMPLE','un','999',true,'now','now'),
  ('target-b','org-correction-b',NULL,'Artificial target B','COMPOSITE','un',NULL,true,'now','now');
INSERT INTO "cost_structures" ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt") VALUES
  ('active-a','org-correction-a','target-a',1,'ACTIVE','2','now','now'),
  ('draft-a','org-correction-a','target-a',2,'DRAFT','1','now','now'),
  ('superseded-a','org-correction-a','target-a',3,'SUPERSEDED','1','now','now'),
  ('inactive-a','org-correction-a','target-a',4,'INACTIVE','1','now','now'),
  ('direct-active','org-correction-a','target-c',1,'ACTIVE','1','now','now'),
  ('one-v1','org-correction-a','target-one',1,'DRAFT','1','now','now'),
  ('gap-v1','org-correction-a','target-gap',1,'DRAFT','1','now','now'),
  ('gap-v3','org-correction-a','target-gap',3,'DRAFT','1','now','now');
SQL
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt") VALUES
  ('active-line-a','org-correction-a','active-a','source-a','1','un',0,'now','now'),
  ('draft-line-a','org-correction-a','draft-a','source-a','1','un',0,'now','now'),
  ('direct-active-line','org-correction-a','direct-active','source-a','1','un',0,'now','now');
SQL
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 -f "$ROOT_DIR/drizzle/pg/0037_costing_correction_integrity.sql" >/dev/null
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 -f "$ROOT_DIR/drizzle/pg/0038_costing_final_stabilization.sql" >/dev/null
psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO "costing_gamma_settings" ("id","organizationId","active","percentage","createdAt","updatedAt") VALUES
  ('gamma-a','org-correction-a',true,'1.2000','now','now');
INSERT INTO "costing_gamma_groups" ("organizationId","groupId","createdAt") VALUES
  ('org-correction-a','group-a','now');
SQL
SUPABASE_DATABASE_URL="postgres://$(whoami)@127.0.0.1:$PORT/postgres" pnpm --dir "$ROOT_DIR" exec tsx "$ROOT_DIR/scripts/costing-correction-pg.ts"
SUPABASE_DATABASE_URL="postgres://$(whoami)@127.0.0.1:$PORT/postgres" pnpm --dir "$ROOT_DIR" exec tsx "$ROOT_DIR/scripts/costing-line-publication-race-pg.ts"

psql -h "$SOCKET" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  UPDATE "cost_structures" SET "id" = 'direct-active-mutated' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure id mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "organizationId" = 'org-correction-b' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure organization mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "itemId" = 'target-b' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure item mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "version" = 99 WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure version mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "outputQuantity" = '9' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure output mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "createdAt" = 'changed' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure createdAt mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "status" = 'INACTIVE' WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure invalid transition was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Active cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  DELETE FROM "cost_structures" WHERE "id" = 'direct-active';
  RAISE EXCEPTION 'published structure deletion was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "outputQuantity" = '9' WHERE "id" = 'superseded-a';
  RAISE EXCEPTION 'superseded structure update was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  DELETE FROM "cost_structures" WHERE "id" = 'superseded-a';
  RAISE EXCEPTION 'superseded structure deletion was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structures" SET "outputQuantity" = '9' WHERE "id" = 'inactive-a';
  RAISE EXCEPTION 'inactive structure update was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  DELETE FROM "cost_structures" WHERE "id" = 'inactive-a';
  RAISE EXCEPTION 'inactive structure deletion was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
  VALUES ('draft-direct-line','org-correction-a','draft-a','source-a','1','un',2,'now','now');
  UPDATE "cost_structure_lines" SET "quantity" = '2' WHERE "id" = 'draft-direct-line';
  DELETE FROM "cost_structure_lines" WHERE "id" = 'draft-direct-line';
END $$;
DO $$ BEGIN
  UPDATE "cost_structure_lines"
  SET "organizationId" = 'org-correction-b', "structureId" = 'direct-active'
  WHERE "id" = 'draft-line-a';
  RAISE EXCEPTION 'simultaneous organization and structure mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%cannot change organization%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
  VALUES ('insert-active-line','org-correction-a','direct-active','source-a','1','un',1,'now','now');
  RAISE EXCEPTION 'line INSERT into ACTIVE was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
  VALUES ('insert-superseded-line','org-correction-a','active-a','source-a','1','un',1,'now','now');
  RAISE EXCEPTION 'line INSERT into SUPERSEDED was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
  VALUES ('insert-inactive-line','org-correction-a','inactive-a','source-a','1','un',1,'now','now');
  RAISE EXCEPTION 'line INSERT into INACTIVE was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structure_lines" SET "quantity" = '2' WHERE "id" = 'direct-active-line';
  RAISE EXCEPTION 'line UPDATE in published structure was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structure_lines" SET "structureId" = 'direct-active' WHERE "id" = 'draft-line-a';
  RAISE EXCEPTION 'line move from DRAFT to ACTIVE was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  UPDATE "cost_structure_lines" SET "organizationId" = 'org-correction-b' WHERE "id" = 'draft-line-a';
  RAISE EXCEPTION 'line organization mutation was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%cannot change organization%' THEN RAISE; END IF;
END $$;
DO $$ BEGIN
  DELETE FROM "cost_structure_lines" WHERE "id" = 'direct-active-line';
  RAISE EXCEPTION 'line DELETE in published structure was accepted';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Lines of published cost structures are immutable%' THEN RAISE; END IF;
END $$;
SELECT 'direct-published-immutability-and-line-protection-ok' AS result;
SELECT "organizationId", "itemId", "nextVersion"
FROM "cost_structure_version_counters"
WHERE "organizationId" = 'org-correction-a'
  AND "itemId" IN ('target-a','target-empty','target-one','target-gap')
ORDER BY "itemId";
SELECT "organizationId", "itemId", "status", count(*) AS structure_count
FROM "cost_structures"
WHERE "organizationId" = 'org-correction-a' AND "itemId" = 'target-a'
GROUP BY "organizationId", "itemId", "status"
ORDER BY "status";
SQL
