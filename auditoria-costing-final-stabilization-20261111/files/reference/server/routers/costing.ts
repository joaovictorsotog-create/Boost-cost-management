import { TRPCError } from "@trpc/server";
import { z } from "zod";
import {
  calculateItemCost,
  calculateItemCostWithGamma,
  CostingDomainError,
  type CostingItem,
} from "../domain/costing/engine";
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
} from "../db/costing";
import { requireTenantPermission } from "../services/tenant-access";
import { protectedProcedure, router } from "../_core/trpc";

const organizationId = z.string().min(8).max(64);
const structureId = z.string().trim().min(1).max(32);
const lineId = z.string().trim().min(1).max(32);
export const decimalInput = z
  .string()
  .regex(
    /^\d+(?:\.\d{1,3})?$/,
    "Use um número não negativo com até três casas decimais."
  );
const unitInput = z.enum([
  "kg",
  "g",
  "mg",
  "t",
  "m",
  "cm",
  "mm",
  "un",
  "unidade",
  "serviço",
  "servico",
  "conjunto",
  "par",
  "peça",
  "peca",
  "h",
  "min",
  "s",
  "L",
  "mL",
  "m²",
  "cm²",
  "mm²",
]);
const structureLine = z.object({
  componentItemId: z.string().trim().min(1).max(128),
  quantity: decimalInput,
  quantityUnit: unitInput.optional(),
  position: z.number().int().min(0).max(10000).optional(),
  notes: z.string().max(2000).nullable().optional(),
});
const persistedStructureLine = structureLine.extend({
  quantityUnit: unitInput,
});
const costingItem = z.object({
  id: z.string().trim().min(1).max(128),
  type: z.enum(["SIMPLE", "COMPOSITE"]),
  active: z.boolean(),
  unit: unitInput,
  groupId: z.string().trim().min(1).max(32).nullable().optional(),
  outputQuantity: decimalInput.optional(),
  manualUnitCost: decimalInput.nullable().optional(),
  structure: z.array(structureLine).max(1000).optional(),
});

function costingError(error: unknown): never {
  if (error instanceof CostingDomainError) {
    throw new TRPCError({
      code: "BAD_REQUEST",
      message: error.message,
      cause: error,
    });
  }
  throw error;
}

export const costingRouter = router({
  calculate: protectedProcedure
    .input(
      z.object({
        organizationId,
        items: z.array(costingItem).min(1).max(500),
        targetItemId: z.string().trim().min(1).max(128),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      try {
        return calculateItemCost(
          input.items as CostingItem[],
          input.targetItemId
        );
      } catch (error) {
        return costingError(error);
      }
    }),
  calculateWithGamma: protectedProcedure
    .input(
      z.object({
        organizationId,
        items: z.array(costingItem).min(1).max(500),
        targetItemId: z.string().trim().min(1).max(128),
        gamma: z.object({
          active: z.boolean(),
          percentage: z
            .string()
            .regex(/^\d+(?:\.\d{1,4})?$/)
            .default("1.2"),
          selectedGroupIds: z.array(z.string().trim().min(1).max(32)).max(100),
        }),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      try {
        return calculateItemCostWithGamma(
          input.items as CostingItem[],
          input.targetItemId,
          input.gamma
        );
      } catch (error) {
        return costingError(error);
      }
    }),
  createSnapshot: protectedProcedure
    .input(
      z.object({
        organizationId,
        targetItemId: z.string().trim().min(1).max(128),
        structureId: structureId.nullable().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      try {
        return await calculateAndCreateCostingSnapshot(input);
      } catch (error) {
        return costingError(error);
      }
    }),
  snapshots: protectedProcedure
    .input(
      z.object({
        organizationId,
        itemId: z.string().trim().min(1).max(32),
        limit: z.number().int().min(1).max(100).default(50),
      })
    )
    .query(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      return listCostingSnapshots(
        input.organizationId,
        input.itemId,
        input.limit
      );
    }),
  structures: protectedProcedure
    .input(
      z.object({
        organizationId,
        itemId: z.string().trim().min(1).max(32).optional(),
      })
    )
    .query(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      return listCostStructures(input.organizationId, input.itemId);
    }),
  structure: protectedProcedure
    .input(z.object({ organizationId, structureId }))
    .query(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      return getCostStructure(input.organizationId, input.structureId);
    }),
  createStructure: protectedProcedure
    .input(
      z.object({
        organizationId,
        itemId: z.string().trim().min(1).max(32),
        outputQuantity: decimalInput.optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return createCostStructure(input);
    }),
  updateStructure: protectedProcedure
    .input(
      z.object({ organizationId, structureId, outputQuantity: decimalInput })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return updateCostStructure(input);
    }),
  createStructureLine: protectedProcedure
    .input(
      z.object({ organizationId, structureId, ...persistedStructureLine.shape })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return createCostStructureLine(input);
    }),
  updateStructureLine: protectedProcedure
    .input(
      z.object({
        organizationId,
        lineId,
        componentItemId: z.string().trim().min(1).max(32).optional(),
        quantity: decimalInput.optional(),
        quantityUnit: unitInput.optional(),
        position: z.number().int().min(0).max(10000).optional(),
        notes: z.string().max(2000).nullable().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return updateCostStructureLine(input);
    }),
  deleteStructureLine: protectedProcedure
    .input(z.object({ organizationId, lineId }))
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return deleteCostStructureLine(input);
    }),
  publishStructure: protectedProcedure
    .input(z.object({ organizationId, structureId }))
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      try {
        return await publishCostStructure(
          input.organizationId,
          input.structureId
        );
      } catch (error) {
        return costingError(error);
      }
    }),
});
