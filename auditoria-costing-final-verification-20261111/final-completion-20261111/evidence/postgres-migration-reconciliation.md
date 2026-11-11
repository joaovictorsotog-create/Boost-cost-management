# Reconciliação das migrations PostgreSQL

## Resultado

A auditoria read-only da árvore Git encontrou os seguintes SQL PostgreSQL:

- `0000` e `0001` como base efetivamente registada;
- `0002–0015` e `0017–0035` presentes como artefactos históricos;
- `0036–0039` como cadeia Costing registada no journal atual;
- nenhum `0016_*.sql` PostgreSQL autoritativo.

O único ficheiro `0016` encontrado pertence à trilha MySQL/TiDB (`drizzle/0016_lean_ronan.sql`) e não pode ser usado como migration PostgreSQL.

Existem ainda números repetidos com conteúdos distintos: `0007`, `0021`, `0027` e `0032`. Por isso, o número não é uma chave de identidade suficiente para o histórico. Os tags do journal devem ser únicos e não devem ser inventados apenas para preencher uma sequência numérica.

## Prova do comportamento atual

Em PostgreSQL descartável, `drizzle-kit migrate --config drizzle.pg.config.ts` executado duas vezes aplicou seis hashes no journal interno e criou as oito tabelas Costing. A segunda execução foi idempotente. O runner aplica o conteúdo do journal; ele não aplica automaticamente todos os SQL que estão no diretório.

Um ensaio separado que tentou executar os SQL históricos em ordem estrita falhou em `0002_force_rls_and_restrict_event_trigger.sql` porque chama `public.rls_auto_enable()`, mas não existe definição dessa função na árvore local. Isso confirma que os ficheiros presentes não constituem, por si só, uma cadeia bootstrap comprovadamente executável a partir de uma base vazia.

## Decisão de reconciliação

Nenhum SQL foi recriado, renumerado ou atribuído artificialmente a `0016`. As migrations históricas não foram reescritas. A cadeia Costing ficou explicitamente identificada por tags únicas:

`0000 -> 0001 -> 0036 -> 0037 -> 0038 -> 0039`

A `0039_costing_rls_security.sql` é incremental e idempotente. Ela protege as oito tabelas Costing com RLS físico, policies tenant-scoped e grants mínimos.

## Runbook autorizado para ambientes existentes

1. Fazer backup e inspecionar `drizzle.__drizzle_migrations`, tabelas, constraints,
   funções, policies e hashes no ambiente alvo.
2. Comparar o estado real com os SQL históricos; não assumir que o nome numérico
   prova aplicação.
3. Se o ambiente já contém os objetos de `0002–0035`, registar uma baseline
   controlada e aprovada, sem replay cego.
4. Se o ambiente não contém a função ou os objetos exigidos por uma migration,
   interromper e recuperar o SQL de fonte autoritativa antes de prosseguir.
5. Aplicar `0036–0039` em ordem, primeiro em clone/homologação, e validar RLS
   com duas organizações e `app_runtime`.
6. Não aplicar `db:push` como substituto do runner PostgreSQL e não executar
   migrations automaticamente no boot da aplicação.

Para um bootstrap novo, ainda é necessário publicar uma cadeia PostgreSQL
canónica que incorpore apenas SQL histórico comprovado, resolva os tags
duplicados e declare explicitamente a ausência de `0016`. Essa cadeia não deve
ser fabricada a partir de descrições ou de migrations MySQL.

## Estado de aprovação

A reconciliação é **parcial e auditável**: a cadeia Costing e o RLS foram
validados em PostgreSQL descartável; a cadeia histórica pré-Costing não pode
ser declarada bootstrap completo sem recuperar `0016` e a definição autoritativa
de `public.rls_auto_enable()`. Não houve acesso a produção nem execução de
migration remota.
