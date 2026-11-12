# Entrega 3B.1.10 — Relatório consolidado de segurança do Alianza Costing

## Resultado executivo

**Status: CORREÇÕES LOCAIS CONCLUÍDAS; NÃO LIBERADO PARA STAGING OU PRODUÇÃO.** A implementação Costing foi auditada na branch `costing-security-preflight-final-20261112`, criada a partir do SHA `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` da implementação mais completa da branch `feature/alianza-costing-foundation-20261110`. O commit desta etapa é `09e459540186efaeaef12246e797254a44d58d27`.

Nenhuma conexão com Supabase, staging remoto ou produção foi aberta. Nenhuma migration foi executada fora de PostgreSQL local descartável. Não houve push, merge, rebase ou alteração da `main`.

## Alterações implementadas

1. `scripts/apply-supabase-rls.mjs` agora faz preflight fail-closed antes de criar o cliente PostgreSQL. Valida ambiente declarado, URL pública Supabase, project ref e host real do banco. `production` é sempre recusado; `local` aceita somente `localhost`, `127.0.0.1` ou `::1`; `staging` exige par explícito de project ref e hostname em allowlist de código. Não existe override por variável de ambiente.
2. A allowlist efetiva de staging permanece vazia. O repositório contém apenas a referência pública de produção `butpqbcnjdxlwwgnoqsa`; não foi encontrado um project ref/host de homologação verificável. O comportamento seguro é recusar staging remoto até aprovação explícita em código.
3. O RLS canônico foi ampliado para as sete tabelas Costing: `cost_groups`, `cost_items`, `cost_structures`, `cost_structure_lines`, `cost_calculations`, `costing_gamma_settings` e `costing_gamma_groups`. Todas recebem `ENABLE/FORCE ROW LEVEL SECURITY` e políticas por `organizationId`.
4. Grants do `app_runtime` são mínimos: CRUD tenant-scoped para catálogos/configuração/estruturas; `cost_calculations` permite apenas `SELECT` e `INSERT`. A imutabilidade continua protegida pelo trigger da migration `0036_costing_foundation.sql`.
5. Helpers `SECURITY DEFINER` passam a usar `search_path = ''`; objetos persistentes estão qualificados. O helper de identidade usa `request.app_user_id` somente quando `session_user = 'app_runtime'`; sessões `authenticated` dependem de `auth.uid()`. Isso impede impersonação por GUC de cliente.
6. O script RLS aplica, quando existentes, o mesmo hardening às funções históricas de convite, budgets, revogação de sessão e restrição de e-mail, sem reescrever migrations históricas.
7. Foram adicionados oito testes do preflight, além dos contratos RLS/contexto atualizados.

## Evidências executadas

| Verificação | Resultado |
|---|---:|
| Preflight positivo/negativo, incluindo ausência de abertura de conexão | 8/8 PASS |
| Contratos RLS, identidade e app_runtime | 32/32 PASS |
| Engine, snapshots e router Costing | 46/46 PASS |
| TypeScript (`pnpm check`) | PASS |
| Prettier nos arquivos alterados | PASS |
| PostgreSQL local: migration Costing + RLS | PASS |
| Reexecução do RLS para idempotência | 2/2 PASS |
| Isolamento tenant A/B via `auth.uid()` | PASS |
| JWT ausente sem linhas visíveis | PASS |
| Isolamento da role `app_runtime` | PASS |
| `cost_calculations`: select/insert sim; update/delete não | PASS |
| `anon` sem privilégio de leitura Costing | PASS |

O harness PostgreSQL usou apenas dados artificiais, cluster descartável, roles locais e socket/porta local. O resultado final foi `costing-install-rls-idempotence-isolation-identity-ok`.

A suíte geral executou **842 testes: 840 aprovados e 2 falhas ambientais preexistentes**: `server/supabase-server-client.contract.test.ts` sem configuração pública Supabase no sandbox e `server/app-runtime-password.contract.test.ts` retornando 503 por dependência de runtime externo. Nenhuma das duas falhas está relacionada ao Costing/RLS/preflight; elas não foram mascaradas nem corrigidas fora do escopo.

## Pendências e bloqueios

- **Staging real:** bloqueado até alguém fornecer e aprovar em revisão de código o project ref e os hosts PostgreSQL de staging. Não usar `SUPABASE_DATABASE_URL` de produção como staging.
- **Journal de migrations:** `drizzle/pg/meta/_journal.json` registra somente `0000` e `0001`, enquanto existem SQLs até `0036`. Portanto não há evidência de uma cadeia histórica completa aplicável automaticamente; isto permanece bloqueio de instalação, não foi inventado nem corrigido por reordenação.
- **Produção:** recusada pelo preflight e não acessada.
- **Suíte geral:** as duas falhas ambientais listadas devem ser resolvidas no ambiente de CI/runtime antes de declarar a suíte global verde.

## Proveniência e integridade

- Repositório da aplicação: `joaovictorsotog-create/alianza-ai-platform`.
- Base auditada: `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285`.
- Commit final desta etapa: `09e459540186efaeaef12246e797254a44d58d27`.
- Branch de trabalho: `costing-security-preflight-final-20261112`.
- Branch Boost documental: `entrega-3b1-9-correcoes-auditoria`, HEAD `4ab242c` antes deste pacote.
- Working tree da aplicação ficou limpa após o commit; nenhum segredo, credencial ou dado de produção foi incluído.
- O patch completo e as fontes exatas do commit estão no pacote independente `alianza-costing-security-audit-package-09e4595`.
