import { and, asc, desc, eq, max, sql } from "drizzle-orm";
import { nanoid } from "nanoid";
import {
  costCalculations,
  costItems,
  costStructureLines,
  costStructures,
  costStructureVersionCounters,
  costingGammaGroups,
  costingGammaSettings,
} from "../../drizzle/pg/schema.costing";
import { getDb } from "../db";
import {
  createCostingCalculationSnapshot,
  type CostingCalculationSnapshot,
  type CostingGammaSnapshot,
} from "../domain/costing/snapshot";
import {
  calculateItemCostWithGamma,
  type CostingItem,
  type CostingResult,
} from "../domain/costing/engine";

const DECIMAL_UP_TO_THREE_PLACES = /^\d+(?:\.\d{1,3})?$/;

async function requireDb() {
  const db = await getDb();
  if (!db) throw new Error("Banco de dados indisponível");
  return db;
}

function requirePositiveDecimal(value: string, field: string) {
  if (!DECIMAL_UP_TO_THREE_PLACES.test(value) || Number(value) <= 0) {
    throw new Error(
      `${field} deve ser um número positivo com até três casas decimais`
    );
  }
}

function nowText() {
  return Date.now().toString();
}

async function assertDraftStructure(
  tx: any,
  organizationId: string,
  structureId: string
) {
  const [structure] = await tx
    .select()
    .from(costStructures)
    .where(
      and(
        eq(costStructures.organizationId, organizationId),
        eq(costStructures.id, structureId)
      )
    )
    .for("update")
    .limit(1);
  if (!structure) throw new Error("Estrutura não encontrada");
  if (structure.status !== "DRAFT") {
    throw new Error("Somente uma estrutura DRAFT pode ser alterada");
  }
  return structure;
}

export async function getCostStructure(
  organizationId: string,
  structureId: string
) {
  const db = await requireDb();
  const [structure] = await db
    .select()
    .from(costStructures)
    .where(
      and(
        eq(costStructures.organizationId, organizationId),
        eq(costStructures.id, structureId)
      )
    )
    .limit(1);
  if (!structure) throw new Error("Estrutura não encontrada");
  const lines = await db
    .select()
    .from(costStructureLines)
    .where(
      and(
        eq(costStructureLines.organizationId, organizationId),
        eq(costStructureLines.structureId, structureId)
      )
    )
    .orderBy(asc(costStructureLines.position), asc(costStructureLines.id));
  return { ...structure, lines };
}

export async function listCostStructures(
  organizationId: string,
  itemId?: string
) {
  const db = await requireDb();
  const predicates = [eq(costStructures.organizationId, organizationId)];
  if (itemId) predicates.push(eq(costStructures.itemId, itemId));
  return db
    .select()
    .from(costStructures)
    .where(and(...predicates))
    .orderBy(desc(costStructures.version), asc(costStructures.id));
}

function isTransientVersionAllocationConflict(error: unknown) {
  let current: unknown = error;
  for (let attempt = 0; attempt < 4 && current; attempt += 1) {
    if (
      typeof current === "object" &&
      current !== null &&
      "code" in current &&
      ((current as { code?: unknown }).code === "40001" ||
        (current as { code?: unknown }).code === "40P01")
    ) {
      return true;
    }
    current =
      typeof current === "object" && current !== null && "cause" in current
        ? (current as { cause?: unknown }).cause
        : undefined;
  }
  return false;
}

