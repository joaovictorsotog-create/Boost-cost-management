CREATE TABLE IF NOT EXISTS "cost_groups" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "name" varchar(120) NOT NULL,
  "description" text,
  "position" integer NOT NULL DEFAULT 0,
  "active" boolean NOT NULL DEFAULT true,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  CONSTRAINT "cost_groups_org_id_id_unique" UNIQUE ("organizationId", "id"),
  CONSTRAINT "cost_groups_org_name_unique" UNIQUE ("organizationId", "name")
);
CREATE INDEX IF NOT EXISTS "cost_groups_org_active_position_idx" ON "cost_groups" ("organizationId", "active", "position");

CREATE TABLE IF NOT EXISTS "cost_items" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "groupId" varchar(32),
  "code" varchar(64),
  "name" varchar(240) NOT NULL,
  "description" text,
  "itemType" text NOT NULL,
  "referenceUnit" varchar(24) NOT NULL,
  "manualUnitCost" numeric(24,3),
  "active" boolean NOT NULL DEFAULT true,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  CONSTRAINT "cost_items_org_id_id_unique" UNIQUE ("organizationId", "id"),
  CONSTRAINT "cost_items_org_code_unique" UNIQUE ("organizationId", "code"),
  CONSTRAINT "cost_items_org_group_fk" FOREIGN KEY ("organizationId", "groupId") REFERENCES "cost_groups" ("organizationId", "id") ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS "cost_items_org_name_idx" ON "cost_items" ("organizationId", "name");
CREATE INDEX IF NOT EXISTS "cost_items_org_group_active_idx" ON "cost_items" ("organizationId", "groupId", "active");

CREATE TABLE IF NOT EXISTS "cost_structures" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "itemId" varchar(32) NOT NULL,
  "version" integer NOT NULL,
  "status" text NOT NULL DEFAULT 'DRAFT',
  "outputQuantity" numeric(24,3) NOT NULL DEFAULT 1,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  CONSTRAINT "cost_structures_org_id_id_unique" UNIQUE ("organizationId", "id"),
  CONSTRAINT "cost_structures_org_item_version_unique" UNIQUE ("organizationId", "itemId", "version"),
  CONSTRAINT "cost_structures_status_check" CHECK ("status" IN ('DRAFT', 'ACTIVE', 'SUPERSEDED', 'INACTIVE')),
  CONSTRAINT "cost_structures_output_positive_check" CHECK ("outputQuantity" > 0),
  CONSTRAINT "cost_structures_org_item_fk" FOREIGN KEY ("organizationId", "itemId") REFERENCES "cost_items" ("organizationId", "id") ON DELETE RESTRICT
);
CREATE UNIQUE INDEX IF NOT EXISTS "cost_structures_one_active_per_item_idx" ON "cost_structures" ("organizationId", "itemId") WHERE "status" = 'ACTIVE';
CREATE INDEX IF NOT EXISTS "cost_structures_org_item_status_idx" ON "cost_structures" ("organizationId", "itemId", "status");

CREATE TABLE IF NOT EXISTS "cost_structure_lines" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "structureId" varchar(32) NOT NULL,
  "componentItemId" varchar(32) NOT NULL,
  "quantity" numeric(24,3) NOT NULL,
  "quantityUnit" varchar(24) NOT NULL,
  "position" integer NOT NULL DEFAULT 0,
  "notes" text,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  CONSTRAINT "cost_structure_lines_quantity_positive_check" CHECK ("quantity" > 0),
  CONSTRAINT "cost_structure_lines_org_structure_fk" FOREIGN KEY ("organizationId", "structureId") REFERENCES "cost_structures" ("organizationId", "id") ON DELETE CASCADE,
  CONSTRAINT "cost_structure_lines_org_component_fk" FOREIGN KEY ("organizationId", "componentItemId") REFERENCES "cost_items" ("organizationId", "id") ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS "cost_structure_lines_structure_position_idx" ON "cost_structure_lines" ("organizationId", "structureId", "position");
CREATE INDEX IF NOT EXISTS "cost_structure_lines_component_idx" ON "cost_structure_lines" ("organizationId", "componentItemId");

CREATE TABLE IF NOT EXISTS "cost_calculations" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "itemId" varchar(32) NOT NULL,
  "structureId" varchar(32),
  "exactCostNumerator" text NOT NULL,
  "exactCostDenominator" text NOT NULL,
  "displayUnitCost" numeric(24,3) NOT NULL,
  "snapshotVersion" integer NOT NULL DEFAULT 1,
  "calculationSnapshot" jsonb NOT NULL,
  "calculatedAt" text NOT NULL,
  CONSTRAINT "cost_calculations_org_item_fk" FOREIGN KEY ("organizationId", "itemId") REFERENCES "cost_items" ("organizationId", "id") ON DELETE RESTRICT,
  CONSTRAINT "cost_calculations_org_structure_fk" FOREIGN KEY ("organizationId", "structureId") REFERENCES "cost_structures" ("organizationId", "id") ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS "cost_calculations_org_item_date_idx" ON "cost_calculations" ("organizationId", "itemId", "calculatedAt");

CREATE TABLE IF NOT EXISTS "costing_gamma_settings" (
  "id" varchar(32) PRIMARY KEY,
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "active" boolean NOT NULL DEFAULT false,
  "percentage" numeric(8,4) NOT NULL DEFAULT 1.2000,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  CONSTRAINT "costing_gamma_percentage_nonnegative_check" CHECK ("percentage" >= 0),
  CONSTRAINT "costing_gamma_settings_org_unique" UNIQUE ("organizationId")
);
CREATE TABLE IF NOT EXISTS "costing_gamma_groups" (
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "groupId" varchar(32) NOT NULL,
  "createdAt" text NOT NULL,
  CONSTRAINT "costing_gamma_groups_org_group_unique" UNIQUE ("organizationId", "groupId"),
  CONSTRAINT "costing_gamma_groups_org_group_fk" FOREIGN KEY ("organizationId", "groupId") REFERENCES "cost_groups" ("organizationId", "id") ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION "prevent_cost_calculation_update"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Cost calculation snapshots are immutable';
END;
$$;
DROP TRIGGER IF EXISTS "cost_calculations_immutable" ON "cost_calculations";
CREATE TRIGGER "cost_calculations_immutable" BEFORE UPDATE OR DELETE ON "cost_calculations" FOR EACH ROW EXECUTE FUNCTION "prevent_cost_calculation_update"();
