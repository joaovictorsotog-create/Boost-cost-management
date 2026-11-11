import { describe, expect, it } from "vitest";
import { calculateItemCost, type CostingItem } from "./engine";
import { createCostingCalculationSnapshot } from "./snapshot";
import { planStructurePublication } from "./structure-publication";

describe("costing calculation snapshots", () => {
  it("captures the complete input graph, result, and Gama configuration", () => {
    const items: CostingItem[] = [
      {
        id: "steel",
        type: "SIMPLE",
        active: true,
        unit: "kg",
        manualUnitCost: "10",
      },
      {
        id: "frame",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [
          { componentItemId: "steel", quantity: "500", quantityUnit: "g" },
        ],
      },
    ];
    const result = calculateItemCost(items, "frame");
    const snapshot = createCostingCalculationSnapshot({
      organizationId: "org-12345678",
      targetItemId: "frame",
      structureId: "active-frame-v1",
      sourceItems: items,
      gamma: {
        active: true,
        percentage: "1.2000",
        selectedGroupIds: ["raw-materials"],
      },
      result,
      calculatedAt: "2026-11-10T15:00:00.000Z",
    });

    expect(snapshot.snapshotVersion).toBe(1);
    expect(snapshot.engineVersion).toBe("costing-engine-v1");
    expect(snapshot.structureId).toBe("active-frame-v1");
    expect(snapshot.sourceItems).toHaveLength(2);
    expect(snapshot.result.exactUnitCost).toBe("5");
    expect(snapshot.exactUnitCost).toEqual({
      numerator: "5",
      denominator: "1",
    });
    expect(snapshot.gamma).toEqual({
      active: true,
      percentage: "1.2000",
      selectedGroupIds: ["raw-materials"],
    });
    expect(JSON.parse(JSON.stringify(snapshot))).toEqual(snapshot);
  });

  it("stores recurring exact costs as numerator and denominator", () => {
    const items: CostingItem[] = [
      {
        id: "raw",
        type: "SIMPLE",
        active: true,
        unit: "un",
        manualUnitCost: "1",
      },
      {
        id: "third",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        outputQuantity: "3",
        structure: [{ componentItemId: "raw", quantity: "1" }],
      },
    ];
    const result = calculateItemCost(items, "third");
    const snapshot = createCostingCalculationSnapshot({
      organizationId: "org-12345678",
      targetItemId: "third",
      sourceItems: items,
      gamma: { active: false, percentage: "1.2000", selectedGroupIds: [] },
      result,
      calculatedAt: "2026-11-10T15:00:00.000Z",
    });
    expect(snapshot.exactUnitCost).toEqual({
      numerator: "1",
      denominator: "3",
    });
  });

  it("copies nested source lines so later mutations do not rewrite the snapshot", () => {
    const line = { componentItemId: "raw", quantity: "1", quantityUnit: "un" };
    const items: CostingItem[] = [
      {
        id: "raw",
        type: "SIMPLE",
        active: true,
        unit: "un",
        manualUnitCost: "2",
      },
      {
        id: "finished",
        type: "COMPOSITE",
        active: true,
        unit: "un",
        structure: [line],
      },
    ];
    const result = calculateItemCost(items, "finished");
    const snapshot = createCostingCalculationSnapshot({
      organizationId: "org-12345678",
      targetItemId: "finished",
      sourceItems: items,
      gamma: { active: false, percentage: "1.2000", selectedGroupIds: [] },
      result,
      calculatedAt: "2026-11-10T15:00:00.000Z",
    });
    line.quantity = "99";
    expect(snapshot.sourceItems[1].structure?.[0].quantity).toBe("1");
  });
});

describe("cost structure publication planning", () => {
  it("plans atomic replacement of the currently active version", () => {
    expect(
      planStructurePublication(
        [
          { id: "v1", itemId: "item-a", version: 1, status: "ACTIVE" },
          { id: "v2", itemId: "item-a", version: 2, status: "DRAFT" },
          { id: "other", itemId: "item-b", version: 1, status: "ACTIVE" },
        ],
        "v2"
      )
    ).toEqual({
      activateStructureId: "v2",
      supersedeStructureIds: ["v1"],
    });
  });

  it("rejects publishing a non-draft or missing version", () => {
    expect(() =>
      planStructurePublication(
        [{ id: "v1", itemId: "item-a", version: 1, status: "ACTIVE" }],
        "v1"
      )
    ).toThrow("Only a DRAFT structure can be published.");
    expect(() => planStructurePublication([], "missing")).toThrow(
      "Structure version not found."
    );
  });

  it("detects corrupt existing states and duplicate version numbers", () => {
    expect(() =>
      planStructurePublication(
        [
          { id: "v1", itemId: "item-a", version: 1, status: "ACTIVE" },
          { id: "v2", itemId: "item-a", version: 2, status: "ACTIVE" },
          { id: "v3", itemId: "item-a", version: 3, status: "DRAFT" },
        ],
        "v3"
      )
    ).toThrow("Data integrity error");
    expect(() =>
      planStructurePublication(
        [
          { id: "v1", itemId: "item-a", version: 1, status: "INACTIVE" },
          { id: "v2", itemId: "item-a", version: 1, status: "DRAFT" },
        ],
        "v2"
      )
    ).toThrow("Duplicate structure version number.");
  });
});
