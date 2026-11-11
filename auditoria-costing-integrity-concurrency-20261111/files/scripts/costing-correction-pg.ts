import { and, eq, sql } from "drizzle-orm";
import { getDb } from "../server/db";
import {
  costCalculations,
  costStructureLines,
  costStructures,
} from "../drizzle/pg/schema.costing";
import {
  calculateAndCreateCostingSnapshot,
  createCostStructure,
  createCostStructureLine,
  deleteCostStructureLine,
  getCostStructure,
  listCostStructures,
  listCostingSnapshots,
  publishCostStructure,
  updateCostStructure,
  updateCostStructureLine,
} from "../server/db/costing";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function expectReject(work: () => Promise<unknown>, message: string) {
  let rejected = false;
  try {
    await work();
  } catch (error) {
    rejected = true;
    assert(
      String(error).includes(message),
      `expected ${message}, got ${String(error)}`
    );
  }
  assert(rejected, `expected rejection: ${message}`);
}

const db = await getDb();
if (!db) throw new Error("database unavailable");

const activeSnapshot = await calculateAndCreateCostingSnapshot({
  organizationId: "org-correction-a",
  targetItemId: "target-a",
  structureId: "active-a",
});
assert(
  activeSnapshot.snapshot.structureId === "active-a",
  "snapshot did not record ACTIVE structure"
);
assert(
  activeSnapshot.snapshot.result.exactUnitCost === "50.6",
  "unexpected exact cost"
);
assert(
  activeSnapshot.snapshot.gamma.adjustmentUnitCost === "0.6",
  "unexpected gamma adjustment"
);

for (const statusId of ["draft-a", "superseded-a", "inactive-a"]) {
  await expectReject(
    () =>
      calculateAndCreateCostingSnapshot({
        organizationId: "org-correction-a",
        targetItemId: "target-a",
        structureId: statusId,
      }),
    "Snapshots oficiais exigem uma estrutura ACTIVE"
  );
}
await expectReject(
  () =>
    calculateAndCreateCostingSnapshot({
      organizationId: "org-correction-a",
      targetItemId: "source-b",
    }),
  "Item não encontrado na organização"
);

const draft = await createCostStructure({
  organizationId: "org-correction-a",
  itemId: "target-a",
  outputQuantity: "2",
});
const newLine = await createCostStructureLine({
  organizationId: "org-correction-a",
  structureId: draft.id,
  componentItemId: "source-a",
  quantity: "1.250",
  quantityUnit: "un",
  position: 1,
});
await updateCostStructureLine({
  organizationId: "org-correction-a",
  lineId: newLine.id,
  quantity: "1.500",
  notes: "artificial correction fixture",
});
await updateCostStructure({
  organizationId: "org-correction-a",
  structureId: draft.id,
  outputQuantity: "3",
});
const editedDraft = await getCostStructure("org-correction-a", draft.id);
assert(editedDraft.status === "DRAFT", "edited structure left DRAFT");
assert(
  Number(editedDraft.outputQuantity) === 3,
  "draft output was not updated"
);
assert(
  Number(editedDraft.lines[0]?.quantity) === 1.5,
  "draft line was not updated"
);
await deleteCostStructureLine({
  organizationId: "org-correction-a",
  lineId: newLine.id,
});
const emptyDraft = await getCostStructure("org-correction-a", draft.id);
assert(emptyDraft.lines.length === 0, "draft line was not deleted");
await createCostStructureLine({
  organizationId: "org-correction-a",
  structureId: draft.id,
  componentItemId: "source-a",
  quantity: "1",
  quantityUnit: "un",
});

await expectReject(
  () =>
    updateCostStructureLine({
      organizationId: "org-correction-a",
      lineId: "active-line-a",
      quantity: "2",
    }),
  "Somente uma estrutura DRAFT pode ser alterada"
);
await expectReject(
  () =>
    deleteCostStructureLine({
      organizationId: "org-correction-a",
      lineId: "active-line-a",
    }),
  "Somente uma estrutura DRAFT pode ser alterada"
);

const published = await publishCostStructure("org-correction-a", draft.id);
assert(published.published.status === "ACTIVE", "DRAFT was not published");
await expectReject(
  () =>
    updateCostStructure({
      organizationId: "org-correction-a",
      structureId: draft.id,
      outputQuantity: "4",
    }),
  "Somente uma estrutura DRAFT pode ser alterada"
);