async function createCostStructureOnce(
  db: Awaited<ReturnType<typeof requireDb>>,
  input: { organizationId: string; itemId: string; outputQuantity?: string }
) {
  return db.transaction(async tx => {
    // This transaction only validates the item and allocates a version. The
    // atomic counter is the consistency boundary; READ COMMITTED lets a
    // waiting ON CONFLICT update observe the committed counter increment,
    // whereas REPEATABLE READ turns the same legitimate wait into 40001.
    await tx.execute(sql`set transaction isolation level read committed`);
    const [item] = await tx
      .select({ id: costItems.id })
      .from(costItems)
      .where(
        and(
          eq(costItems.organizationId, input.organizationId),
          eq(costItems.id, input.itemId)
        )
      )
      .for("update")
      .limit(1);
    if (!item) throw new Error("Item não encontrado na organização");

    const [versionRow] = await tx
      .select({ maxVersion: max(costStructures.version) })
      .from(costStructures)
      .where(
        and(
          eq(costStructures.organizationId, input.organizationId),
          eq(costStructures.itemId, input.itemId)
        )
      );
    const [counter] = await tx
      .insert(costStructureVersionCounters)
      .values({
        organizationId: input.organizationId,
        itemId: input.itemId,
        nextVersion: Number(versionRow?.maxVersion ?? 0) + 1,
      })
      .onConflictDoUpdate({
        target: [
          costStructureVersionCounters.organizationId,
          costStructureVersionCounters.itemId,
        ],
        set: {
          nextVersion: sql`${costStructureVersionCounters.nextVersion} + 1`,
        },
      })
      .returning({ version: costStructureVersionCounters.nextVersion });
    const version = Number(counter?.version);
    if (!Number.isInteger(version) || version < 1) {
      throw new Error("Não foi possível reservar uma versão de estrutura");
    }
    const id = nanoid(20);
    const timestamp = nowText();
    const [structure] = await tx
      .insert(costStructures)
      .values({
        id,
        organizationId: input.organizationId,
        itemId: input.itemId,
        version,
        status: "DRAFT",
        outputQuantity: input.outputQuantity ?? "1",
        createdAt: timestamp,
        updatedAt: timestamp,
      })
      .returning();
    return { ...structure, lines: [] };
  });
}

export async function createCostStructure(input: {
  organizationId: string;
  itemId: string;
  outputQuantity?: string;
}) {
  const outputQuantity = input.outputQuantity ?? "1";
  requirePositiveDecimal(outputQuantity, "outputQuantity");
  const db = await requireDb();
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return await createCostStructureOnce(db, { ...input, outputQuantity });
    } catch (error) {
      if (!isTransientVersionAllocationConflict(error) || attempt === 3) {
        throw error;
      }
    }
  }
  throw new Error("Não foi possível reservar uma versão de estrutura");
}

export async function updateCostStructure(input: {
  organizationId: string;
  structureId: string;
  outputQuantity: string;
}) {
  requirePositiveDecimal(input.outputQuantity, "outputQuantity");
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    await assertDraftStructure(tx, input.organizationId, input.structureId);
    const [structure] = await tx
      .update(costStructures)
      .set({ outputQuantity: input.outputQuantity, updatedAt: nowText() })
      .where(
        and(
          eq(costStructures.organizationId, input.organizationId),
          eq(costStructures.id, input.structureId),
          eq(costStructures.status, "DRAFT")
        )
      )
      .returning();
    if (!structure) throw new Error("Estrutura DRAFT não pôde ser atualizada");
    return getCostStructureFromTransaction(
      tx,
      input.organizationId,
      structure.id
    );
  });
}

async function getCostStructureFromTransaction(
  tx: any,
  organizationId: string,
  structureId: string
) {
  const [structure] = await tx
    .select()
    .from(costStructures)
    .where(
      and(
        eq(costStructures.organizationId, organizationId),
        eq(costStructures.id, structureId)
      )
    )
    .limit(1);
  if (!structure) throw new Error("Estrutura não encontrada");
  const lines = await tx
    .select()
    .from(costStructureLines)
    .where(
      and(
        eq(costStructureLines.organizationId, organizationId),
        eq(costStructureLines.structureId, structureId)
      )
    )
    .orderBy(asc(costStructureLines.position), asc(costStructureLines.id));
  return { ...structure, lines };
}

export async function createCostStructureLine(input: {
  organizationId: string;
  structureId: string;
  componentItemId: string;
  quantity: string;
  quantityUnit: string;
  position?: number;
  notes?: string | null;
}) {
  requirePositiveDecimal(input.quantity, "quantity");
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    await assertDraftStructure(tx, input.organizationId, input.structureId);
    const [component] = await tx
      .select({ id: costItems.id })
      .from(costItems)
      .where(
        and(
          eq(costItems.organizationId, input.organizationId),
          eq(costItems.id, input.componentItemId)
        )
      )
      .limit(1);
    if (!component) throw new Error("Componente não encontrado na organização");
    const timestamp = nowText();
    const [line] = await tx
      .insert(costStructureLines)
      .values({
        id: nanoid(20),
        organizationId: input.organizationId,
        structureId: input.structureId,
        componentItemId: input.componentItemId,
        quantity: input.quantity,
        quantityUnit: input.quantityUnit,
        position: input.position ?? 0,
        notes: input.notes ?? null,
        createdAt: timestamp,
        updatedAt: timestamp,
      })
      .returning();
    return line;
  });
}

