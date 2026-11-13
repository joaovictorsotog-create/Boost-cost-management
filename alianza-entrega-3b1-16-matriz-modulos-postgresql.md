# Matriz de compatibilidade PostgreSQL por módulo

**Branch auditada:** `costing-security-preflight-final-20261112`  
**HEAD:** `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`

| Módulo/capacidade | Evidência encontrada | Contrato PostgreSQL relevante | Estado | Gate pendente |
|---|---|---|---|---|
| Identidade/Supabase Auth | `server/lib/supabaseIdentity.ts`, scripts Supabase | claims `sub`, audience `authenticated`, sessão Supabase | Parcialmente compatível | Validar em PostgreSQL descartável com roles reais |
| Tenancy/RBAC | `server/db/tenancy.ts`, `server/policies/rbac.ts`, routers protegidos | `organizationId`, membership, helpers privados, RLS | Parcialmente compatível | Provar isolamento A/B em cada tabela convertida |
| Runtime DB | `server/db.ts`, `server/lib/appRuntimeDb.ts` | postgres-js, TLS, `app_runtime`, contexto transacional | Compatível por código | Validar grants, `rolbypassrls=false`, search_path e conexão |
| CRM | `server/routers/crm.ts`, `server/db/crm.ts`, schema PG | `jsonb`, transações, filtros tenant | Compatível por camada | Instalar baseline e executar CRUD/RLS integrado |
| Inbox/Mensageria | `server/routers/inbox.ts`, `server/db/inbox.ts` | advisory locks, `FOR UPDATE`, `jsonb`, transações | Dependente de PG | Validar concorrência, locks e RLS em cluster descartável |
| Materialização de mídia | `server/architecture/materialization/postgres-repository.ts` | `FOR UPDATE SKIP LOCKED`, fencing/version | Compatível por camada | Validar claim concorrente e índices |
| AI/Knowledge | routers/db AI e knowledge | `jsonb/json`, transações e tenancy | Parcialmente compatível | Verificar tipos PG e FK no baseline consolidado |
| Automations/Campaigns | routers/db automations, follow-ups, campaign execution | jobs, transações, cron metadata, JSON | Parcialmente compatível | Validar todas as tabelas e worker contra PG |
| Webhooks/Evolution | `server/http/evolution.ts`, migrations webhook | `ON CONFLICT`, replay guard, JSONB | Compatível por camada | Provar idempotência e RLS runtime |
| Budgets | `server/db/budgets.ts`, `drizzle/pg/schema.budgets.ts` | decimais, FK tenant, status history | Parcialmente compatível | Definir política de precisão e validar relações |
| Catalog | `server/db/catalog.ts`, `drizzle/pg/schema.catalog.ts` | decimais, soft delete, tenant indexes | Parcialmente compatível | Confirmar sequência única de migrations |
| Sellers | `server/db/sellers.ts` | `pgTable`, bigint/index | Compatível por camada | Validar instalação com dependências |
| Operations/Audit | `server/db/operations-metrics.ts`, audit migrations | RLS, logs por organização | Parcialmente compatível | Validar grants e retenção |
| Platform admin | `server/db/platform-admin.ts`, router platform | acesso elevado controlado por aplicação | Não concluído | Definir explicitamente bypass/admin e testar isolamento |
| Costing engine | `server/domain/costing/engine.ts` | `BigInt`, frações exatas, serialização decimal | Aprovado em unidade | Integrar com banco e frontend |
| Costing persistence | `server/db/costing.ts` | transações, snapshot server-side, `cost_calculations` imutável | Compatível por código | Executar migration 0036 em banco descartável |
| Costing RLS | `drizzle/pg/rls_multitenant.sql` e contratos | 7 tabelas, authenticated/app_runtime, tenant predicate | Compatível por SQL estático | Prova real de SELECT/INSERT/UPDATE/DELETE cross-tenant |
| Costing frontend | somente permissão no `WorkspaceContext` localizada | deveria haver página/hooks e fluxo UI | Não evidenciado | Criar/confirmar tela e teste E2E antes de aceite funcional |
| Schemas legados | `drizzle/schema.mysql.ts`, `drizzle/` | MySQL/TiDB: backticks, enums, unsigned, AUTO_INCREMENT | Incompatível com execução PG direta | Converter ou retirar do caminho oficial |
| Migrations PG | `drizzle/pg/*.sql` | SQL PG, funções, RLS, duplicidades numéricas | Não linear/ não homologada | Reconciliação e baseline autoritativo |
| ETL/staging | `mysql2`, `migrate-tidb-to-supabase.mjs` | origem MySQL/TiDB e destino PG | Deliberadamente híbrido | Isolar como ferramenta de migração, não runtime |

## Critério de leitura

“Compatível por camada” significa que o código ou SQL usa APIs PostgreSQL coerentes, não que a instalação ou fluxo completo foi provado. “Aprovado em unidade” significa apenas que os testes locais correspondentes passaram. “Não homologado” prevalece enquanto não houver bootstrap vazio e testes integrados.

## Módulos registrados no appRouter

`admin`, `evolution`, `evolutionStats`, `secretary`, `operations`, `platform`, `system`, `auth`, `workspace`, `crm`, `inbox`, `kanban`, `ai`, `knowledge`, `settings`, `automations`, `whatsappConfig`, `budgets`, `catalog`, `sellers`, `routes`, `costing` e `clients`.

## Evidência executada nesta rodada

- `pnpm check`: sucesso.
- `pnpm vitest run server/domain/costing/engine.test.ts server/domain/costing/snapshot.test.ts server/routers/costing.test.ts server/pg-schema-conversion.contract.test.ts`: 4 arquivos, 47 testes aprovados.
- Nenhum banco persistente acessado; nenhuma migration executada.
