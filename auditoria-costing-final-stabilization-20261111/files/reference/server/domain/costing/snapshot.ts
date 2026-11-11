import type {
  CostingGammaBaseLine,
  CostingItem,
  CostingResult,
} from "./engine";

export const COSTING_SNAPSHOT_VERSION = 1 as const;
export const COSTING_ENGINE_VERSION = "costing-engine-v1" as const;

export interface CostingGammaSnapshot {
  active: boolean;
  percentage: string;
  /** IDs of the groups explicitly selected when this calculation was made. */
  selectedGroupIds: readonly string[];
  baseBatchCost?: string;
  adjustmentBatchCost?: string;
  adjustmentUnitCost?: string;
  baseLines?: readonly CostingGammaBaseLine[];
}

export interface CostingCalculationSnapshot {
  snapshotVersion: typeof COSTING_SNAPSHOT_VERSION;
  engineVersion: typeof COSTING_ENGINE_VERSION;
  calculatedAt: string;
  organizationId: string;
  targetItemId: string;
  structureId: string | null;
  /** Full input graph at calculation time, including every referenced simple/composite item. */
  sourceItems: readonly CostingItem[];
  gamma: CostingGammaSnapshot;
  result: CostingResult;
  exactUnitCost: { numerator: string; denominator: string };
}

/**
 * Build a self-contained, JSON-serializable audit snapshot. The caller must
 * persist this payload atomically with the calculation row. It intentionally
 * copies nested structure lines so later caller mutation cannot alter the
 * in-memory snapshot before persistence.
 */
export function createCostingCalculationSnapshot(input: {
  organizationId: string;
  targetItemId: string;
  structureId?: string | null;
  sourceItems: readonly CostingItem[];
  gamma: CostingGammaSnapshot;
  result: CostingResult;
  calculatedAt: string;
}): CostingCalculationSnapshot {
  if (!input.organizationId.trim() || !input.targetItemId.trim()) {
    throw new Error(
      "Organization and target item are required for a costing snapshot."
    );
  }
  if (!Number.isFinite(Date.parse(input.calculatedAt))) {
    throw new Error("A valid calculation timestamp is required.");
  }
  const exact = input.result.exactUnitCost;
  let numerator: string;
  let denominator: string;
  if (/^\d+\/\d+$/.test(exact)) {
    [numerator, denominator] = exact.split("/");
  } else if (/^\d+(?:\.\d+)?$/.test(exact)) {
    const [whole, decimal = ""] = exact.split(".");
    numerator = (whole + decimal).replace(/^0+(?=\d)/, "");
    denominator = "1" + "0".repeat(decimal.length);
  } else {
    throw new Error("The calculation engine returned an invalid exact cost.");
  }
  let n = BigInt(numerator);
  let d = BigInt(denominator);
  if (n < 0n || d <= 0n)
    throw new Error(
      "The exact cost must be non-negative with a positive denominator."
    );
  const gcd = (left: bigint, right: bigint): bigint => {
    while (right !== 0n) [left, right] = [right, left % right];
    return left;
  };
  const divisor = gcd(n, d);
  n /= divisor;
  d /= divisor;
  numerator = n.toString();
  denominator = d.toString();

  return {
    snapshotVersion: COSTING_SNAPSHOT_VERSION,
    engineVersion: COSTING_ENGINE_VERSION,
    calculatedAt: input.calculatedAt,
    organizationId: input.organizationId,
    targetItemId: input.targetItemId,
    structureId: input.structureId ?? null,
    sourceItems: input.sourceItems.map(item => ({
      ...item,
      structure: item.structure?.map(line => ({ ...line })),
    })),
    gamma: {
      active: input.gamma.active,
      percentage: input.gamma.percentage,
      selectedGroupIds: [...input.gamma.selectedGroupIds],
      ...(input.gamma.baseBatchCost === undefined
        ? {}
        : { baseBatchCost: input.gamma.baseBatchCost }),
      ...(input.gamma.adjustmentBatchCost === undefined
        ? {}
        : { adjustmentBatchCost: input.gamma.adjustmentBatchCost }),
      ...(input.gamma.adjustmentUnitCost === undefined
        ? {}
        : { adjustmentUnitCost: input.gamma.adjustmentUnitCost }),
      ...(input.gamma.baseLines === undefined
        ? {}
        : { baseLines: input.gamma.baseLines.map(line => ({ ...line })) }),
    },
    result: {
      ...input.result,
      lines: input.result.lines.map(line => ({ ...line })),
    },
    exactUnitCost: { numerator, denominator },
  };
}
