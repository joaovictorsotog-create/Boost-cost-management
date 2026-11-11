# Entrega 3B.1.9 — Relatório de validações

## Resultado executivo

**Status: INDETERMINADA — NÃO LIBERADA PARA EXECUÇÃO ADMINISTRATIVA.** Os quatro bloqueadores foram corrigidos no plano SQL e a consulta real foi executada localmente. A classificação não é aprovação: o fixture local não reproduz integralmente todos os catálogos/propriedades de um ambiente Supabase e o teste preserva essa incerteza.

## Correções

1. O hash agora está vinculado à representação canônica atual produzida pelo inventário SQL. A consulta compara a representação atual, os bytes UTF-8 atuais e o hash externo esperado/calculado. `sha256_verified` isolado não existe no contrato novo.
2. Functions, procedures, aggregates e window functions possuem representação por categoria. Aggregates incluem os campos de transição, finalização, combinação, serialização, desserialização, transição de estado, tipos e atributos relevantes. Window functions não recebem definição inventada.
3. A interface externa foi expandida para 25 campos, incluindo `canonical_definition`, bytes, encoding, algoritmo, hash esperado, hash calculado e snapshot. A consulta marca duplicidade, registro órfão, incompletude e snapshot divergente.
4. A aceitação TEMPORARY ganhou `snapshot_id`, exige vínculo com `audit_id` revisado e usa `COALESCE` para impedir que NULL avance para aceitação condicional.

## Execução reproduzível

- PostgreSQL: **16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)**.
- Instância: cluster descartável, socket Unix e porta local 55439.
- Consulta: Etapa 13 extraída do SQL publicado, não simulação Python.
- Harness: `test_3b1_9_postgres.py`.
- Resultado: **30 cenários SQL reais PASS**.
- Regressão: suíte Python legada com **15 cenários PASS**.
- Verificações adicionais: `py_compile` e `git diff --check`.

Os 30 casos demonstraram, entre outros, canonical alterada, bytes diferentes, hash esperado/calculado adulterados, identidade, snapshot, duplicidade, registro órfão, incompletude, aggregates, window sem cobertura e sete combinações de TEMPORARY. Nos casos de TEMPORARY, `temporary_acceptance_valid` foi false para ausência/incompletude/divergência e true apenas na entrada completa vinculada.

## Limitações

O fixture PostgreSQL 16 não contém uma window function de usuário e não é uma cópia do catálogo Supabase. Esse fato é observado, não convertido em aprovação. O SHA-256 é calculado fora do PostgreSQL por um verificador que deve preservar bytes UTF-8 e fornecer a evidência; a consulta verifica que os bytes correspondem à definição atual, sem presumir `pgcrypto`.

Nenhuma conexão, alteração, role, grant, revoke, migration, DDL ou DML foi executada no Supabase ou em produção.
