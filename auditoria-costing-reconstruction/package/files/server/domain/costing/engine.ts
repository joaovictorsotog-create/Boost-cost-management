/**
 * Pure costing domain engine. User-entered decimals have at most three places.
 * Internal calculations use exact rational arithmetic; only final unit cost is rounded.
 * No database, framework, floating-point money arithmetic, or commercial pricing.
 */
export type CostingItemType = "SIMPLE" | "COMPOSITE";
export interface CostingStructureLine {
  componentItemId: string;
  quantity: string;
  /** Unit used to enter this consumption; defaults to the component reference unit for legacy callers. */ quantityUnit?: string;
}
export interface CostingItem {
  id: string;
  type: CostingItemType;
  active: boolean;
  unit: string;
  groupId?: string | null;
  /** Number of finished units represented by the composite structure; defaults to 1. */
  outputQuantity?: string;
  manualUnitCost?: string | null;
  structure?: readonly CostingStructureLine[];
}
export interface CostingLineResult {
  componentItemId: string;
  quantity: string;
  enteredUnit: string;
  referenceUnit: string;
  conversionFactor: string;
  componentUnitCost: string;
  batchLineCost: string;
}
export interface CostingResult {
  itemId: string;
  unit: string;
  /** Exact decimal, or an exact numerator/denominator string when the value is recurring. */
  exactUnitCost: string;
  /** Final unit cost rounded to at most three places by the fourth decimal digit (0–5 down, 6–9 up). */
  displayUnitCost: string;
  lines: CostingLineResult[];
}
export interface CostingGammaBaseLine {
  itemId: string;
  groupId: string;
  quantity: string;
  unit: string;
  unitCost: string;
  batchCost: string;
}
export interface CostingGammaInput {
  active: boolean;
  percentage?: string;
  selectedGroupIds: readonly string[];
}
export interface CostingGammaResult {
  baseBatchCost: string;
  adjustmentBatchCost: string;
  adjustmentUnitCost: string;
  baseLines: CostingGammaBaseLine[];
  result: CostingResult;
}
export type CostingErrorCode =
  | "DUPLICATE_ITEM_ID"
  | "ITEM_NOT_FOUND"
  | "ITEM_INACTIVE"
  | "INVALID_ITEM_TYPE"
  | "INVALID_UNIT"
  | "INVALID_DECIMAL"
  | "SIMPLE_HAS_STRUCTURE"
  | "SIMPLE_COST_MISSING"
  | "COMPOSITE_STRUCTURE_MISSING"
  | "COMPOSITE_HAS_MANUAL_COST"
  | "COMPONENT_NOT_FOUND"
  | "COMPONENT_INACTIVE"
  | "CYCLE_DETECTED"
  | "INVALID_OUTPUT_QUANTITY"
  | "UNIT_NOT_SUPPORTED"
  | "INCOMPATIBLE_UNITS";
export class CostingDomainError extends Error {
  readonly code: CostingErrorCode;
  readonly itemId?: string;
  readonly componentItemId?: string;
  constructor(
    code: CostingErrorCode,
    message: string,
    details: { itemId?: string; componentItemId?: string } = {}
  ) {
    super(message);
    this.name = "CostingDomainError";
    this.code = code;
    this.itemId = details.itemId;
    this.componentItemId = details.componentItemId;
  }
}
interface Fraction {
  numerator: bigint;
  denominator: bigint;
}
function gcd(a: bigint, b: bigint): bigint {
  a = a < 0n ? -a : a;
  b = b < 0n ? -b : b;
  while (b !== 0n) {
    const remainder = a % b;
    a = b;
    b = remainder;
  }
  return a;
}
function fraction(numerator: bigint, denominator = 1n): Fraction {
  if (denominator === 0n) throw new Error("Zero denominator");
  const sign = denominator < 0n ? -1n : 1n;
  const divisor = gcd(numerator, denominator);
  return {
    numerator: (numerator / divisor) * sign,
    denominator: (denominator / divisor) * sign,
  };
}
type UnitDimension =
  | "mass"
  | "length"
  | "count"
  | "service"
  | "set"
  | "pair"
  | "piece"
  | "time"
  | "volume"
  | "area";
