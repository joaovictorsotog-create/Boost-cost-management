# Entrega 3B.1.12 — Matriz de commits e arquivos publicados em relação à base remota

Base remota: `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801`

Commit final: `16fde337f707734fbca13ac311f1ebe2d01a2472`

| Commit | Arquivos próprios do commit | Classificação |
|---|---|---|
| `3571f34f34a8d46af1f07924eef389035ca81dd0` | `server/domain/costing/engine.ts`, `engine.test.ts`, `snapshot.ts`, `snapshot.test.ts`, `structure-publication.ts`, `tsconfig.json` | Núcleo Costing e suporte BigInt |
| `0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c` | `drizzle/pg/0036_costing_foundation.sql`, `schema.costing.ts`, `server/db.ts`, `server/db/costing.ts`, `server/routers/costing.ts` | Persistência, migration, integração Costing e TLS local |
| `4ae1ffb5500a93bc076ba7d8a1aa17a42bc4ca39` | `engine.ts`, `engine.test.ts`, `server/routers/costing.ts`, `server/routers/costing.test.ts` | Validação e autoridade de snapshot Costing |
| `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` | `0036_costing_foundation.sql`, `schema.costing.ts`, `server/db/costing.ts` | Constraints e imutabilidade Costing |
| `16fde337f707734fbca13ac311f1ebe2d01a2472` | `rls_multitenant.sql`, `apply-supabase-rls.mjs`, contratos RLS/contexto e teste de preflight | Segurança Costing e hardening transversal |

## Inventário final de 17 caminhos

| Status | Caminho | Escopo | Observação |
|---|---|---|---|
| A | `drizzle/pg/0036_costing_foundation.sql` | Costing | Schema, constraints e trigger de snapshot |
| M | `drizzle/pg/rls_multitenant.sql` | Segurança transversal + Costing | Helpers gerais e sete tabelas Costing |
| M | `drizzle/pg/schema.costing.ts` | Costing | Sete tabelas e constraints Drizzle |
| M | `scripts/apply-supabase-rls.mjs` | Segurança transversal | Preflight antes de conexão |
| M | `server/app-runtime-rls-context.contract.test.ts` | Segurança transversal | Identidade `app_runtime`/`auth.uid()` |
| A | `server/apply-supabase-rls.preflight.test.ts` | Segurança | Casos positivos/negativos do preflight |
| M | `server/db.ts` | Infraestrutura de conexão | TLS remoto obrigatório; TLS desativado só em loopback |
| A | `server/db/costing.ts` | Costing | Carregamento autorizado e persistência |
| M | `server/domain/costing/engine.test.ts` | Costing | Testes do motor e Gama |
| M | `server/domain/costing/engine.ts` | Costing | Aritmética racional, composição e Gama |
| M | `server/domain/costing/snapshot.test.ts` | Costing | Snapshot autocontido e imutável em memória |
| M | `server/domain/costing/snapshot.ts` | Costing | Contrato do snapshot |
| M | `server/domain/costing/structure-publication.ts` | Costing | Publicação de estruturas |
| A | `server/routers/costing.test.ts` | Costing | Validação decimal do router |
| M | `server/routers/costing.ts` | Costing | Endpoints de cálculo, snapshot e publicação |
| M | `server/supabase-rls.contract.test.ts` | Segurança + Costing | Contratos RLS e snapshots |
| M | `tsconfig.json` | Suporte Costing | `target: ES2020` para BigInt |

Não há caminhos removidos.

## Resumo quantitativo

- Adicionados: 3
- Modificados: 14
- Removidos: 0
- Total: 17
- Adições: 2.250 linhas
- Remoções: 344 linhas
- Patch completo: `alianza-entrega-3b1-12-diff-27df6b0-a-16fde337.patch`
