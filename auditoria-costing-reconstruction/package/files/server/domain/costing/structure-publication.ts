export type CostStructureStatus =
  | "DRAFT"
  | "ACTIVE"
  | "SUPERSEDED"
  | "INACTIVE";

export interface CostStructureVersionState {
  id: string;
  itemId: string;
  version: number;
  status: CostStructureStatus;
}

export interface StructurePublicationPlan {
  activateStructureId: string;
  supersedeStructureIds: string[];
  /** Callers must execute all status updates in one database transaction. */
}

/**
 * Pure validation/planning for publication. It does not write to the database.
 * The persistence adapter must lock the item/version rows, re-read statuses,
 * apply this plan atomically, and rely on the partial unique index as the final
 * concurrency guard.
 */
export function planStructurePublication(
  structures: readonly CostStructureVersionState[],
  targetStructureId: string
): StructurePublicationPlan {
  const target = structures.find(
    structure => structure.id === targetStructureId
  );
  if (!target) throw new Error("Structure version not found.");
  if (target.status !== "DRAFT")
    throw new Error("Only a DRAFT structure can be published.");

  const sameItem = structures.filter(
    structure => structure.itemId === target.itemId
  );
  const duplicateVersions = new Set<number>();
  for (const structure of sameItem) {
    if (duplicateVersions.has(structure.version))
      throw new Error("Duplicate structure version number.");
    duplicateVersions.add(structure.version);
  }
  const active = sameItem.filter(structure => structure.status === "ACTIVE");
  if (active.length > 1)
    throw new Error(
      "Data integrity error: more than one ACTIVE structure exists for this item."
    );

  return {
    activateStructureId: target.id,
    supersedeStructureIds: active.map(structure => structure.id),
  };
}
