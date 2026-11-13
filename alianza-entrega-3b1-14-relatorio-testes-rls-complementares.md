# Entrega 3B.1.14 — Ajuste final de evidência RLS Costing

## Proveniência e escopo

Aplicação: branch `costing-security-preflight-final-20261112`, SHA `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`, working tree limpa e não alterada nesta rodada.

Documentação: `joaovictorsotog-create/Boost-cost-management`, branch `entrega-3b1-9-correcoes-auditoria`, ajustada somente em novo commit documental derivado de `2afaf36d73d54e1c936efff1076b40aa026fb502`.

Não houve push da aplicação, PR, merge, rebase, cherry-pick, deploy, conexão Supabase/produção ou alteração de migration/SQL de produção.

## Execução

O harness foi executado com Bash em PostgreSQL 16 descartável. As conexões de runtime foram abertas diretamente com `-U app_runtime`, sem `SET ROLE`. O log integral está em `alianza-entrega-3b1-14-evidencias-rls-complementares.log`.

A sessão registrou `session_user=app_runtime` e `current_user=app_runtime`. As fixtures são artificiais, isoladas e contêm uma linha válida por organização em cada uma das sete tabelas Costing.

## INSERT cruzado — evidência atribuível a RLS

Cada INSERT possui fixture própria, identificador exclusivo e referências estrangeiras válidas. O bloco captura `RETURNED_SQLSTATE` e `MESSAGE_TEXT`; somente é aceito como PASS quando `SQLSTATE=42501` e a mensagem contém `row-level security policy`. Qualquer outro SQLSTATE ou mensagem faria o harness falhar, sem conversão em sucesso.

| Tabela | Organização da sessão | SQLSTATE | Mensagem/origem | Resultado |
|---|---|---:|---|---|
| `cost_groups` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `cost_items` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `cost_structures` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `cost_structure_lines` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `cost_calculations` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `costing_gamma_settings` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |
| `costing_gamma_groups` | A insere B | `42501` | `new row violates row-level security policy` | PASS — RLS |

Resultado: `runtime_cross_insert_all_seven=ok` e `cross_insert all_seven blocked_by_rls`.

## Transferência A→B — origem diferenciada

Antes de cada UPDATE, o harness confirmou que o registro da organização A estava visível para `app_runtime`. Cada comando alterou somente `organizationId`.

| Tabela | Fixture A visível | SQLSTATE | Origem observada | Resultado |
|---|---:|---:|---|---|
| `cost_groups` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |
| `cost_items` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |
| `cost_structures` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |
| `cost_structure_lines` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |
| `cost_calculations` | 1 | `42501` | `permission denied for table cost_calculations` | PASS — privilégio ausente; não é prova isolada de RLS |
| `costing_gamma_settings` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |
| `costing_gamma_groups` | 1 | `42501` | mensagem de row-level security policy | PASS — RLS |

Resultado: `runtime_org_transfer_updates_blocked=ok` e `transfer_update all_seven blocked_with_origin`.

## Outros controles preservados

O harness também repetiu isolamento de leitura A/B nas sete tabelas (`own=1`, `other=0`), UPDATE/DELETE cruzado, identidade via `auth.uid()`, adulteração de `request.app_user_id`, sessão sem JWT, bloqueio de `anon`, aplicação RLS idempotente e imutabilidade dos snapshots. Os bloqueios de `cost_calculations` por UPDATE/DELETE continuam documentados separadamente como ausência de privilégio.

## Conclusão

Os sete INSERTs cruzados são comprovadamente rejeitados pela policy `WITH CHECK`. Seis transferências A→B são comprovadamente rejeitadas pela camada RLS; `cost_calculations` é rejeitada pelo privilégio ausente e não é apresentada como prova isolada de RLS. Não há falsos positivos por constraint, duplicidade, fixture inválida ou erro genérico mascarado.
