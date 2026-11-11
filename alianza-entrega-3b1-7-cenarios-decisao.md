# Entrega 3B.1.7 — Matriz de cenários da decisão consolidada

**Tipo:** teste local determinístico da precedência do `CASE` final.  
**Limitação:** não conecta ao PostgreSQL e não afirma resultados de produção.

| # | Condição simulada | Resultado esperado | Resultado obtido | Evidência |
|---:|---|---|---|---|
| 1 | Todos os controlos aprovados, sem riscos pendentes | `APROVADA` | `APROVADA` | `alianza-entrega-3b1-7-test-decisao.py` |
| 2 | Hash SHA-256 divergente | Não aprovada | `INDETERMINADA` | `has_stale_function_review` |
| 3 | Função sem revisão individual | `INDETERMINADA` | `INDETERMINADA` | `has_missing_function_review` |
| 4 | Aggregate ou outro objecto executável sem cobertura | `INDETERMINADA` | `INDETERMINADA` | `has_missing_function_review` + `has_nonverifiable_executable_function` |
| 5 | `SECURITY DEFINER` com risco de privilégio do proprietário | Não aprovada | `REPROVADA` | `has_owner_effective_privilege_risk` |
| 6 | Metadados de `SECURITY DEFINER` incompletos | `INDETERMINADA` | `INDETERMINADA` | `has_security_definer_metadata_indeterminate` |
| 7 | `transaction_read_only` desligado | Não aprovado | `REPROVADA` | `transaction_read_only_ok = false` |
| 8 | `default_transaction_read_only` desligado | Não aprovado | `REPROVADA` | `default_transaction_read_only_ok = false` |
| 9 | FDW com privilégio efectivo indevido | Não aprovado | `REPROVADA` | `has_fdw_effective_privilege` |
| 10 | Foreign Server com privilégio efectivo indevido | Não aprovado | `REPROVADA` | `has_server_effective_privilege` |
| 11 | Default ACL com concessão perigosa | Não aprovado | `INDETERMINADA` | `has_dangerous_default_acl` |
| 12 | `TEMPORARY` sem aceitação formal | Não aprovado | `INDETERMINADA` | `temporary_acceptance_valid = false` |
| 13 | `TEMPORARY` com aceitação formal válida | Condicional | `APROVACAO_CONDICIONAL_TEMPORARY` | aceitação externa válida |
| 14 | Ownership não verificável em categoria relevante | `INDETERMINADA` | `INDETERMINADA` | `ownership_catalogs_selectable = false` |
| 15 | Indicador crítico de Large Object isolado | Não aprovado | `REPROVADA` | `has_large_object_read` |

## Precedência

1. `REPROVADA`: risco ou violação de segurança comprovada.
2. `INDETERMINADA`: ausência de evidência, falha, incompatibilidade ou cobertura incompleta.
3. `APROVACAO_CONDICIONAL_TEMPORARY`: apenas com aceitação formal válida e sem qualquer outro risco.
4. `APROVADA`: apenas sem riscos, sem lacunas, sem `TEMPORARY` efectivo e com todos os registos reconciliados.

Os cenários foram executados pelo teste local. Consultas reais, assinatura das funções de privilégio, versão PostgreSQL e resultados catalogais continuam não executados por restrição de autorização.
