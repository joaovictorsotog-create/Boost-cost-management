import {
  boolean,
  check,
  decimal,
  foreignKey,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  unique,
  uniqueIndex,
  varchar,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { organizations } from "../schema.pg";

/**
 * Cadastro central de custos.
 *
 * Valores monetários são strings decimais ou frações racionais. Não usar
 * mode: "number": a precisão exata do motor depende de não passar por float.
 */
export const costGroups = pgTable(
  "cost_groups",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    name: varchar("name", { length: 120 }).notNull(),
    description: text("description"),
    position: integer("position").default(0).notNull(),
    active: boolean("active").default(true).notNull(),
    createdAt: text("createdAt").notNull(),
    updatedAt: text("updatedAt").notNull(),
  },
  table => [
    unique("cost_groups_org_id_id_unique").on(table.organizationId, table.id),
    unique("cost_groups_org_name_unique").on(table.organizationId, table.name),
    index("cost_groups_org_active_position_idx").on(
      table.organizationId,
      table.active,
      table.position
    ),
  ]
);

export const costItems = pgTable(
  "cost_items",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    groupId: varchar("groupId", { length: 32 }),
    code: varchar("code", { length: 64 }),
    name: varchar("name", { length: 240 }).notNull(),
    description: text("description"),
    itemType: text("itemType").$type<"SIMPLE" | "COMPOSITE">().notNull(),
    referenceUnit: varchar("referenceUnit", { length: 24 }).notNull(),
    manualUnitCost: decimal("manualUnitCost", {
      precision: 24,
      scale: 3,
      mode: "string",
    }),
    active: boolean("active").default(true).notNull(),
    createdAt: text("createdAt").notNull(),
    updatedAt: text("updatedAt").notNull(),
  },
  table => [
    unique("cost_items_org_id_id_unique").on(table.organizationId, table.id),
    unique("cost_items_org_code_unique").on(table.organizationId, table.code),
    foreignKey({
      name: "cost_items_org_group_fk",
      columns: [table.organizationId, table.groupId],
      foreignColumns: [costGroups.organizationId, costGroups.id],
    }).onDelete("restrict"),
    index("cost_items_org_name_idx").on(table.organizationId, table.name),
    index("cost_items_org_group_active_idx").on(
      table.organizationId,
      table.groupId,
      table.active
    ),
  ]
);

export const costStructures = pgTable(
  "cost_structures",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    itemId: varchar("itemId", { length: 32 }).notNull(),
    version: integer("version").notNull(),
    status: text("status")
      .$type<"DRAFT" | "ACTIVE" | "SUPERSEDED" | "INACTIVE">()
      .default("DRAFT")
      .notNull(),
    outputQuantity: decimal("outputQuantity", {
      precision: 24,
      scale: 3,
      mode: "string",
    })
      .default("1")
      .notNull(),
    createdAt: text("createdAt").notNull(),
    updatedAt: text("updatedAt").notNull(),
  },
  table => [
    unique("cost_structures_org_id_id_unique").on(
      table.organizationId,
      table.id
    ),
    unique("cost_structures_org_item_version_unique").on(
      table.organizationId,
      table.itemId,
      table.version
    ),
    check(
      "cost_structures_status_check",
      sql`${table.status} in ('DRAFT', 'ACTIVE', 'SUPERSEDED', 'INACTIVE')`
    ),
    check(
      "cost_structures_output_positive_check",
      sql`${table.outputQuantity} > 0`
    ),
    // A single published structure is authoritative for an item at any moment.
    // Drafts and historical versions remain unrestricted.
    uniqueIndex("cost_structures_one_active_per_item_idx")
      .on(table.organizationId, table.itemId)
      .where(sql`${table.status} = 'ACTIVE'`),
    foreignKey({
      name: "cost_structures_org_item_fk",
      columns: [table.organizationId, table.itemId],
      foreignColumns: [costItems.organizationId, costItems.id],
    }).onDelete("restrict"),
    index("cost_structures_org_item_status_idx").on(
      table.organizationId,
      table.itemId,
      table.status
    ),
  ]
);

