# Plano técnico recomendado para bootstrap PostgreSQL

## Fase 0 — Congelamento

1. Fixar os refs remotos auditados e seus SHAs.
2. Preservar os SQLs históricos sem renomear ou alterar.
3. Classificar cada objeto em baseline, migration incremental, compatibilidade Supabase ou operação.

## Fase 1 — Baseline autoritativo

4. Reconstituir o schema PostgreSQL completo a partir dos SQLs e schemas, incluindo tabelas gerais, budgets, catalog, inbound media e Costing.
5. Resolver diferenças de tipos/nomenclatura entre `schema.pg.ts`, schemas auxiliares e SQLs.
6. Definir todos os objetos `SECURITY DEFINER` com `search_path = ''`, qualificando referências a `pg_catalog`, `public` e `private`.
7. Remover dependência implícita de `public.rls_auto_enable()` ou definir explicitamente seu contrato em uma decisão separada.
8. Registrar o baseline e seu manifesto SHA-256.

## Fase 2 — RLS por escopo

9. Separar o RLS Costing em um arquivo/runner explicitamente Costing-only.
10. Manter um runner global separado para os módulos gerais, com pré-condições declaradas.
11. Validar `authenticated` e `app_runtime`, sem grants para `anon` fora de decisão explícita.
12. Confirmar `FORCE ROW LEVEL SECURITY`, policies tenant-scoped, grants e impossibilidade de bypass.
13. Verificar imutabilidade de `cost_calculations` e coerência de todos os SECURITY DEFINER.

## Fase 3 — Teste descartável

14. Usar ambiente com `initdb`, `pg_ctl`, `postgres` ou equivalente autorizado.
15. Criar cluster vazio.
16. Aplicar o baseline em transação controlada.
17. Aplicar incremental Costing.
18. Verificar catálogo PostgreSQL: tabelas, constraints, índices, funções, triggers, policies, grants e roles.
19. Criar duas organizações e identidades artificiais.
20. Testar leitura/escrita cruzada com `authenticated` e `app_runtime`.
21. Rejeitar UPDATE/DELETE de snapshots.
22. Destruir o cluster após registrar logs e hashes.

## Fase 4 — Integração futura

23. Executar migrations somente com configuração PostgreSQL explícita.
24. Atualizar o journal de maneira gerada e verificável, sem fabricar aplicação histórica.
25. Testar o backend Costing e, quando existir, o fluxo frontend.
26. Só depois planejar merge com `main`.

## Critérios de aceite

- instalação completa em banco vazio executada com sucesso;
- sequência e hashes reproduzíveis;
- nenhum objeto referenciado sem definição;
- zero `SECURITY DEFINER` sem `search_path = ''`;
- `rls_auto_enable()` resolvida ou removida de forma documentada;
- Costing isolável sem aplicar RLS global;
- isolamento entre duas organizações comprovado para as roles previstas;
- nenhum segredo ou banco persistente usado;
- logs do bootstrap e catálogo final armazenados como evidência.
