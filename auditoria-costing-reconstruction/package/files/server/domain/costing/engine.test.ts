import { describe, expect, it } from "vitest";
import {
  calculateItemCost,
  calculateItemCostWithGamma,
  CostingDomainError,
  formatCostForDisplay,
  type CostingItem,
} from "./engine";

const simple = (id: string, cost: string, active = true): CostingItem => ({
  id,
  type: "SIMPLE",
  active,
  unit: "unidade",
  manualUnitCost: cost,
});

describe("costing domain engine", () => {
  it("accepts and preserves small values with three decimal places", () => {
    const result = calculateItemCost([simple("small", "0.025")], "small");
    expect(result.exactUnitCost).toBe("0.025");
    expect(result.displayUnitCost).toBe("0.025");
    expect(formatCostForDisplay("0.025")).toBe("0.025");
  });

  it("uses exact rational arithmetic across multiple composition levels", () => {
    const items: CostingItem[] = [
      simple("one-third-source", "1"),
      {
        id: "one-third",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        outputQuantity: "3",
        structure: [{ componentItemId: "one-third-source", quantity: "1" }],
      },
      {
        id: "whole",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [{ componentItemId: "one-third", quantity: "3" }],
      },
    ];
    const recurring = calculateItemCost(items, "one-third");
    const whole = calculateItemCost(items, "whole");
    expect(recurring.exactUnitCost).toBe("1/3");
    expect(recurring.displayUnitCost).toBe("0.333");
    expect(whole.exactUnitCost).toBe("1");
    expect(whole.displayUnitCost).toBe("1");
  });

  it("rounds only the final unit cost to at most three decimals, with ties down", () => {
    expect(formatCostForDisplay("1.2344")).toBe("1.234");
    expect(formatCostForDisplay("1.2345")).toBe("1.234");
    expect(formatCostForDisplay("1.2345001")).toBe("1.234");
    expect(formatCostForDisplay("1.2346")).toBe("1.235");
    expect(formatCostForDisplay("1/3")).toBe("0.333");
    expect(formatCostForDisplay("12")).toBe("12");
  });

  it("preserves intermediate precision instead of rounding a nested component", () => {
    const items: CostingItem[] = [
      simple("mill", "0.001"),
      {
        id: "subassembly",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [{ componentItemId: "mill", quantity: "0.4" }],
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [{ componentItemId: "subassembly", quantity: "2" }],
      },
    ];
    const result = calculateItemCost(items, "finished");
    expect(result.exactUnitCost).toBe("0.0008");
    expect(result.displayUnitCost).toBe("0.001");
  });

  it("calculates multi-level structures and repeated occurrences", () => {
    const items: CostingItem[] = [
      simple("bolt", "0.1"),
      simple("plate", "10"),
      {
        id: "sub",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [{ componentItemId: "bolt", quantity: "2" }],
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [
          { componentItemId: "sub", quantity: "3" },
          { componentItemId: "plate", quantity: "1.5" },
          { componentItemId: "bolt", quantity: "2" },
        ],
      },
    ];
    const result = calculateItemCost(items, "finished");
    expect(result.exactUnitCost).toBe("15.8");
    expect(result.displayUnitCost).toBe("15.8");
    expect(result.lines.map(line => line.batchLineCost)).toEqual([
      "0.6",
      "15",
      "0.2",
    ]);
  });

  it("rejects composition cycles", () => {
    const items: CostingItem[] = [
      {
        id: "a",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "b", quantity: "1" }],
      },
      {
        id: "b",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "a", quantity: "1" }],
      },
    ];
    expect(() => calculateItemCost(items, "a")).toThrowError(
      expect.objectContaining({ code: "CYCLE_DETECTED" })
    );
  });

  it("rejects inactive components", () => {
    const items: CostingItem[] = [
      simple("x", "2", false),
      {
        id: "parent",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "x", quantity: "1" }],
      },
    ];
    expect(() => calculateItemCost(items, "parent")).toThrowError(
      expect.objectContaining({ code: "COMPONENT_INACTIVE" })
    );
  });

  it("rejects manual cost on a composite", () => {
    const items: CostingItem[] = [
      simple("x", "2"),
      {
        id: "parent",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        manualUnitCost: "99",
        structure: [{ componentItemId: "x", quantity: "1" }],
      },
    ];
    expect(() => calculateItemCost(items, "parent")).toThrowError(
      expect.objectContaining({ code: "COMPOSITE_HAS_MANUAL_COST" })
    );
  });

  it("rejects missing components and malformed decimal quantities", () => {
    const missing: CostingItem[] = [
      {
        id: "p",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "ghost", quantity: "1" }],
      },
    ];
    expect(() => calculateItemCost(missing, "p")).toThrowError(
      expect.objectContaining({ code: "COMPONENT_NOT_FOUND" })
    );
    const malformed: CostingItem[] = [
      simple("x", "2"),
      {
        id: "p",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "x", quantity: "1,2" }],
      },
    ];
    expect(() => calculateItemCost(malformed, "p")).toThrowError(
      CostingDomainError
    );
  });

  it("rejects user-entered values with more than three decimal places", () => {
    expect(() =>
      calculateItemCost([simple("invalid", "1.2345")], "invalid")
    ).toThrowError(expect.objectContaining({ code: "INVALID_DECIMAL" }));
    const items: CostingItem[] = [
      simple("part", "1"),
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "part", quantity: "0.0001" }],
      },
    ];
    expect(() => calculateItemCost(items, "finished")).toThrowError(
      expect.objectContaining({ code: "INVALID_DECIMAL" })
    );
  });

  it("calculates an artificial multi-line composition (R$ 44)", () => {
    const items: CostingItem[] = [
      simple("shaft", "10"),
      simple("steel-sheet", "10"),
      simple("m6-bolt", "1"),
      {
        id: "mechanism",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        structure: [
          { componentItemId: "shaft", quantity: "1" },
          { componentItemId: "steel-sheet", quantity: "3" },
          { componentItemId: "m6-bolt", quantity: "4" },
        ],
      },
    ];
    const result = calculateItemCost(items, "mechanism");
    expect(result.exactUnitCost).toBe("44");
    expect(result.displayUnitCost).toBe("44");
    expect(result.lines.map(line => line.batchLineCost)).toEqual([
      "10",
      "30",
      "4",
    ]);
  });

  it("rounds an artificial exact result only for presentation", () => {
    expect(formatCostForDisplay("123.4564818")).toBe("123.456");
  });

  it("allocates a three-decimal tube purchase across the output quantity", () => {
    const items: CostingItem[] = [
      {
        id: "tube-meter",
        type: "SIMPLE",
        active: true,
        unit: "m",
        manualUnitCost: "44.474",
      },
      {
        id: "tube-lot",
        type: "COMPOSITE",
        active: true,
        unit: "conjunto",
        outputQuantity: "10",
        structure: [{ componentItemId: "tube-meter", quantity: "12" }],
      },
    ];
    const result = calculateItemCost(items, "tube-lot");
    expect(result.exactUnitCost).toBe("53.3688");
    expect(result.displayUnitCost).toBe("53.369");
    expect(result.lines[0].batchLineCost).toBe("533.688");
  });

  it("aggregates batch line costs before dividing by output quantity", () => {
    const items: CostingItem[] = [
      simple("one-real", "1"),
      {
        id: "three-unit-batch",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        outputQuantity: "3",
        structure: [
          { componentItemId: "one-real", quantity: "1" },
          { componentItemId: "one-real", quantity: "2" },
        ],
      },
    ];
    const result = calculateItemCost(items, "three-unit-batch");
    expect(result.exactUnitCost).toBe("1");
    expect(result.displayUnitCost).toBe("1");
    expect(result.lines.map(line => line.batchLineCost)).toEqual(["1", "2"]);
  });

  it("rejects a zero output quantity", () => {
    const items: CostingItem[] = [
      simple("component", "1"),
      {
        id: "invalid-batch",
        type: "COMPOSITE",
        active: true,
        unit: "unidade",
        outputQuantity: "0",
        structure: [{ componentItemId: "component", quantity: "1" }],
      },
    ];
    expect(() => calculateItemCost(items, "invalid-batch")).toThrowError(
      expect.objectContaining({ code: "INVALID_OUTPUT_QUANTITY" })
    );
  });

  it("converts grams to kilograms exactly and records the conversion audit data", () => {
    const items: CostingItem[] = [
      {
        id: "steel",
        type: "SIMPLE",
        active: true,
        unit: "kg",
        manualUnitCost: "10",
      },
      {
        id: "assembly",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "steel", quantity: "500", quantityUnit: "g" },
        ],
      },
    ];
    const result = calculateItemCost(items, "assembly");
    expect(result.exactUnitCost).toBe("5");
    expect(result.lines[0]).toMatchObject({
      quantity: "500",
      enteredUnit: "g",
      referenceUnit: "kg",
      conversionFactor: "0.001",
      batchLineCost: "5",
    });
  });

  it("converts centimeters to meters without intermediate rounding", () => {
    const items: CostingItem[] = [
      {
        id: "profile",
        type: "SIMPLE",
        active: true,
        unit: "m",
        manualUnitCost: "10",
      },
      {
        id: "frame",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "profile", quantity: "50", quantityUnit: "cm" },
        ],
      },
    ];
    const result = calculateItemCost(items, "frame");
    expect(result.exactUnitCost).toBe("5");
    expect(result.lines[0].conversionFactor).toBe("0.01");
  });

  it("rejects conversions between different dimensions", () => {
    const items: CostingItem[] = [
      {
        id: "steel",
        type: "SIMPLE",
        active: true,
        unit: "kg",
        manualUnitCost: "10",
      },
      {
        id: "assembly",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "steel", quantity: "2", quantityUnit: "m" },
        ],
      },
    ];
    expect(() => calculateItemCost(items, "assembly")).toThrowError(
      expect.objectContaining({ code: "INCOMPATIBLE_UNITS" })
    );
  });

  it("rejects units outside the controlled unit catalog", () => {
    const items: CostingItem[] = [
      {
        id: "steel",
        type: "SIMPLE",
        active: true,
        unit: "kg",
        manualUnitCost: "10",
      },
      {
        id: "assembly",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "steel", quantity: "2", quantityUnit: "caixa" },
        ],
      },
    ];
    expect(() => calculateItemCost(items, "assembly")).toThrowError(
      expect.objectContaining({ code: "UNIT_NOT_SUPPORTED" })
    );
  });

  it("supports service-priced items without treating services as countable units", () => {
    const items: CostingItem[] = [
      {
        id: "machining",
        type: "SIMPLE",
        active: true,
        unit: "serviço",
        manualUnitCost: "25",
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          {
            componentItemId: "machining",
            quantity: "2",
            quantityUnit: "serviço",
          },
        ],
      },
    ];
    const result = calculateItemCost(items, "finished");
    expect(result.exactUnitCost).toBe("50");
  });

  it("does not silently convert a service into a generic unit", () => {
    const items: CostingItem[] = [
      {
        id: "machining",
        type: "SIMPLE",
        active: true,
        unit: "serviço",
        manualUnitCost: "25",
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "machining", quantity: "2", quantityUnit: "un" },
        ],
      },
    ];
    expect(() => calculateItemCost(items, "finished")).toThrowError(
      expect.objectContaining({ code: "INCOMPATIBLE_UNITS" })
    );
  });

  it("applies the default 1.2% once to one selected group", () => {
    const items: CostingItem[] = [
      {
        id: "raw-a",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-a",
        manualUnitCost: "100",
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "raw-a", quantity: "2" }],
      },
    ];
    const result = calculateItemCostWithGamma(items, "finished", {
      active: true,
      selectedGroupIds: ["g-a"],
    });
    expect(result.baseBatchCost).toBe("200");
    expect(result.adjustmentBatchCost).toBe("2.4");
    expect(result.result.exactUnitCost).toBe("202.4");
  });

  it("applies Gama to a batch once and divides the adjustment by output", () => {
    const items: CostingItem[] = [
      {
        id: "batch-source",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-batch",
        manualUnitCost: "100",
      },
      {
        id: "batch-of-two",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        outputQuantity: "2",
        structure: [{ componentItemId: "batch-source", quantity: "1" }],
      },
    ];
    const result = calculateItemCostWithGamma(items, "batch-of-two", {
      active: true,
      selectedGroupIds: ["g-batch"],
    });
    expect(result.baseBatchCost).toBe("100");
    expect(result.adjustmentUnitCost).toBe("0.6");
    expect(result.result.exactUnitCost).toBe("50.6");
  });

  it("preserves exact Gama bases through an intermediate composite output", () => {
    const items: CostingItem[] = [
      {
        id: "nested-source",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-nested",
        manualUnitCost: "10",
      },
      {
        id: "nested-batch",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        outputQuantity: "2",
        structure: [{ componentItemId: "nested-source", quantity: "3" }],
      },
      {
        id: "nested-finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        outputQuantity: "4",
        structure: [{ componentItemId: "nested-batch", quantity: "2" }],
      },
    ];
    const result = calculateItemCostWithGamma(items, "nested-finished", {
      active: true,
      percentage: "1.2000",
      selectedGroupIds: ["g-nested"],
    });
    expect(result.baseBatchCost).toBe("30");
    expect(result.adjustmentBatchCost).toBe("0.36");
    expect(result.adjustmentUnitCost).toBe("0.09");
    expect(result.result.exactUnitCost).toBe("7.59");
  });

  it("sums several selected groups and ignores an unselected group", () => {
    const items: CostingItem[] = [
      {
        id: "a",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-a",
        manualUnitCost: "10",
      },
      {
        id: "b",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-b",
        manualUnitCost: "20",
      },
      {
        id: "c",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g-c",
        manualUnitCost: "30",
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "a", quantity: "1" },
          { componentItemId: "b", quantity: "1" },
          { componentItemId: "c", quantity: "1" },
        ],
      },
    ];
    const result = calculateItemCostWithGamma(items, "finished", {
      active: true,
      selectedGroupIds: ["g-a", "g-b"],
    });
    expect(result.baseBatchCost).toBe("30");
    expect(result.result.exactUnitCost).toBe("60.36");
    expect(result.baseLines).toHaveLength(2);
  });

  it("resolves manual selected items through different composition levels without recursion", () => {
    const items: CostingItem[] = [
      {
        id: "manual",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g",
        manualUnitCost: "50",
      },
      {
        id: "sub",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        outputQuantity: "2",
        structure: [{ componentItemId: "manual", quantity: "1" }],
      },
      {
        id: "root",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [{ componentItemId: "sub", quantity: "4" }],
      },
    ];
    const result = calculateItemCostWithGamma(items, "root", {
      active: true,
      selectedGroupIds: ["g"],
    });
    expect(result.baseBatchCost).toBe("100");
    expect(result.adjustmentBatchCost).toBe("1.2");
    expect(result.result.exactUnitCost).toBe("101.2");
    expect(result.baseLines).toHaveLength(1);
  });

  it("counts each physical line once, keeps duplicate group IDs harmless, and preserves exact gamma data", () => {
    const items: CostingItem[] = [
      {
        id: "manual",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "g",
        manualUnitCost: "1",
      },
      {
        id: "root",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "manual", quantity: "2" },
          { componentItemId: "manual", quantity: "3" },
        ],
      },
    ];
    const result = calculateItemCostWithGamma(items, "root", {
      active: true,
      selectedGroupIds: ["g", "g"],
    });
    expect(result.baseBatchCost).toBe("5");
    expect(result.adjustmentBatchCost).toBe("0.06");
    expect(result.baseLines.map(line => line.batchCost)).toEqual(["2", "3"]);
  });

  it("does not apply gamma when inactive or when the selected base is empty", () => {
    const items: CostingItem[] = [
      {
        id: "manual",
        type: "SIMPLE",
        active: true,
        unit: "un",
        groupId: "other",
        manualUnitCost: "10",
      },
    ];
    const inactive = calculateItemCostWithGamma(items, "manual", {
      active: false,
      selectedGroupIds: ["other"],
    });
    const empty = calculateItemCostWithGamma(items, "manual", {
      active: true,
      selectedGroupIds: ["missing"],
    });
    expect(inactive.result.exactUnitCost).toBe("10");
    expect(empty.result.exactUnitCost).toBe("10");
    expect(empty.baseBatchCost).toBe("0");
  });
});