const historySnapshots = [activeSnapshot.id];
for (let i = 0; i < 2; i += 1) {
  await new Promise(resolve => setTimeout(resolve, 3));
  historySnapshots.push(
    (
      await calculateAndCreateCostingSnapshot({
        organizationId: "org-correction-a",
        targetItemId: "target-a",
        structureId: draft.id,
      })
    ).id
  );
}
const history = await listCostingSnapshots("org-correction-a", "target-a", 2);
assert(history.length === 2, "history limit was not applied");
assert(
  historySnapshots.includes(history[0]!.id),
  "history did not return stored snapshots"
);
for (let i = 1; i < history.length; i += 1) {
  assert(
    history[i - 1]!.calculatedAt >= history[i]!.calculatedAt,
    "history is not newest first"
  );
}

const tenConcurrentDrafts = await Promise.all(
  Array.from({ length: 10 }, () =>
    createCostStructure({
      organizationId: "org-correction-a",
      itemId: "target-a",
    })
  )
);
const tenVersions = tenConcurrentDrafts
  .map(structure => structure.version)
  .sort((left, right) => left - right);
assert(new Set(tenVersions).size === 10, "same-item versions are not unique");
assert(
  tenVersions.every(
    (version, index) => index === 0 || version === tenVersions[index - 1]! + 1
  ),
  "same-item versions are not sequential"
);

const scopedConcurrentDrafts = await Promise.all([
  ...Array.from({ length: 5 }, () =>
    createCostStructure({
      organizationId: "org-correction-a",
      itemId: "target-c",
    })
  ),
  ...Array.from({ length: 5 }, () =>
    createCostStructure({
      organizationId: "org-correction-b",
      itemId: "target-b",
    })
  ),
]);
assert(
  scopedConcurrentDrafts.length === 10,
  "cross-scope creation count mismatch"
);
assert(
  new Set(
    scopedConcurrentDrafts.map(
      structure => `${structure.organizationId}:${structure.itemId}`
    )
  ).size === 2,
  "cross-scope creation lost tenant or item isolation"
);

const concurrentDrafts = [
  await createCostStructure({
    organizationId: "org-correction-a",
    itemId: "target-a",
  }),
  await createCostStructure({
    organizationId: "org-correction-a",
    itemId: "target-a",
  }),
];
const concurrent = await Promise.allSettled(
  concurrentDrafts.map(structure =>
    publishCostStructure("org-correction-a", structure.id)
  )
);
assert(
  concurrent.filter(result => result.status === "fulfilled").length >= 1,
  "concurrent publication failed entirely"
);
const finalTargetStructures = await listCostStructures(
  "org-correction-a",
  "target-a"
);
assert(
  finalTargetStructures.filter(structure => structure.status === "ACTIVE")
    .length === 1,
  "final target has more than one ACTIVE structure"
);
const concurrentRows = finalTargetStructures.filter(structure =>
  concurrentDrafts.some(draft => draft.id === structure.id)
);
assert(
  concurrentRows.every(structure =>
    ["ACTIVE", "SUPERSEDED", "DRAFT"].includes(structure.status)
  ),
  "concurrent publication left an invalid structure state"
);

try {
  await db.transaction(async tx => {
    await tx.execute(sql`set transaction isolation level repeatable read`);
    await tx
      .update(costStructures)
      .set({ outputQuantity: "9", updatedAt: Date.now().toString() })
      .where(
        and(
          eq(costStructures.organizationId, "org-correction-a"),
          eq(costStructures.id, "draft-a")
        )
      );
    throw new Error("rollback marker");
  });
} catch (error) {
  assert(
    String(error).includes("rollback marker"),
    "unexpected rollback error"
  );
}
const [rolledBack] = await db
  .select({ outputQuantity: costStructures.outputQuantity })
  .from(costStructures)
  .where(
    and(
      eq(costStructures.organizationId, "org-correction-a"),
      eq(costStructures.id, "draft-a")
    )
  )
  .limit(1);
assert(
  Number(rolledBack?.outputQuantity) === 1,
  "transaction rollback did not restore the draft"
);

const [snapshotCount] = await db
  .select({ count: sql<number>`count(*)` })
  .from(costCalculations)
  .where(eq(costCalculations.organizationId, "org-correction-a"));
console.log(
  JSON.stringify({
    activeStructure: activeSnapshot.snapshot.structureId,
    exactUnitCost: activeSnapshot.snapshot.result.exactUnitCost,
    gamma: activeSnapshot.snapshot.gamma.adjustmentUnitCost,
    historyReturned: history.length,
    snapshotsPersisted: Number(snapshotCount?.count ?? 0),
    draftLifecycle: "create-line-update-line-delete-line-publish",
    tenConcurrentVersions: tenVersions,
    scopedConcurrentCreations: scopedConcurrentDrafts.length,
    concurrentPublication: concurrent.map(result => result.status),
    finalActiveForTarget: finalTargetStructures
      .filter(structure => structure.status === "ACTIVE")
      .map(structure => structure.id),
    rollback: "ok",
  })
);
process.exit(0);