interface UnitDefinition {
  dimension: UnitDimension;
  factorToBase: Fraction;
}
/** Exact factors to a canonical unit: kg, m, un, h, L and m². */
const UNIT_DEFINITIONS: Record<string, UnitDefinition> = {
  kg: { dimension: "mass", factorToBase: fraction(1n) },
  g: { dimension: "mass", factorToBase: fraction(1n, 1000n) },
  mg: { dimension: "mass", factorToBase: fraction(1n, 1000000n) },
  t: { dimension: "mass", factorToBase: fraction(1000n) },
  m: { dimension: "length", factorToBase: fraction(1n) },
  cm: { dimension: "length", factorToBase: fraction(1n, 100n) },
  mm: { dimension: "length", factorToBase: fraction(1n, 1000n) },
  un: { dimension: "count", factorToBase: fraction(1n) },
  unidade: { dimension: "count", factorToBase: fraction(1n) },
  serviço: { dimension: "service", factorToBase: fraction(1n) },
  servico: { dimension: "service", factorToBase: fraction(1n) },
  conjunto: { dimension: "set", factorToBase: fraction(1n) },
  par: { dimension: "pair", factorToBase: fraction(1n) },
  peça: { dimension: "piece", factorToBase: fraction(1n) },
  peca: { dimension: "piece", factorToBase: fraction(1n) },
  h: { dimension: "time", factorToBase: fraction(1n) },
  min: { dimension: "time", factorToBase: fraction(1n, 60n) },
  s: { dimension: "time", factorToBase: fraction(1n, 3600n) },
  L: { dimension: "volume", factorToBase: fraction(1n) },
  mL: { dimension: "volume", factorToBase: fraction(1n, 1000n) },
  "m²": { dimension: "area", factorToBase: fraction(1n) },
  "cm²": { dimension: "area", factorToBase: fraction(1n, 10000n) },
  "mm²": { dimension: "area", factorToBase: fraction(1n, 1000000n) },
};
function getUnitDefinition(unit: string, itemId: string): UnitDefinition {
  const definition = UNIT_DEFINITIONS[unit];
  if (!definition)
    throw new CostingDomainError(
      "UNIT_NOT_SUPPORTED",
      "Unsupported unit '" + unit + "' on item " + itemId,
      { itemId }
    );
  return definition;
}
function convertQuantity(
  quantity: Fraction,
  enteredUnit: string,
  referenceUnit: string,
  itemId: string
): { quantity: Fraction; factor: Fraction } {
  const entered = getUnitDefinition(enteredUnit, itemId);
  const reference = getUnitDefinition(referenceUnit, itemId);
  if (entered.dimension !== reference.dimension) {
    throw new CostingDomainError(
      "INCOMPATIBLE_UNITS",
      "Cannot convert " +
        enteredUnit +
        " to " +
        referenceUnit +
        " for item " +
        itemId,
      { itemId }
    );
  }
  const factor = divide(entered.factorToBase, reference.factorToBase, itemId);
  return { quantity: multiply(quantity, factor), factor };
}
function parseDecimal(value: string, context: string): Fraction {
  if (typeof value !== "string" || !/^\d+(?:\.\d{1,3})?$/.test(value)) {
    throw new CostingDomainError(
      "INVALID_DECIMAL",
      "Expected a non-negative decimal with at most three decimal places for " +
        context +
        ": " +
        String(value)
    );
  }
  const parts = value.split(".");
  const scale = (parts[1] || "").length;
  return fraction(BigInt(parts[0] + (parts[1] || "")), 10n ** BigInt(scale));
}
function add(a: Fraction, b: Fraction): Fraction {
  return fraction(
    a.numerator * b.denominator + b.numerator * a.denominator,
    a.denominator * b.denominator
  );
}
function multiply(a: Fraction, b: Fraction): Fraction {
  return fraction(a.numerator * b.numerator, a.denominator * b.denominator);
}
function divide(a: Fraction, b: Fraction, itemId: string): Fraction {
  if (b.numerator === 0n) {
    throw new CostingDomainError(
      "INVALID_OUTPUT_QUANTITY",
      "Output quantity must be greater than zero: " + itemId,
      { itemId }
    );
  }
  return fraction(a.numerator * b.denominator, a.denominator * b.numerator);
}
function terminatingDecimal(value: Fraction): string | null {
  let denominator = value.denominator,
    twos = 0,
    fives = 0;
  while (denominator % 2n === 0n) {
    denominator /= 2n;
    twos += 1;
  }
  while (denominator % 5n === 0n) {
    denominator /= 5n;
    fives += 1;
  }
  if (denominator !== 1n) return null;
  const scale = Math.max(twos, fives);
  const coefficient =
    value.numerator * 2n ** BigInt(scale - twos) * 5n ** BigInt(scale - fives);
  const negative = coefficient < 0n;
  const digits = (negative ? -coefficient : coefficient).toString();
  if (scale === 0) return (negative ? "-" : "") + digits;
  const padded = digits.padStart(scale + 1, "0"),
    splitAt = padded.length - scale;
  let result = padded.slice(0, splitAt) + "." + padded.slice(splitAt);
  result = result.replace(/0+$/, "").replace(/\.$/, "");
  return (negative ? "-" : "") + result;
}
function fractionToExactString(value: Fraction): string {
  return (
    terminatingDecimal(value) ??
    value.numerator.toString() + "/" + value.denominator.toString()
  );
}
/** Round the final result to three places. Exact ties stay down, matching the approved convention. */
function roundFractionToThree(value: Fraction): string {
  const scaledNumerator = value.numerator * 1000n;
  let rounded = scaledNumerator / value.denominator;
  const fourthDecimalDigit =
    ((scaledNumerator * 10n) / value.denominator) % 10n;
  if (fourthDecimalDigit > 5n) rounded += 1n;
  const negative = rounded < 0n;
  const digits = (negative ? -rounded : rounded).toString().padStart(4, "0");
  let result = digits.slice(0, -3) + "." + digits.slice(-3);
  result = result.replace(/0+$/, "").replace(/\.$/, "");
  return (negative ? "-" : "") + (result || "0");
}
function parseExactString(value: string): Fraction {
  if (/^\d+\/\d+$/.test(value)) {
    const [numerator, denominator] = value.split("/");
    return fraction(BigInt(numerator), BigInt(denominator));
  }
  if (/^\d+(?:\.\d+)?$/.test(value)) {
    const parts = value.split(".");
    return fraction(
      BigInt(parts[0] + (parts[1] || "")),
      10n ** BigInt((parts[1] || "").length)
    );
  }
  throw new CostingDomainError(
    "INVALID_DECIMAL",
    "Invalid exact decimal value: " + value
  );
}
export function formatCostForDisplay(exactValue: string): string {
  return roundFractionToThree(parseExactString(exactValue));
}
export function calculateItemCost(
  sourceItems: readonly CostingItem[],
  targetItemId: string
): CostingResult {
  const items = new Map<string, CostingItem>();
  for (const item of sourceItems) {
    if (items.has(item.id))
      throw new CostingDomainError(
        "DUPLICATE_ITEM_ID",
        "Duplicate item identifier: " + item.id,
        { itemId: item.id }
      );
    items.set(item.id, item);
  }
  const root = items.get(targetItemId);
  if (!root)
    throw new CostingDomainError(
      "ITEM_NOT_FOUND",
      "Item not found: " + targetItemId,
      { itemId: targetItemId }
    );
  const visiting: string[] = [];
  const resolve = (
    item: CostingItem
  ): { result: CostingResult; exactCost: Fraction } => {
    if (!item.active)
      throw new CostingDomainError(
        "ITEM_INACTIVE",
        "Item is inactive: " + item.id,
        { itemId: item.id }
      );
    if (!item.unit.trim())
      throw new CostingDomainError(
        "INVALID_UNIT",
        "Item has no unit: " + item.id,
        { itemId: item.id }
      );
    if (item.type !== "SIMPLE" && item.type !== "COMPOSITE")
      throw new CostingDomainError(
        "INVALID_ITEM_TYPE",
        "Invalid item type: " + item.id,
        { itemId: item.id }
      );
    const cycleIndex = visiting.indexOf(item.id);
    if (cycleIndex >= 0)
      throw new CostingDomainError(
        "CYCLE_DETECTED",
        "Composition cycle detected: " +
          [...visiting.slice(cycleIndex), item.id].join(" -> "),
        { itemId: item.id }
      );
    if (item.type === "SIMPLE") {
      if (item.structure && item.structure.length > 0)
        throw new CostingDomainError(
          "SIMPLE_HAS_STRUCTURE",
          "Simple item cannot have a structure: " + item.id,
          { itemId: item.id }
        );
      if (item.manualUnitCost == null || item.manualUnitCost === "")
        throw new CostingDomainError(
          "SIMPLE_COST_MISSING",
          "Simple item has no manual cost: " + item.id,
          { itemId: item.id }
        );
      const cost = parseDecimal(item.manualUnitCost, "item " + item.id);
      const exactUnitCost = fractionToExactString(cost);
      return {
        exactCost: cost,
        result: {
          itemId: item.id,
          unit: item.unit,
          exactUnitCost,
          displayUnitCost: formatCostForDisplay(exactUnitCost),
          lines: [],
        },
      };
    }
    if (item.manualUnitCost != null && item.manualUnitCost !== "")
      throw new CostingDomainError(
        "COMPOSITE_HAS_MANUAL_COST",
        "Composite item cannot have manual cost: " + item.id,
        { itemId: item.id }
      );
    if (!item.structure || item.structure.length === 0)
      throw new CostingDomainError(
        "COMPOSITE_STRUCTURE_MISSING",
        "Composite item has no structure: " + item.id,
        { itemId: item.id }
      );
    visiting.push(item.id);
    try {
      const outputQuantity = parseDecimal(
        item.outputQuantity ?? "1",
        "output quantity in " + item.id
      );
      if (outputQuantity.numerator === 0n) {
        throw new CostingDomainError(
          "INVALID_OUTPUT_QUANTITY",
          "Output quantity must be greater than zero: " + item.id,
          { itemId: item.id }
        );
      }
      let batchTotal = fraction(0n);
      const lines: CostingLineResult[] = [];
      for (const line of item.structure) {
        const component = items.get(line.componentItemId);
        if (!component)
          throw new CostingDomainError(
            "COMPONENT_NOT_FOUND",
            "Component " +
              line.componentItemId +
              " referenced by " +
              item.id +
              " does not exist",
            { itemId: item.id, componentItemId: line.componentItemId }
          );
        if (!component.active)
          throw new CostingDomainError(
            "COMPONENT_INACTIVE",
            "Inactive component " + component.id + " is used by " + item.id,
            { itemId: item.id, componentItemId: component.id }
          );
        const enteredQuantity = parseDecimal(
          line.quantity,
          "quantity in " + item.id
        );
        const enteredUnit = line.quantityUnit ?? component.unit;
        const conversion = convertQuantity(
          enteredQuantity,
          enteredUnit,
          component.unit,
          item.id
        );
        const child = resolve(component);
        const batchLineCost = multiply(conversion.quantity, child.exactCost);
        batchTotal = add(batchTotal, batchLineCost);
        lines.push({
          componentItemId: component.id,
          quantity: line.quantity,
          enteredUnit,
          referenceUnit: component.unit,
          conversionFactor: fractionToExactString(conversion.factor),
          componentUnitCost: fractionToExactString(child.exactCost),
          batchLineCost: fractionToExactString(batchLineCost),
        });
      }
      // Keep the exact rational result throughout every level; round only for final presentation.
      const exactCost = divide(batchTotal, outputQuantity, item.id);
      const exactUnitCost = fractionToExactString(exactCost);
      return {
        exactCost,
        result: {
          itemId: item.id,
          unit: item.unit,
          exactUnitCost,
          displayUnitCost: roundFractionToThree(exactCost),
          lines,
        },
      };
    } finally {
      visiting.pop();
    }
  };
  return resolve(root).result;
}

