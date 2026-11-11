# Revisão final — Costing Verification Round

## Proveniência

- SHA-base: `0fe7df0bcd6412b90bd3bd1d5be2341a7408fb69`
- SHA final local: `357fc3226dc784964679c6ce611eaee2f0f9d76b`
- Pai do SHA final: `0fe7df0bcd6412b90bd3bd1d5be2341a7408fb69`
- Branch local: `costing-final-verification-20261111`
- Working tree: limpa
- Push da aplicação: não realizado

## Matriz de revisão

| Item | Estado | Evidência |
|---|---|---|
| Trigger de imutabilidade de estruturas publicadas | APROVADO | Provas SQL e harness Costing completo |
| Lock da estrutura destino no INSERT | APROVADO | `insert-mutation` e `insert-publication`, PIDs distintos |
| Lock source/destination no UPDATE | APROVADO | `update-*` e `move-*`, duas ordens |
| DELETE de linha em estrutura publicada | APROVADO | `delete-publication` rejeitado pelo trigger |
| Movimentação entre estruturas | APROVADO | `move-mutation` publicou a movimentação; ordem inversa rejeitou sem alteração |
| Estado final sem parcialidade | APROVADO | Consulta direta de estruturas e linhas em cada caso |
| Publicação concorrente pela função real | APROVADO | Dois workers independentes chamando `publishCostStructure` |
| Publicações do mesmo item | APROVADO | Chamadas serializadas; exatamente uma ACTIVE, histórico SUPERSEDED |
| Publicações de itens diferentes | APROVADO | Dois PIDs, intervalos temporais sobrepostos e ambas ACTIVE |
| Rollback de mutação rejeitada | APROVADO | Transação mutadora rollback após erro do trigger |
| Rollback de `createCostStructure` | APROVADO | Harness Costing completo: `rollback: ok` |
| Ausência de deadlock não tratado | APROVADO | Harness concluído sem timeout na execução final |
| Sequência Drizzle `0036–0038` | APROVADO | Runner real em banco descartável, cinco hashes e tabelas verificadas |
| Segunda execução pelo journal | APROVADO | Nenhum hash adicional na segunda execução |
| Schema Costing carregado pelo config | APROVADO | `drizzle-kit check` passou com schema array |
| Regras de cálculo, Gama e arredondamento | APROVADO | 52/52 testes direcionados e harness completo |
| RLS, roles, grants e policies | NÃO COMPROVADO | Fora do escopo autorizado; não foram alterados |
| Reconciliação de todas as migrations PG `0002–0035` | NÃO COMPROVADO | Journal histórico permanece parcial; documentado no relatório de migrations |
| Rollback de uma chamada de serviço artificialmente forçada a falhar após lock | NÃO COMPROVADO | A corrida real observada foi serializada com sucesso; o harness existente cobre rollback de criação |

## Testes

- TypeScript: aprovado.
- Testes Costing direcionados: 52/52 aprovados.
- Harness PostgreSQL final: aprovado.
- Harness Costing completo: aprovado, incluindo concorrência, lifecycle, triggers e rollback.
- Prettier: aprovado nos ficheiros suportados.
- Sintaxe shell: aprovada.
- `git diff --check`: aprovado.
- Suíte geral: 837/839 testes aprovados; as duas falhas externas conhecidas continuam:
  - `server/app-runtime-password.contract.test.ts`
  - `server/supabase-server-client.contract.test.ts`

## Parecer

Não foram encontrados defeitos críticos ou altos nos locks, triggers, mutações de linhas, publicação concorrente ou sequência Costing `0036–0038` após a correção. A branch local está pronta para auditoria documental, mas esta conclusão não autoriza integração, RLS, produção ou deploy.