export const costStructureLines = pgTable(
  "cost_structure_lines",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    structureId: varchar("structureId", { length: 32 }).notNull(),
    componentItemId: varchar("componentItemId", { length: 32 }).notNull(),
    quantity: decimal("quantity", {
      precision: 24,
      scale: 3,
      mode: "string",
    }).notNull(),
    quantityUnit: varchar("quantityUnit", { length: 24 }).notNull(),
    position: integer("position").default(0).notNull(),
    notes: text("notes"),
    createdAt: text("createdAt").notNull(),
    updatedAt: text("updatedAt").notNull(),
  },
  table => [
    check(
      "cost_structure_lines_quantity_positive_check",
      sql`${table.quantity} > 0`
    ),
    foreignKey({
      name: "cost_structure_lines_org_structure_fk",
      columns: [table.organizationId, table.structureId],
      foreignColumns: [costStructures.organizationId, costStructures.id],
    }).onDelete("cascade"),
    foreignKey({
      name: "cost_structure_lines_org_component_fk",
      columns: [table.organizationId, table.componentItemId],
      foreignColumns: [costItems.organizationId, costItems.id],
    }).onDelete("restrict"),
    index("cost_structure_lines_structure_position_idx").on(
      table.organizationId,
      table.structureId,
      table.position
    ),
    index("cost_structure_lines_component_idx").on(
      table.organizationId,
      table.componentItemId
    ),
  ]
);

export const costCalculations = pgTable(
  "cost_calculations",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    itemId: varchar("itemId", { length: 32 }).notNull(),
    structureId: varchar("structureId", { length: 32 }),
    exactCostNumerator: text("exactCostNumerator").notNull(),
    exactCostDenominator: text("exactCostDenominator").notNull(),
    displayUnitCost: decimal("displayUnitCost", {
      precision: 24,
      scale: 3,
      mode: "string",
    }).notNull(),
    snapshotVersion: integer("snapshotVersion").default(1).notNull(),
    calculationSnapshot: jsonb("calculationSnapshot")
      .$type<Record<string, unknown>>()
      .notNull(),
    calculatedAt: text("calculatedAt").notNull(),
  },
  table => [
    foreignKey({
      name: "cost_calculations_org_item_fk",
      columns: [table.organizationId, table.itemId],
      foreignColumns: [costItems.organizationId, costItems.id],
    }).onDelete("restrict"),
    foreignKey({
      name: "cost_calculations_org_structure_fk",
      columns: [table.organizationId, table.structureId],
      foreignColumns: [costStructures.organizationId, costStructures.id],
    }).onDelete("restrict"),
    index("cost_calculations_org_item_date_idx").on(
      table.organizationId,
      table.itemId,
      table.calculatedAt
    ),
  ]
);

export const costingGammaSettings = pgTable(
  "costing_gamma_settings",
  {
    id: varchar("id", { length: 32 }).primaryKey(),
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    active: boolean("active").default(false).notNull(),
    percentage: decimal("percentage", {
      precision: 8,
      scale: 4,
      mode: "string",
    })
      .default("1.2000")
      .notNull(),
    createdAt: text("createdAt").notNull(),
    updatedAt: text("updatedAt").notNull(),
  },
  table => [
    check(
      "costing_gamma_percentage_nonnegative_check",
      sql`${table.percentage} >= 0`
    ),
    unique("costing_gamma_settings_org_unique").on(table.organizationId),
  ]
);

export const costingGammaGroups = pgTable(
  "costing_gamma_groups",
  {
    organizationId: varchar("organizationId", { length: 32 })
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    groupId: varchar("groupId", { length: 32 }).notNull(),
    createdAt: text("createdAt").notNull(),
  },
  table => [
    unique("costing_gamma_groups_org_group_unique").on(
      table.organizationId,
      table.groupId
    ),
    foreignKey({
      name: "costing_gamma_groups_org_group_fk",
      columns: [table.organizationId, table.groupId],
      foreignColumns: [costGroups.organizationId, costGroups.id],
    }).onDelete("cascade"),
  ]
);