export async function updateCostStructureLine(input: {
  organizationId: string;
  lineId: string;
  componentItemId?: string;
  quantity?: string;
  quantityUnit?: string;
  position?: number;
  notes?: string | null;
}) {
  if (input.quantity !== undefined)
    requirePositiveDecimal(input.quantity, "quantity");
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    const [line] = await tx
      .select()
      .from(costStructureLines)
      .where(
        and(
          eq(costStructureLines.organizationId, input.organizationId),
          eq(costStructureLines.id, input.lineId)
        )
      )
      .for("update")
      .limit(1);
    if (!line) throw new Error("Linha não encontrada");
    await assertDraftStructure(tx, input.organizationId, line.structureId);
    if (
      input.componentItemId &&
      input.componentItemId !== line.componentItemId
    ) {
      const [component] = await tx
        .select({ id: costItems.id })
        .from(costItems)
        .where(
          and(
            eq(costItems.organizationId, input.organizationId),
            eq(costItems.id, input.componentItemId)
          )
        )
        .limit(1);
      if (!component)
        throw new Error("Componente não encontrado na organização");
    }
    const [updated] = await tx
      .update(costStructureLines)
      .set({
        ...(input.componentItemId === undefined
          ? {}
          : { componentItemId: input.componentItemId }),
        ...(input.quantity === undefined ? {} : { quantity: input.quantity }),
        ...(input.quantityUnit === undefined
          ? {}
          : { quantityUnit: input.quantityUnit }),
        ...(input.position === undefined ? {} : { position: input.position }),
        ...(input.notes === undefined ? {} : { notes: input.notes }),
        updatedAt: nowText(),
      })
      .where(
        and(
          eq(costStructureLines.organizationId, input.organizationId),
          eq(costStructureLines.id, input.lineId)
        )
      )
      .returning();
    if (!updated) throw new Error("Linha não pôde ser atualizada");
    return updated;
  });
}

export async function deleteCostStructureLine(input: {
  organizationId: string;
  lineId: string;
}) {
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    const [line] = await tx
      .select()
      .from(costStructureLines)
      .where(
        and(
          eq(costStructureLines.organizationId, input.organizationId),
          eq(costStructureLines.id, input.lineId)
        )
      )
      .for("update")
      .limit(1);
    if (!line) throw new Error("Linha não encontrada");
    await assertDraftStructure(tx, input.organizationId, line.structureId);
    const [deleted] = await tx
      .delete(costStructureLines)
      .where(
        and(
          eq(costStructureLines.organizationId, input.organizationId),
          eq(costStructureLines.id, input.lineId)
        )
      )
      .returning({ id: costStructureLines.id });
    return deleted;
  });
}

