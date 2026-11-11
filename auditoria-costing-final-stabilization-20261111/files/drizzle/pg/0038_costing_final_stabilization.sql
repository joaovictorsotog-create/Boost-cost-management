-- Final stabilization: keep the counter as the next available version and
-- serialize line mutations with structure publication.

INSERT INTO "cost_structure_version_counters" ("organizationId", "itemId", "nextVersion")
SELECT "organizationId", "itemId", MAX("version") + 1
FROM "cost_structures"
GROUP BY "organizationId", "itemId"
ON CONFLICT ("organizationId", "itemId") DO UPDATE
SET "nextVersion" = GREATEST(
  "cost_structure_version_counters"."nextVersion",
  EXCLUDED."nextVersion"
);

CREATE OR REPLACE FUNCTION "prevent_published_cost_structure_line_mutation"() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  source_status text;
  destination_status text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT "status" INTO destination_status
    FROM "cost_structures"
    WHERE "organizationId" = NEW."organizationId" AND "id" = NEW."structureId"
    FOR UPDATE;
    IF destination_status IS DISTINCT FROM 'DRAFT' THEN
      RAISE EXCEPTION 'Lines of published cost structures are immutable';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Always acquire source and destination structure locks in the same
    -- organization/id order used by publication. This serializes a line
    -- mutation with publication and avoids opposite-order deadlocks when a
    -- line is moved between two DRAFT structures.
    PERFORM 1
    FROM "cost_structures"
    WHERE ("organizationId", "id") IN (
      (OLD."organizationId", OLD."structureId"),
      (NEW."organizationId", NEW."structureId")
    )
    ORDER BY "organizationId", "id"
    FOR UPDATE;

    SELECT "status" INTO source_status
    FROM "cost_structures"
    WHERE "organizationId" = OLD."organizationId" AND "id" = OLD."structureId";
    IF source_status IS DISTINCT FROM 'DRAFT' THEN
      RAISE EXCEPTION 'Lines of published cost structures are immutable';
    END IF;

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
  END IF;

  SELECT "status" INTO source_status
  FROM "cost_structures"
  WHERE "organizationId" = OLD."organizationId" AND "id" = OLD."structureId"
  FOR UPDATE;
  IF source_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'Lines of published cost structures are immutable';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS "cost_structure_lines_published_immutable" ON "cost_structure_lines";
CREATE TRIGGER "cost_structure_lines_published_immutable"
BEFORE INSERT OR UPDATE OR DELETE ON "cost_structure_lines"
FOR EACH ROW EXECUTE FUNCTION "prevent_published_cost_structure_line_mutation"();
