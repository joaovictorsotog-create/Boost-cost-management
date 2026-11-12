# Entrega 3B.1.11 — Matriz completa de tabelas Costing e RLS

Fonte direta: `drizzle/pg/schema.costing.ts`, `drizzle/pg/0036_costing_foundation.sql`, `drizzle/pg/rls_multitenant.sql` e `server/supabase-rls.contract.test.ts` no commit `16fde337f707734fbca13ac311f1ebe2d01a2472`.

| # | Nome exato | Finalidade | ENABLE | FORCE | Policies | Grants authenticated | Grants app_runtime | UPDATE/DELETE | Justificativa |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | `cost_groups` | Cadastro tenant-scoped de grupos de itens | Sim | Sim | `costing_tenant_read` SELECT; `costing_app_runtime_insert`, `_update`, `_delete` | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos apenas com policy tenant-scoped | Parte do schema Costing; CRUD necessário |
| 2 | `cost_items` | Itens simples/compostos, grupo, unidade e custo manual | Sim | Sim | Mesmo conjunto; todas verificam `private.has_organization_access("organizationId")` | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos apenas com policy tenant-scoped | Base do cálculo e do catálogo |
| 3 | `cost_structures` | Versões de estruturas e estado de publicação | Sim | Sim | Mesmo conjunto tenant-scoped | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos no tenant; publicação adicionalmente transacional | Contém DRAFT/ACTIVE/SUPERSEDED/INACTIVE |
| 4 | `cost_structure_lines` | Linhas de consumo das estruturas | Sim | Sim | Mesmo conjunto tenant-scoped | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos no tenant | Necessária para composição |
| 5 | `cost_calculations` | Resultado e snapshot imutável do cálculo | Sim | Sim | `costing_tenant_read` SELECT; `costing_app_runtime_insert` INSERT | SELECT | SELECT, INSERT | Não há grant/policy de UPDATE/DELETE; trigger `cost_calculations_immutable` bloqueia ambos | Evidência histórica do cálculo; deve ser append-only |
| 6 | `costing_gamma_settings` | Ativação e percentual da Gama por organização | Sim | Sim | Mesmo conjunto tenant-scoped | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos no tenant | Configuração organizacional da Gama |
| 7 | `costing_gamma_groups` | Seleção de grupos que formam a base da Gama | Sim | Sim | Mesmo conjunto tenant-scoped | SELECT | SELECT, INSERT, UPDATE, DELETE | Permitidos no tenant | Configuração tenant-scoped vinculada a `cost_groups` |

## Regras comuns observadas

- `anon` e `authenticated` recebem `REVOKE ALL` no bloco Costing antes dos grants explícitos; `authenticated` recebe somente SELECT.
- `app_runtime` recebe SELECT/INSERT em todas as sete tabelas.
- UPDATE/DELETE são concedidos ao `app_runtime` somente nas seis tabelas diferentes de `cost_calculations`.
- Todas as policies Costing usam `organizationId`; não há policy global por ID isolado.
- `cost_calculations` possui ainda proteção de trigger na migration, além da ausência de grants/policies de alteração.
- `organizations` não é tabela Costing. É uma tabela central referenciada por foreign keys e protegida por suas próprias regras; não deve ser contada como oitava tabela Costing.
- Não foi encontrada oitava tabela declarada no schema Drizzle, na migration Costing, no bloco RLS Costing ou no contrato de teste.