export async function calculateAndCreateCostingSnapshot(input: {
  organizationId: string;
  targetItemId: string;
  structureId?: string | null;
}) {
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    const itemRows = await tx
      .select()
      .from(costItems)
      .where(eq(costItems.organizationId, input.organizationId));
    const target = itemRows.find(row => row.id === input.targetItemId);
    if (!target) throw new Error("Item não encontrado na organização");

    const structureRows = await tx
      .select()
      .from(costStructures)
      .where(eq(costStructures.organizationId, input.organizationId));
    const requestedStructure = input.structureId
      ? structureRows.find(row => row.id === input.structureId)
      : undefined;
    if (input.structureId && !requestedStructure)
      throw new Error("Estrutura não encontrada na organização");
    if (requestedStructure && requestedStructure.itemId !== input.targetItemId)
      throw new Error("A estrutura não pertence ao item-alvo");
    if (requestedStructure && requestedStructure.status !== "ACTIVE")
      throw new Error("Snapshots oficiais exigem uma estrutura ACTIVE");

    const lineRows = await tx
      .select()
      .from(costStructureLines)
      .where(eq(costStructureLines.organizationId, input.organizationId));
    const activeByItem = new Map(
      structureRows
        .filter(row => row.status === "ACTIVE")
        .map(row => [row.itemId, row])
    );
    if (requestedStructure) activeByItem.set(target.id, requestedStructure);

    const sourceItems: CostingItem[] = itemRows.map(row => {
      const structure =
        row.itemType === "COMPOSITE" ? activeByItem.get(row.id) : undefined;
      return {
        id: row.id,
        type: row.itemType,
        active: row.active,
        unit: row.referenceUnit,
        groupId: row.groupId,
        manualUnitCost: row.manualUnitCost,
        outputQuantity: structure?.outputQuantity ?? "1",
        structure: structure
          ? lineRows
              .filter(line => line.structureId === structure.id)
              .sort((left, right) => left.position - right.position)
              .map(line => ({
                componentItemId: line.componentItemId,
                quantity: line.quantity,
                quantityUnit: line.quantityUnit,
              }))
          : undefined,
      };
    });
    const [settings] = await tx
      .select()
      .from(costingGammaSettings)
      .where(eq(costingGammaSettings.organizationId, input.organizationId))
      .limit(1);
    const groupRows = await tx
      .select({ groupId: costingGammaGroups.groupId })
      .from(costingGammaGroups)
      .where(eq(costingGammaGroups.organizationId, input.organizationId));
    const gammaResult = calculateItemCostWithGamma(sourceItems, target.id, {
      active: settings?.active ?? false,
      percentage: settings?.percentage ?? "1.2000",
      selectedGroupIds: groupRows.map(row => row.groupId),
    });
    const calculatedAt = new Date().toISOString();
    const snapshot = createCostingCalculationSnapshot({
      organizationId: input.organizationId,
      targetItemId: target.id,
      structureId:
        requestedStructure?.id ?? activeByItem.get(target.id)?.id ?? null,
      sourceItems,
      result: gammaResult.result,
      gamma: {
        active: settings?.active ?? false,
        percentage: settings?.percentage ?? "1.2000",
        selectedGroupIds: groupRows.map(row => row.groupId),
        baseBatchCost: gammaResult.baseBatchCost,
        adjustmentBatchCost: gammaResult.adjustmentBatchCost,
        adjustmentUnitCost: gammaResult.adjustmentUnitCost,
        baseLines: gammaResult.baseLines,
      },
      calculatedAt,
    });
    const id = nanoid(20);
    await tx.insert(costCalculations).values({
      id,
      organizationId: input.organizationId,
      itemId: input.targetItemId,
      structureId:
        requestedStructure?.id ?? activeByItem.get(target.id)?.id ?? null,
      exactCostNumerator: snapshot.exactUnitCost.numerator,
      exactCostDenominator: snapshot.exactUnitCost.denominator,
      displayUnitCost: snapshot.result.displayUnitCost,
      snapshotVersion: snapshot.snapshotVersion,
      calculationSnapshot: snapshot as unknown as Record<string, unknown>,
      calculatedAt: snapshot.calculatedAt,
    });
    return { id, snapshot };
  });
}

export async function listCostingSnapshots(
  organizationId: string,
  itemId: string,
  limit = 50
) {
  const db = await requireDb();
  return db
    .select()
    .from(costCalculations)
    .where(
      and(
        eq(costCalculations.organizationId, organizationId),
        eq(costCalculations.itemId, itemId)
      )
    )
    .orderBy(desc(costCalculations.calculatedAt), desc(costCalculations.id))
    .limit(Math.min(Math.max(Math.trunc(limit), 1), 100));
}

export async function publishCostStructure(
  organizationId: string,
  targetStructureId: string
) {
  const db = await requireDb();
  return db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    const [target] = await tx
      .select()
      .from(costStructures)
      .where(
        and(
          eq(costStructures.organizationId, organizationId),
          eq(costStructures.id, targetStructureId)
        )
      )
      .for("update")
      .limit(1);
    if (!target) throw new Error("Estrutura não encontrada");
    if (target.status !== "DRAFT")
      throw new Error("Somente uma estrutura DRAFT pode ser publicada");
    const active = await tx
      .select({ id: costStructures.id })
      .from(costStructures)
      .where(
        and(
          eq(costStructures.organizationId, organizationId),
          eq(costStructures.itemId, target.itemId),
          eq(costStructures.status, "ACTIVE")
        )
      )
      .for("update");
    await tx
      .update(costStructures)
      .set({ status: "SUPERSEDED", updatedAt: nowText() })
      .where(
        and(
          eq(costStructures.organizationId, organizationId),
          eq(costStructures.itemId, target.itemId),
          eq(costStructures.status, "ACTIVE")
        )
      );
    const [published] = await tx
      .update(costStructures)
      .set({ status: "ACTIVE", updatedAt: nowText() })
      .where(
        and(
          eq(costStructures.organizationId, organizationId),
          eq(costStructures.id, targetStructureId),
          eq(costStructures.status, "DRAFT")
        )
      )
      .returning();
    if (!published) throw new Error("Estrutura não pôde ser publicada");
    return { published, supersededStructureIds: active.map(row => row.id) };
  });
}

export { costStructureLines };
