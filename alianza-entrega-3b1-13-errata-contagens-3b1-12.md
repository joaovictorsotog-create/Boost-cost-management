# Errata — Contagens do diff da Entrega 3B.1.12

## Base da contagem

A contagem foi recalculada diretamente com:

```text
git diff --name-status 27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801 16fde337f707734fbca13ac311f1ebe2d01a2472
```

## Contagem correta

- Arquivos adicionados: **4**
- Arquivos modificados: **13**
- Arquivos removidos: **0**
- Total: **17**

A descrição anterior que informava “3 adicionados e 14 modificados” estava incorreta. O inventário que informava “4 adicionados e 13 modificados” é o correto.

## Arquivos adicionados

1. `drizzle/pg/0036_costing_foundation.sql`
2. `server/apply-supabase-rls.preflight.test.ts`
3. `server/db/costing.ts`
4. `server/routers/costing.test.ts`

## Arquivos modificados

1. `drizzle/pg/rls_multitenant.sql`
2. `drizzle/pg/schema.costing.ts`
3. `scripts/apply-supabase-rls.mjs`
4. `server/app-runtime-rls-context.contract.test.ts`
5. `server/db.ts`
6. `server/domain/costing/engine.test.ts`
7. `server/domain/costing/engine.ts`
8. `server/domain/costing/snapshot.test.ts`
9. `server/domain/costing/snapshot.ts`
10. `server/domain/costing/structure-publication.ts`
11. `server/routers/costing.ts`
12. `server/supabase-rls.contract.test.ts`
13. `tsconfig.json`

## Integridade

O diff de referência não foi alterado. A errata corrige somente a documentação em novo arquivo e não reescreve o relatório histórico.
