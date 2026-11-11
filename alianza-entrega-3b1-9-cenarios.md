# Entrega 3B.1.9 — Cenários SQL reais

Todos os 30 cenários abaixo executaram a Etapa 13 real contra PostgreSQL descartável 16.15. `INDETERMINADA` é o resultado final esperado do fixture quando há evidência inválida ou quando controles locais não permitem aprovação; os indicadores específicos são comparados automaticamente pelo harness.

| Nº | Cenário | Indicador validado | Resultado |
|---:|---|---|---|
| 1 | Sem revisão | missing | PASS |
| 2 | Role incorreta | all_valid=false | PASS |
| 3 | Canonical atual alterada | stale | PASS |
| 4 | Bytes diferentes | stale | PASS |
| 5 | Hash registrado adulterado | stale | PASS |
| 6 | Hash calculado adulterado | stale | PASS |
| 7 | Snapshot divergente | snapshot_mismatch | PASS |
| 8 | Identidade do objeto divergente | missing/unmatched | PASS |
| 9 | Argumentos divergentes | missing/unmatched | PASS |
| 10 | Registro duplicado | duplicate | PASS |
| 11 | Registro órfão | unmatched | PASS |
| 12 | Registro incompleto | incomplete | PASS |
| 13 | Status não aprovado | all_valid=false | PASS |
| 14 | Fonte incorreta | all_valid=false | PASS |
| 15 | Encoding incorreto | all_valid=false | PASS |
| 16 | Normalização indevida | all_valid=false | PASS |
| 17 | audit_id ausente | incomplete | PASS |
| 18 | Algoritmo incorreto | stale | PASS |
| 19 | Owner divergente | stale | PASS |
| 20 | SECURITY divergente | stale | PASS |
| 21 | Aggregate com metadados | all_valid=true | PASS |
| 22 | Aggregate sem registro | missing | PASS |
| 23 | Window sem representação correspondente | missing/unmatched | PASS |
| 24 | TEMPORARY ausente | temp_valid=false | PASS |
| 25 | TEMPORARY incompleta | temp_valid=false | PASS |
| 26 | TEMPORARY de outra role | temp_valid=false | PASS |
| 27 | TEMPORARY de outro snapshot | temp_valid=false | PASS |
| 28 | TEMPORARY sem evidência | temp_valid=false | PASS |
| 29 | TEMPORARY sem justificativa | temp_valid=false | PASS |
| 30 | TEMPORARY válida | temp_valid=true; demais controles preservados | PASS |

Os 15 cenários estruturais da entrega anterior continuam executados por `alianza-entrega-3b1-7-test-decisao.py`; o resultado dessa suíte também foi PASS.
