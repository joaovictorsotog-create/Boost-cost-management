# Entrega 3B.1.14 — Matriz de cobertura e evidências RLS

Legenda:

- **Loop compartilhado / consulta individual:** o harness usa uma função/loop comum, mas executa uma consulta dinâmica separada para cada tabela e registra o resultado por tabela.
- **Bloco com comandos individuais:** cada tabela possui uma instrução explícita no bloco SQL compartilhado.
- **Inferido:** não usado para os resultados declarados abaixo; cada linha listada foi executada.

| Cenário | `cost_groups` | `cost_items` | `cost_structures` | `cost_structure_lines` | `cost_calculations` | `costing_gamma_settings` | `costing_gamma_groups` | Forma de execução |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| A lê A; A não lê B | PASS | PASS | PASS | PASS | PASS | PASS | PASS | loop compartilhado, 2 SELECTs por tabela |
| B lê B; B não lê A | PASS | PASS | PASS | PASS | PASS | PASS | PASS | loop compartilhado, 2 SELECTs por tabela |
| A tenta UPDATE de B | PASS | PASS | PASS | PASS | PASS por privilégio | PASS | PASS | loop compartilhado, UPDATE dinâmico individual |
| A tenta DELETE de B | PASS | PASS | PASS | PASS | PASS por privilégio | PASS | PASS | loop compartilhado, DELETE dinâmico individual |
| A tenta INSERT em B | PASS | PASS | PASS | PASS | PASS | PASS | PASS | 7 INSERTs explícitos no bloco |
| A transfere registro A→B | PASS | PASS | PASS | PASS | PASS por privilégio | PASS | PASS | 7 UPDATEs explícitos no bloco |

## Não inferido

Nenhum `1 / 0` nesta matriz é uma extrapolação de outra tabela. Para cada célula de isolamento, o harness executou as duas consultas:

```sql
SELECT count(*) FROM public.<tabela> WHERE "organizationId" = 'organização própria';
SELECT count(*) FROM public.<tabela> WHERE "organizationId" = 'organização alheia';
```

Para escritas cruzadas, cada célula corresponde a uma instrução dinâmica ou explícita aplicada à tabela indicada. `cost_calculations` possui resultado “por privilégio” porque a ausência de UPDATE/DELETE foi exercitada diretamente e retornou `permission denied`.

## Controles preservados

| Controle | Evidência |
|---|---|
| conexão direta do runtime | `session_user=app_runtime`, `current_user=app_runtime` |
| não uso de `SET ROLE` | conexão `psql -U app_runtime` no harness |
| `authenticated` usa JWT | adulteração de `request.app_user_id` não alterou organização observada |
| JWT ausente | zero registros |
| anon | `permission denied` |
| idempotência | `rls_run_1=ok`, `rls_run_2=ok` |
| snapshot imutável | UPDATE/DELETE bloqueados |
