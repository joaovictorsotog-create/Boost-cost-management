# Contador, locks e publicação — análise final

## Contador

O contador `cost_structure_version_counters` representa sempre a **próxima versão disponível**.

A migration `0038_costing_final_stabilization.sql` reconcilia linhas existentes com `MAX(version)+1` usando `GREATEST`, de forma idempotente.

A reserva ocorre na mesma transação da criação:

1. bloqueia o item com `SELECT ... FOR UPDATE`;
2. insere a linha do contador com `MAX(version)+1` usando `ON CONFLICT DO NOTHING`;
3. incrementa uma vez a linha do contador;
4. retorna `nextVersion - 1` como a versão alocada;
5. insere a DRAFT;
6. confirma tudo na mesma transação.

Assim, para um item sem estruturas, a linha inicial é `nextVersion=1`, a reserva deixa `nextVersion=2` e retorna versão `1`. Para um item com versões `1..4`, a migration deixa `nextVersion=5`, a reserva retorna `5` e deixa `nextVersion=6`.

Não há mais o incremento duplo que produzia a sequência artificial `7..16`.

## Casos exercitados

O harness executou e validou:

- item sem estruturas: versão `1`;
- item com versão `1`: versão `2`;
- item com versões `1..4`: versão `5` no fluxo principal e próxima versão `6`;
- item com versões não contíguas `1` e `3`: versão `4`;
- contador já existente: contador anterior `6` antes das dez criações;
- dez criações concorrentes no mesmo item: versões `6..15`;
- cinco criações em outro item da mesma organização;
- cinco criações em item de outra organização;
- rollback artificial do contador;
- falha forçada depois da reserva dentro de `createCostStructure`;
- repetição após rollback: versão `2`, sem reutilização ou consumo indevido.

## Resultado final direto no PostgreSQL

```text
target-a      nextVersion 18
target-empty  nextVersion 3
target-gap    nextVersion 5
target-one    nextVersion 3
```

Para `target-a`, o maior `version` materializado era `17`, logo `nextVersion=18`.

## Locks e publicação

A publicação usa `READ COMMITTED` de forma intencional. Primeiro lê o candidato para descobrir o item; depois bloqueia, numa única consulta, o candidato e todas as estruturas `ACTIVE` daquele item, ordenadas por `organizationId`/`id`; só então revalida o status observado após a espera pelos locks.

O trigger de linhas usa `FOR UPDATE` no destino para INSERT, na origem para DELETE e em origem/destino ordenados para UPDATE. Uma tentativa de inserir uma linha enquanto a publicação já bloqueou a estrutura espera, revalida o estado e é rejeitada depois de a estrutura se tornar ACTIVE. Se a linha obtiver o lock primeiro, a linha é confirmada antes da publicação e a publicação ocorre depois dela.

O teste descartável `costing-line-publication-race-pg.ts` usa duas sessões independentes identificadas por `pg_backend_pid()`, uma barreira transacional e testa ambos os resultados:

- linha confirmada antes da publicação: permanece válida na estrutura que depois fica ACTIVE;
- linha iniciada enquanto a publicação detém o lock: é rejeitada após o commit da publicação.

Resultado observado:

```json
{"independentBackendPids":[48921,48922],"lineBeforePublication":"committed-before-publication","lineAfterPublication":"rejected","finalStatuses":["ACTIVE","ACTIVE"],"finalLineCounts":[1,0]}
```

Os PIDs variam por execução; o valor acima pertence à execução final capturada no harness.

## Idempotência

O executor aplica `0038_costing_final_stabilization.sql` duas vezes. A segunda aplicação passou sem erro. A migration utiliza `ON CONFLICT`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS` e recriação determinística do trigger.

A cadeia de migrations Costing `0036`/`0037` é mantida como ficheiros PostgreSQL locais, seguindo a convenção existente deste repositório. A integração da nova migration no mecanismo operacional/journal de produção deve ser confirmada antes de release.
