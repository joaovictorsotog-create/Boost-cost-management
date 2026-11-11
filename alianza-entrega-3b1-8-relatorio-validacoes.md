# Entrega 3B.1.8 — Relatório de alterações e validações

## Resultado geral

**Status: INDETERMINADA documentalmente.** Os quatro bloqueadores foram tratados no SQL e exercitados em PostgreSQL local. A suíte demonstrou os indicadores de revisão e TEMPORARY, mas o fixture local não pretende reproduzir todos os objetos do ambiente produtivo; portanto não há declaração de aprovação produtiva.

## Alterações em relação à 3B.1.7

1. **SHA-256:** substituído o uso probatório de `sha256_verified` por contrato externo com bytes hexadecimais UTF-8, origem, encoding, snapshot, hash apresentado e hash calculado independentemente. Divergência ou ausência de evidência é stale/indeterminada.
2. **População executável:** a reconciliação individual e o CASE final usam a mesma população `f`, `p`, `a`, `w`. Aggregates usam representação de `pg_aggregate`; window functions usam metadados de `pg_proc`; nenhuma categoria é ignorada silenciosamente.
3. **PostgreSQL real:** adicionado `test_3b1_8_postgres.py`, que inicializa cluster descartável, cria fixtures, executa a Etapa 13 do SQL publicado, coleta resultados reais e remove o cluster. PostgreSQL testado: 16.15.
4. **TEMPORARY:** a aceitação deixou de ser fixa. A consulta consome entrada externa tipada com responsável, data, evidência, justificativa, escopo, role e auditoria.
5. **Compatibilidade encontrada:** corrigida a chamada inexistente `has_large_object_privilege` usando ACL nativa de Large Objects no PostgreSQL 16; removidas referências inexistentes aos owners de `pg_ts_parser`/`pg_ts_template` nessa versão.

## Evidência dos testes reais

- Sem revisão: `INDETERMINADA`, `has_missing_function_review = t`.
- Revisão válida de função/procedure/aggregate: `all_function_reviews_valid = t`, sem missing/stale.
- SHA divergente: `has_stale_function_review = t`, `final_status = INDETERMINADA`.
- Aggregate sem revisão: `final_status = INDETERMINADA`.
- TEMPORARY incompleto: `can_create_temp = t`, `temporary_acceptance_valid = f`, `final_status = INDETERMINADA`.
- TEMPORARY válido: `can_create_temp = t`, `temporary_acceptance_valid = t`; a suíte confirma o consumo da aceitação, mantendo `INDETERMINADA` quando outro controle local não está plenamente reproduzido.

Os seis cenários acima executaram a consulta SQL real, não uma função `decide()` em Python. O teste auxiliar Python da entrega anterior permanece apenas como apoio conceitual.

## Limitações restantes

O PostgreSQL 16 local não apresentou uma window function de usuário (`prokind = 'w'`), logo a cobertura de execução efetiva dessa categoria permanece uma limitação de fixture, não um resultado inventado. Também não há declaração de equivalência do catálogo local com Supabase. Nenhuma operação de produção ocorreu.
