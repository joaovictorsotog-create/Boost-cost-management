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
  listCostingSnapshots,
  publishCostStructure,
} from "../db/costing";
import { requireTenantPermission } from "../services/tenant-access";
import { protectedProcedure, router } from "../_core/trpc";

const organizationId = z.string().min(8).max(64);
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
        if (error instanceof CostingDomainError) {
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: error.message,
            cause: error,
          });
        }
        throw error;
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
        if (error instanceof CostingDomainError)
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: error.message,
            cause: error,
          });
        throw error;
      }
    }),
  createSnapshot: protectedProcedure
    .input(
      z.object({
        organizationId,
        targetItemId: z.string().trim().min(1).max(128),
        structureId: z.string().trim().min(1).max(32).nullable().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "costing.read"
      );
      return calculateAndCreateCostingSnapshot(input);
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
  publishStructure: protectedProcedure
    .input(
      z.object({
        organizationId,
        structureId: z.string().trim().min(1).max(32),
      })
    )
    .mutation(async ({ ctx, input }) => {
      await requireTenantPermission(
        ctx.user.id,
        input.organizationId,
        "workspace.manage"
      );
      return publishCostStructure(input.organizationId, input.structureId);
    }),
});
