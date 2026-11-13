# Inventário de objetos PostgreSQL — Alianza

## Arquivos e configurações

- 41 arquivos SQL em `drizzle/pg`: 40 arquivos numerados de `0000` a `0036`, além de `rls_multitenant.sql`.
- `drizzle/pg/meta/_journal.json`: somente entradas `0000` e `0001`.
- Snapshots: `0000_snapshot.json` e `0001_snapshot.json`.
- Schemas auxiliares: `schema.budgets.ts`, `schema.catalog.ts`, `schema.costing.ts`, `schema.inbound-media-materializations.ts`.
- Schema geral: `drizzle/schema.pg.ts`.
- Config principal: `drizzle.config.ts`, dialect MySQL, schema `drizzle/schema.mysql.ts`, saída `./drizzle`.
- Config PG: `drizzle.pg.config.ts`, dialect PostgreSQL, schema `drizzle/schema.pg.ts`, saída `./drizzle/pg`.

## Contagens estáticas dos SQLs

As contagens abaixo são nomes distintos extraídos lexicamente dos arquivos, com comparação case-insensitive; não são objetos confirmados em um banco:

| Tipo | Nomes distintos | Ocorrências |
|---|---:|---:|
| Tabelas | 61 | 79 |
| Índices | 128 | 140 |
| Foreign-key/constraints `ADD CONSTRAINT` | 114 | 114 |
| Funções criadas diretamente | 7 | 11 |
| Triggers criados diretamente | 2 | 2 |
| Policies explícitas | 55 | 69 |
| Enums PostgreSQL explícitos | 0 | 0 |

A contagem de tabelas inclui módulos gerais, budgets, catalog, inbound media e as sete tabelas Costing; ocorrências duplicadas decorrem de `IF NOT EXISTS`, variantes históricas e arquivos sobrepostos.

## Costing

`0036_costing_foundation.sql` define sete tabelas:

1. `cost_groups`;
2. `cost_items`;
3. `cost_structures`;
4. `cost_structure_lines`;
5. `cost_calculations`;
6. `costing_gamma_settings`;
7. `costing_gamma_groups`.

Também define índices tenant-scoped, constraints compostas, status de estrutura, quantidade positiva, unicidade de uma estrutura ACTIVE por item, função `prevent_cost_calculation_update()` e trigger de imutabilidade.

A dependência primária externa é `organizations`; as tabelas Costing também formam a cadeia grupo → item → estrutura/linhas → cálculo, com configurações e grupos Gama.

## Objetos históricos e faltantes

- `0021_budgets.sql` cria `budgets` e `budget_items`, mas o parser de inventário anterior não os contou por diferença de capitalização (`create table` minúsculo); eles existem no arquivo.
- `schema.budgets.ts` e `schema.catalog.ts` existem, mas suas tabelas não estão representadas de modo completo na cadeia `0036`; devem ser conciliadas com os SQLs históricos.
- A migration `0022_catalog.sql` é um arquivo histórico que precisa ser inspecionado na reconstrução; não se deve inferir sua aplicação a partir da existência do arquivo.
- `public.rls_auto_enable()` é revogada em `0002` e no RLS global, mas nenhuma definição `CREATE FUNCTION` foi localizada nos arquivos auditados.

## SECURITY DEFINER

Funções históricas usam `set search_path = public` ou, em um caso, `pg_catalog`:

- `private.has_organization_access` — `public` em `0003`;
- `private.accept_organization_invitation` — `public` em `0017`, `0025`, `0026`;
- `private.enforce_allowed_auth_email` — sem `set search_path` local em `0019`;
- `private.has_budget_organization_access` — `public` em `0021`;
- `private.is_supabase_session_active` — `pg_catalog` em `0034`.

O payload global tenta endurecer funções existentes para `search_path = ''`, mas isso ocorre somente se o bloco global for executado. Portanto, o histórico isolado não satisfaz o requisito de que todas as funções `SECURITY DEFINER` estejam com search path vazio.

## Dependências externas

- `auth.uid()` e infraestrutura de autenticação Supabase;
- roles `anon`, `authenticated` e `app_runtime`;
- pooler Supabase e project ref;
- `public.users`, `organization_members`, `organizations`;
- schema `private` e helpers históricos;
- permissões e funções condicionais existentes no banco.

Este inventário é estático. Não prova que nenhum objeto exista em um banco remoto e não autoriza execução.