function parseGammaPercentage(value: string): Fraction {
  if (typeof value !== "string" || !/^\d+(?:\.\d{1,4})?$/.test(value)) {
    throw new CostingDomainError(
      "INVALID_DECIMAL",
      "Gama deve ser um percentual não negativo com até quatro casas decimais."
    );
  }
  const parts = value.split("."),
    scale = (parts[1] || "").length;
  return fraction(BigInt(parts[0] + (parts[1] || "")), 10n ** BigInt(scale));
}

/**
 * Applies Gama once to the resolved manual-price bases. Composite group IDs
 * are never used as bases: only SIMPLE items with a selected group contribute,
 * so nested compositions cannot apply the percentage recursively.
 */
export function calculateItemCostWithGamma(
  sourceItems: readonly CostingItem[],
  targetItemId: string,
  gamma: CostingGammaInput
): CostingGammaResult {
  const result = calculateItemCost(sourceItems, targetItemId);
  const items = new Map(sourceItems.map(item => [item.id, item]));
  const root = items.get(targetItemId);
  if (!root)
    throw new CostingDomainError(
      "ITEM_NOT_FOUND",
      "Item not found: " + targetItemId,
      { itemId: targetItemId }
    );
  const selected = new Set(gamma.selectedGroupIds);
  const baseLines: CostingGammaBaseLine[] = [];
  const visiting = new Set<string>();
  const collect = (
    item: CostingItem,
    consumedQuantity: Fraction,
    isRoot = false
  ): Fraction => {
    if (visiting.has(item.id))
      throw new CostingDomainError(
        "CYCLE_DETECTED",
        "Composition cycle detected: " + item.id,
        { itemId: item.id }
      );
    if (item.type === "SIMPLE") {
      if (
        item.groupId &&
        selected.has(item.groupId) &&
        item.manualUnitCost != null
      ) {
        const unitCost = parseDecimal(item.manualUnitCost, "item " + item.id);
        const batchCost = multiply(consumedQuantity, unitCost);
        baseLines.push({
          itemId: item.id,
          groupId: item.groupId,
          quantity: fractionToExactString(consumedQuantity),
          unit: item.unit,
          unitCost: fractionToExactString(unitCost),
          batchCost: fractionToExactString(batchCost),
        });
        return batchCost;
      }
      return fraction(0n);
    }
    if (!item.structure) return fraction(0n);
    visiting.add(item.id);
    try {
      let total = fraction(0n);
      const outputQuantity = parseDecimal(
        item.outputQuantity ?? "1",
        "output quantity in " + item.id
      );
      const childConsumedQuantity = isRoot
        ? consumedQuantity
        : divide(consumedQuantity, outputQuantity, item.id);
      for (const line of item.structure) {
        const component = items.get(line.componentItemId);
        if (!component)
          throw new CostingDomainError(
            "COMPONENT_NOT_FOUND",
            "Component not found: " + line.componentItemId,
            { itemId: item.id, componentItemId: line.componentItemId }
          );
        const converted = convertQuantity(
          parseDecimal(line.quantity, "quantity in " + item.id),
          line.quantityUnit ?? component.unit,
          component.unit,
          item.id
        );
        total = add(
          total,
          collect(
            component,
            multiply(childConsumedQuantity, converted.quantity)
          )
        );
      }
      return total;
    } finally {
      visiting.delete(item.id);
    }
  };
  const baseBatch = gamma.active
    ? collect(root, fraction(1n), true)
    : fraction(0n);
  const percentage = gamma.active
    ? parseGammaPercentage(gamma.percentage ?? "1.2")
    : fraction(0n);
  const adjustmentBatch = divide(
    multiply(baseBatch, percentage),
    fraction(100n),
    targetItemId
  );
  const outputQuantity = parseDecimal(
    root.outputQuantity ?? "1",
    "output quantity in " + root.id
  );
  const adjustmentUnit = divide(adjustmentBatch, outputQuantity, targetItemId);
  const adjustedExact = add(
    parseExactString(result.exactUnitCost),
    adjustmentUnit
  );
  const adjusted: CostingResult = {
    ...result,
    exactUnitCost: fractionToExactString(adjustedExact),
    displayUnitCost: roundFractionToThree(adjustedExact),
  };
  return {
    baseBatchCost: fractionToExactString(baseBatch),
    adjustmentBatchCost: fractionToExactString(adjustmentBatch),
    adjustmentUnitCost: fractionToExactString(adjustmentUnit),
    baseLines,
    result: adjusted,
  };
}
