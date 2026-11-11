# Fluxo integrado Costing

Esta evidência distingue testes de domínio/DB de um E2E HTTP real.

## Executado em banco descartável

- criação e lifecycle DRAFT de estruturas;
- inclusão, atualização e exclusão de linhas;
- cálculo exato e Gamma;
- snapshots persistidos e append-only;
- rollback após reserva de versão;
- versões vazia, existente e não contígua;
- dez criações concorrentes;
- publicação concorrente do mesmo item e de itens independentes;
- corridas INSERT/UPDATE/DELETE/MOVE contra publicação;
- triggers de imutabilidade;
- RLS A/B entre duas organizações;
- operações cross-tenant negadas.

## Executado com mocks

- router exige `costing.read` para leitura/cálculo/snapshot;
- router exige `workspace.manage` para grupos, itens, estruturas, linhas e publicação;
- organização enviada pelo cliente é validada por `requireTenantPermission`;
- criação de grupo/item e ativação de item são encaminhadas ao serviço correto;
- IDs de outra organização são rejeitados pelo boundary de autorização.

## Não executado

- login real via Supabase Auth;
- request HTTP completo do frontend ao router e ao PostgreSQL;
- autenticação real com `auth.uid()` em projeto Supabase;
- edição real de grupo/item/preço através de uma UI;
- fluxo completo de produção ou homologação remota.

Os estados acima são limitações deliberadas da rodada de auditoria. Não foram
convertidos em alegações de E2E.
