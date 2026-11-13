# Alianza Costing — Matriz de migrations PostgreSQL

## Inventário observado

| Grupo | Arquivos observados | Estado |
|---|---:|---|
| SQL PostgreSQL em `drizzle/pg` | 38 | COMPROVADO |
| Journal PostgreSQL | 2 entradas (`0000`, `0001`) | COMPROVADO |
| Snapshots PostgreSQL em `drizzle/pg/meta` | `0000_snapshot.json`, `0001_snapshot.json` | COMPROVADO |
| SQL Costing | `0036_costing_foundation.sql` | COMPROVADO |
| RLS global | `rls_multitenant.sql` fora do journal | COMPROVADO |
| Configuração Drizzle PG | `drizzle.pg.config.ts`, schema `drizzle/schema.pg.ts` | COMPROVADO |

## Sequência de nomes

```text
0000, 0001, 0002, 0003, 0004, 0005, 0006,
0007 (inbound_media_materializations_local_only),
0007 (inbound_media_materializations_rls_local_only),
0008, 0009, 0010, 0011, 0012, 0013, 0014, 0015,
0017, 0018, 0019, 0020,
0021 (budgets),
0021 (production_schema_consolidation),
0022, 0023, 0024, 0025, 0026,
0027 (budget_revoked),
0027 (catalog_product_description),
0028, 0029, 0030, 0031,
0032 (catalog_tenant_category_isolation),
0032 (restore_scheduler_columns),
0033, 0034, 0035, 0036
```

### Anomalias

- O número `0016` não aparece.
- Os números `0007`, `0021`, `0027` e `0032` aparecem duas vezes.
- O journal não contém nenhuma entrada para `0002`–`0036`.
- Não há snapshot/meta correspondente aos SQLs posteriores a `0001`.
- O SQL `rls_multitenant.sql` é um runner/payload operacional separado e não aparece no journal.

Essas anomalias impedem declarar que `drizzle-kit migrate` instalará a coleção completa em um banco vazio. Não foram criadas entradas artificiais, não foram renumerados arquivos e nenhum SQL foi marcado como aplicado.

## Migrations relevantes para Costing

| Arquivo | Papel | Dependências | Status |
|---|---|---|---|
| `0000_eminent_mathemanic.sql` | baseline de tabelas Alianza, incluindo `organizations`, `users`, `organization_members` e demais tabelas | nenhuma migration anterior observada | COMPROVADO como arquivo base |
| `0001_pink_pete_wisdom.sql` | adiciona `users.supabaseAuthId` e unique | `users` de `0000` | COMPROVADO |
| `0002`–`0035` | hardening, módulos e alterações históricas de schema/RLS | varia por arquivo; não journalizados | PENDENTE de reconciliação |
| `0036_costing_foundation.sql` | sete tabelas Costing, FKs compostas, índices, trigger de snapshot | `organizations`, `cost_groups`, `cost_items`, `cost_structures` em cadeia | COMPROVADO estaticamente |
| `rls_multitenant.sql` | payload global de RLS e grants; inclui Costing | baseline amplo, `auth.uid()`, helpers e roles | NÃO é migration Costing-only |

## Verificação de bootstrap

Foi tentada uma verificação controlada, sem banco persistente, mas a sessão atual não possui os binários `initdb`/`pg_ctl`; portanto não foi possível executar o bootstrap local nesta rodada. O resultado é **BLOQUEADO**, não PASS.

Mesmo com PostgreSQL disponível, o teste deve ser precedido pela reconciliação do journal: o estado atual não oferece evidência suficiente para escolher uma sequência histórica sem risco de omitir SQLs ou aplicar duas variantes do mesmo número.

## Sequência tecnicamente recomendada, ainda não executada

1. Obter/confirmar o baseline PostgreSQL oficial correspondente ao `0000` e `0001`.
2. Reconciliar os SQLs `0002`–`0035` com histórico de aplicação verificável e produzir uma decisão de versionamento, sem renumerar retroativamente.
3. Em cluster descartável, instalar o baseline reconciliado.
4. Aplicar `0036_costing_foundation.sql` em transação controlada.
5. Verificar tabelas, FKs compostas, índices e trigger.
6. Aplicar uma estratégia RLS separada e revisada; não usar o payload global para alegar isolamento Costing-only.
7. Registrar a sequência e hashes no repositório documental antes de qualquer ambiente persistente.
