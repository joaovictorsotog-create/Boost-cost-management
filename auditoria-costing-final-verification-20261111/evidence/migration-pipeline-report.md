# Auditoria do pipeline PostgreSQL e migrations Costing

## Defeito encontrado antes da correção

A configuração `drizzle.pg.config.ts` apontava apenas para `./drizzle/schema.pg.ts`. O schema Costing, em `./drizzle/pg/schema.costing.ts`, não era carregado pelo Drizzle Kit.

O journal `drizzle/pg/meta/_journal.json` continha somente as entradas `0000_eminent_mathemanic` e `0001_pink_pete_wisdom`, embora os ficheiros `0036_costing_foundation.sql`, `0037_costing_correction_integrity.sql` e `0038_costing_final_stabilization.sql` existissem. A prova em PostgreSQL descartável mostrou que o runner reportava sucesso, gravava apenas dois hashes e não criava nenhuma tabela `cost_*`.

## Correção aplicada

- `drizzle.pg.config.ts` passou a carregar os dois schemas:
  - `./drizzle/schema.pg.ts`
  - `./drizzle/pg/schema.costing.ts`
- O journal recebeu, em ordem, as entradas:
  1. `0036_costing_foundation`
  2. `0037_costing_correction_integrity`
  3. `0038_costing_final_stabilization`
- Não foram alteradas migrations históricas anteriores nem o banco remoto.

## Prova do runner real

Em um PostgreSQL descartável vazio, usando `drizzle-kit migrate --config drizzle.pg.config.ts`:

| Execução | Resultado |
|---|---|
| Primeira | Cinco hashes aplicados: `0000`, `0001`, `0036`, `0037`, `0038` |
| Segunda | Nenhum hash adicional; o journal impediu reaplicação |
| Schema final | As oito tabelas Costing foram criadas, incluindo `cost_structure_version_counters` |
| Índices | Índice parcial de uma estrutura `ACTIVE` por item presente |
| Configuração | `drizzle-kit check` passou |

As mensagens PostgreSQL de `DROP TRIGGER IF EXISTS` na primeira execução são notices esperados, não falhas.

## Ordem comprovada

```text
0000_eminent_mathemanic
  -> 0001_pink_pete_wisdom
    -> 0036_costing_foundation
      -> 0037_costing_correction_integrity
        -> 0038_costing_final_stabilization
```

## Limitação explicitamente preservada

O journal global PostgreSQL ainda não registra as migrations históricas `0002`–`0035`, apesar de existirem ficheiros SQL correspondentes. Esta rodada corrigiu e comprovou a trilha necessária de Costing `0036–0038`; não declara que toda a história PostgreSQL do projeto esteja reconciliada. A reconciliação global permanece uma pendência separada, conforme o plano de migração do projeto.
