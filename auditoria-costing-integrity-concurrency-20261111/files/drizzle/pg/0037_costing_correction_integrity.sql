DROP INDEX IF EXISTS "cost_calculations_org_item_date_idx";
CREATE INDEX IF NOT EXISTS "cost_calculations_org_item_date_id_idx" ON "cost_calculations" ("organizationId", "itemId", "calculatedAt", "id");

CREATE TABLE IF NOT EXISTS "cost_structure_version_counters" (
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "itemId" varchar(32) NOT NULL,
  "nextVersion" integer NOT NULL CHECK ("nextVersion" > 0),
  CONSTRAINT "cost_structure_version_counters_org_item_unique" UNIQUE ("organizationId", "itemId"),
  CONSTRAINT "cost_structure_version_counters_org_item_fk" FOREIGN KEY ("organizationId", "itemId") REFERENCES "cost_items" ("organizationId", "id") ON DELETE CASCADE
);
INSERT INTO "cost_structure_version_counters" ("organizationId", "itemId", "nextVersion")
SELECT "organizationId", "itemId", MAX("version") + 1
FROM "cost_structures"
GROUP BY "organizationId", "itemId"
ON CONFLICT ("organizationId", "itemId") DO UPDATE
SET "nextVersion" = GREATEST("cost_structure_version_counters"."nextVersion", EXCLUDED."nextVersion");

CREATE OR REPLACE FUNCTION "prevent_published_cost_structure_mutation"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD."status" <> 'DRAFT' THEN
      RAISE EXCEPTION 'Published cost structures are immutable';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD."status" IN ('SUPERSEDED', 'INACTIVE') THEN
    RAISE EXCEPTION 'Published cost structures are immutable';
  END IF;

  IF OLD."status" = 'ACTIVE' THEN
    IF NEW."status" <> 'SUPERSEDED' OR
       ROW(NEW."id", NEW."organizationId", NEW."itemId", NEW."version", NEW."outputQuantity", NEW."createdAt") IS DISTINCT FROM
       ROW(OLD."id", OLD."organizationId", OLD."itemId", OLD."version", OLD."outputQuantity", OLD."createdAt") THEN
      RAISE EXCEPTION 'Active cost structures are immutable except for superseding';
    END IF;
  ELSIF OLD."status" = 'DRAFT' AND NEW."status" NOT IN ('DRAFT', 'ACTIVE') THEN
    RAISE EXCEPTION 'Invalid cost structure status transition';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS "cost_structures_published_immutable" ON "cost_structures";
CREATE TRIGGER "cost_structures_published_immutable" BEFORE UPDATE OR DELETE ON "cost_structures" FOR EACH ROW EXECUTE FUNCTION "prevent_published_cost_structure_mutation"();

CREATE OR REPLACE FUNCTION "prevent_published_cost_structure_line_mutation"() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  source_status text;
  destination_status text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT "status" INTO destination_status
    FROM "cost_structures"
    WHERE "organizationId" = NEW."organizationId" AND "id" = NEW."structureId";
    IF destination_status IS DISTINCT FROM 'DRAFT' THEN
      RAISE EXCEPTION 'Lines of published cost structures are immutable';
    END IF;
    RETURN NEW;
  END IF;

  SELECT "status" INTO source_status
  FROM "cost_structures"
  WHERE "organizationId" = OLD."organizationId" AND "id" = OLD."structureId";
  IF source_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'Lines of published cost structures are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;

  IF NEW."organizationId" <> OLD."organizationId" THEN
    RAISE EXCEPTION 'A cost structure line cannot change organization';
  END IF;
  SELECT "status" INTO destination_status
  FROM "cost_structures"
  WHERE "organizationId" = NEW."organizationId" AND "id" = NEW."structureId";
  IF destination_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'Lines of published cost structures are immutable';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS "cost_structure_lines_published_immutable" ON "cost_structure_lines";
CREATE TRIGGER "cost_structure_lines_published_immutable" BEFORE INSERT OR UPDATE OR DELETE ON "cost_structure_lines" FOR EACH ROW EXECUTE FUNCTION "prevent_published_cost_structure_line_mutation"();
