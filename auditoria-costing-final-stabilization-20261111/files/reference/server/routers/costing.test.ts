import { beforeEach, describe, expect, it, vi } from "vitest";
import { TRPCError } from "@trpc/server";

const mocks = vi.hoisted(() => ({
  withRequestRuntimeDb: vi.fn(
    (_identity: unknown, work: () => Promise<unknown>) => work()
  ),
  requireTenantPermission: vi.fn(),
  calculateAndCreateCostingSnapshot: vi.fn(),
  listCostingSnapshots: vi.fn(),
  calculateItemCost: vi.fn(),
  calculateItemCostWithGamma: vi.fn(),
  listCostStructures: vi.fn(),
  getCostStructure: vi.fn(),
  createCostStructure: vi.fn(),
  updateCostStructure: vi.fn(),
  createCostStructureLine: vi.fn(),
  updateCostStructureLine: vi.fn(),
  deleteCostStructureLine: vi.fn(),
  publishCostStructure: vi.fn(),
}));

vi.mock("../services/tenant-access", () => ({
  requireTenantPermission: mocks.requireTenantPermission,
}));
vi.mock("../lib/appRuntimeDb", () => ({
  withRequestRuntimeDb: mocks.withRequestRuntimeDb,
}));
vi.mock("../db/costing", () => ({
  calculateAndCreateCostingSnapshot: mocks.calculateAndCreateCostingSnapshot,
  listCostingSnapshots: mocks.listCostingSnapshots,
  calculateItemCost: mocks.calculateItemCost,
  calculateItemCostWithGamma: mocks.calculateItemCostWithGamma,
  listCostStructures: mocks.listCostStructures,
  getCostStructure: mocks.getCostStructure,
  createCostStructure: mocks.createCostStructure,
  updateCostStructure: mocks.updateCostStructure,
  createCostStructureLine: mocks.createCostStructureLine,
  updateCostStructureLine: mocks.updateCostStructureLine,
  deleteCostStructureLine: mocks.deleteCostStructureLine,
  publishCostStructure: mocks.publishCostStructure,
}));

import { costingRouter, decimalInput } from "./costing";

const organizationId = "org-costing-test";
const otherOrganizationId = "org-other-test";
const caller = () =>
  costingRouter.createCaller({
    user: { id: 17, supabaseAuthId: "test-supabase-auth-17" },
  } as any);

function forbidden(message = "FORBIDDEN") {
  return new TRPCError({ code: "FORBIDDEN", message });
}

describe("costing decimal input", () => {
  it.each(["10", "1.25", "0.500", "0"])("accepts %s", value => {
    expect(decimalInput.safeParse(value).success).toBe(true);
  });

  it.each(["1.2345", "-1", "-0.5", "", ".5", "1.", "1,25", " 1"])(
    "rejects %s",
    value => {
      expect(decimalInput.safeParse(value).success).toBe(false);
    }
  );
});

describe("costing router authorization and service boundaries", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireTenantPermission.mockResolvedValue({ role: "admin" });
    mocks.listCostingSnapshots.mockResolvedValue([]);
    mocks.listCostStructures.mockResolvedValue([]);
    mocks.getCostStructure.mockResolvedValue({
      id: "structure-1",
      status: "DRAFT",
      lines: [],
    });
    mocks.createCostStructure.mockResolvedValue({
      id: "structure-1",
      status: "DRAFT",
      lines: [],
    });
    mocks.updateCostStructure.mockResolvedValue({
      id: "structure-1",
      status: "DRAFT",
      lines: [],
    });
    mocks.createCostStructureLine.mockResolvedValue({ id: "line-1" });
    mocks.updateCostStructureLine.mockResolvedValue({ id: "line-1" });
    mocks.deleteCostStructureLine.mockResolvedValue({ id: "line-1" });
    mocks.publishCostStructure.mockResolvedValue({
      published: { id: "structure-1", status: "ACTIVE" },
    });
    mocks.calculateAndCreateCostingSnapshot.mockResolvedValue({
      id: "snapshot-1",
    });
  });

  it("permite leitura ao tenant correto com costing.read", async () => {
    await caller().structures({ organizationId });
    await caller().snapshots({ organizationId, itemId: "item-1" });
    expect(
      mocks.requireTenantPermission.mock.calls.map(call => call[2])
    ).toEqual(["costing.read", "costing.read"]);
  });

  it("nega leitura e escrita quando a permissão do usuário é insuficiente", async () => {
    mocks.requireTenantPermission.mockImplementation(
      async (_userId, _org, permission) => {
        if (permission !== "costing.read")
          throw forbidden("workspace.manage ausente");
        return { role: "agent" };
      }
    );
    await expect(
      caller().createStructure({ organizationId, itemId: "item-1" })
    ).rejects.toThrow("workspace.manage ausente");
    await expect(
      caller().publishStructure({ organizationId, structureId: "structure-1" })
    ).rejects.toThrow("workspace.manage ausente");
    expect(mocks.createCostStructure).not.toHaveBeenCalled();
    expect(mocks.publishCostStructure).not.toHaveBeenCalled();
  });

  it("nega qualquer organização diferente da autorizada", async () => {
    mocks.requireTenantPermission.mockImplementation(async (_userId, org) => {
      if (org !== organizationId) throw forbidden("tenant inválido");
      return { role: "admin" };
    });
    await expect(
      caller().structures({ organizationId: otherOrganizationId })
    ).rejects.toThrow("tenant inválido");
    expect(mocks.listCostStructures).not.toHaveBeenCalled();
  });

  it("encaminha operações DRAFT ao serviço somente após workspace.manage", async () => {
    await caller().createStructure({
      organizationId,
      itemId: "item-1",
      outputQuantity: "2",
    });
    await caller().createStructureLine({
      organizationId,
      structureId: "structure-1",
      componentItemId: "component-1",
      quantity: "1.250",
      quantityUnit: "kg",
    });
    await caller().updateStructureLine({
      organizationId,
      lineId: "line-1",
      quantity: "2",
      quantityUnit: "kg",
    });
    await caller().deleteStructureLine({ organizationId, lineId: "line-1" });
    expect(
      mocks.requireTenantPermission.mock.calls.map(call => call[2])
    ).toEqual(Array(4).fill("workspace.manage"));
  });

  it("não atravessa tenant ao criar estrutura com item estrangeiro", async () => {
    mocks.createCostStructure.mockRejectedValue(
      new Error("Item não encontrado na organização")
    );
    await expect(
      caller().createStructure({
        organizationId,
        itemId: "item-from-other-tenant",
      })
    ).rejects.toThrow("Item não encontrado na organização");
    expect(mocks.createCostStructure).toHaveBeenCalledWith({
      organizationId,
      itemId: "item-from-other-tenant",
    });
  });

  it("não aceita snapshot oficial baseado em estrutura não ACTIVE", async () => {
    mocks.calculateAndCreateCostingSnapshot.mockRejectedValue(
      new Error("Snapshots oficiais exigem uma estrutura ACTIVE")
    );
    await expect(
      caller().createSnapshot({
        organizationId,
        targetItemId: "item-1",
        structureId: "draft-1",
      })
    ).rejects.toThrow("Snapshots oficiais exigem uma estrutura ACTIVE");
  });
});
