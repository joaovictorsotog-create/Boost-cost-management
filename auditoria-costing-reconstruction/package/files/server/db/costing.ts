import { and, asc, eq } from "drizzle-orm";
import { nanoid } from "nanoid";
import {
  costCalculations,
  costItems,
  costStructureLines,
  costStructures,
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

async function requireDb() {
  const db = await getDb();
  if (!db) throw new Error("Banco de dados indisponível");
  return db;
}

async function persistCostingSnapshot(input: {
  organizationId: string;
  targetItemId: string;
  structureId?: string | null;
  sourceItems: readonly CostingItem[];
  gamma: CostingGammaSnapshot;
  result: CostingResult;
  calculatedAt: string;
}): Promise<{ id: string; snapshot: CostingCalculationSnapshot }> {
  const db = await requireDb();
  const snapshot = createCostingCalculationSnapshot(input);
  const id = nanoid(20);
  await db.transaction(async tx => {
    await tx.insert(costCalculations).values({
      id,
      organizationId: input.organizationId,
      itemId: input.targetItemId,
      structureId: input.structureId ?? null,
      exactCostNumerator: snapshot.exactUnitCost.numerator,
      exactCostDenominator: snapshot.exactUnitCost.denominator,
      displayUnitCost: snapshot.result.displayUnitCost,
      snapshotVersion: snapshot.snapshotVersion,
      calculationSnapshot: snapshot as unknown as Record<string, unknown>,
      calculatedAt: snapshot.calculatedAt,
    });
  });
  return { id, snapshot };
}

export async function calculateAndCreateCostingSnapshot(input: {
  organizationId: string;
  targetItemId: string;
  structureId?: string | null;
}) {
  const db = await requireDb();
  const itemRows = await db
    .select()
    .from(costItems)
    .where(eq(costItems.organizationId, input.organizationId));
  const target = itemRows.find(row => row.id === input.targetItemId);
  if (!target) throw new Error("Item não encontrado na organização");

  const structureRows = await db
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

  const lineRows = await db
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
  const [settings] = await db
    .select()
    .from(costingGammaSettings)
    .where(eq(costingGammaSettings.organizationId, input.organizationId))
    .limit(1);
  const groupRows = await db
    .select({ groupId: costingGammaGroups.groupId })
    .from(costingGammaGroups)
    .where(eq(costingGammaGroups.organizationId, input.organizationId));
  const gammaResult = calculateItemCostWithGamma(sourceItems, target.id, {
    active: settings?.active ?? false,
    percentage: settings?.percentage ?? "1.2000",
    selectedGroupIds: groupRows.map(row => row.groupId),
  });
  const calculatedAt = new Date().toISOString();
  return persistCostingSnapshot({
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
    .orderBy(asc(costCalculations.calculatedAt))
    .limit(Math.min(limit, 100));
}

export async function publishCostStructure(
  organizationId: string,
  targetStructureId: string
) {
  const db = await requireDb();
  return db.transaction(async tx => {
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
      .set({ status: "SUPERSEDED", updatedAt: Date.now().toString() })
      .where(
        and(
          eq(costStructures.organizationId, organizationId),
          eq(costStructures.itemId, target.itemId),
          eq(costStructures.status, "ACTIVE")
        )
      );
    const [published] = await tx
      .update(costStructures)
      .set({ status: "ACTIVE", updatedAt: Date.now().toString() })
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

export async function updateCostStructureLine(): Promise<never> {
  throw new Error(
    "Estruturas publicadas são imutáveis; crie uma nova versão DRAFT"
  );
}

export { costStructureLines };
