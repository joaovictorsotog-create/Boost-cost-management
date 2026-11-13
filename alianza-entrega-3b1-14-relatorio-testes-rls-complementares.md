# Entrega 3B.1.14 — Complementação final dos testes RLS Costing

## Proveniência verificada antes dos testes

Aplicação:

- branch: `costing-security-preflight-final-20261112`
- HEAD esperado e confirmado: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`
- working tree: limpa
- nenhum arquivo da aplicação foi alterado nesta rodada

Boost:

- repositório: `joaovictorsotog-create/Boost-cost-management`
- branch documental: `entrega-3b1-9-correcoes-auditoria`
- HEAD esperado e confirmado antes desta rodada: `de83e2346456c81c50eef7eac9b8bc81eb74317c`
- remoto confirmado na mesma branch e SHA

## Harness executado agora

O harness atualizado foi executado em PostgreSQL descartável 16. As conexões de runtime foram abertas diretamente com `-U app_runtime`; não houve `SET ROLE`.

A sessão registrou:

```text
session_user | current_user
-------------+--------------
app_runtime  | app_runtime
```

O fixture possui uma linha para a organização A e uma linha para a organização B em cada uma das sete tabelas:

- `cost_groups`
- `cost_items`
- `cost_structures`
- `cost_structure_lines`
- `cost_calculations`
- `costing_gamma_settings`
- `costing_gamma_groups`

## Resultados novos — isolamento de leitura

Foi executado um loop PL/pgSQL compartilhado que emitiu uma consulta individual por tabela, registrando `own=1` e `other=0` para cada caso.

### Organização A

```text
cost_groups             own=1 other=0
cost_items              own=1 other=0
cost_structures         own=1 other=0
cost_structure_lines    own=1 other=0
cost_calculations       own=1 other=0
costing_gamma_settings  own=1 other=0
costing_gamma_groups    own=1 other=0
```

Resultado: `runtime_org_a_all_seven=ok`.

### Organização B

```text
cost_groups             own=1 other=0
cost_items              own=1 other=0
cost_structures         own=1 other=0
cost_structure_lines    own=1 other=0
cost_calculations       own=1 other=0
costing_gamma_settings  own=1 other=0
costing_gamma_groups    own=1 other=0
```

Resultado: `runtime_org_b_all_seven=ok`.

Portanto, tanto A quanto B leem somente seus próprios registros em todas as sete tabelas, e cada organização não lê registros da outra.

## Resultados novos — escritas cruzadas

### UPDATE e DELETE de registros da outra organização

Foi executado um loop compartilhado com uma instrução dinâmica individual por tabela. Para as seis tabelas mutáveis, o resultado foi zero linhas visíveis; para `cost_calculations`, a tentativa foi bloqueada por privilégio ausente. Resultado:

```text
runtime_cross_update_delete_all_seven=ok
```

Todos os sete casos foram exercitados individualmente dentro do loop:

- `cost_groups`: UPDATE/DELETE bloqueados;
- `cost_items`: UPDATE/DELETE bloqueados;
- `cost_structures`: UPDATE/DELETE bloqueados;
- `cost_structure_lines`: UPDATE/DELETE bloqueados;
- `cost_calculations`: UPDATE/DELETE bloqueados por `permission denied`;
- `costing_gamma_settings`: UPDATE/DELETE bloqueados;
- `costing_gamma_groups`: UPDATE/DELETE bloqueados.

### INSERT em organização alheia

Foram executados sete INSERTs individuais, um por tabela, dentro de um bloco PL/pgSQL compartilhado. Todos falharam conforme esperado pela policy `WITH CHECK`:

```text
runtime_cross_insert_all_seven=ok
```

### Transferência de registro entre organizações

Foram executados sete UPDATEs individuais tentando alterar `organizationId` de A para B. Todos foram bloqueados, incluindo `cost_calculations`, que permanece bloqueado também pelo privilégio de UPDATE:

```text
runtime_org_transfer_updates_blocked=ok
```

## Testes preservados e repetidos

O harness final também preservou e repetiu:

- conexão direta como `app_runtime`;
- `session_user=app_runtime`;
- `current_user=app_runtime`;
- adulteração de `request.app_user_id` para `authenticated`, que não suplanta `auth.uid()`;
- sessão `authenticated` sem JWT, retornando zero registros;
- acesso `anon`, bloqueado por privilégio;
- aplicação RLS duas vezes, ambas concluídas com `rls_run_1=ok` e `rls_run_2=ok`;
- imutabilidade dos snapshots, com UPDATE/DELETE bloqueados.

## Testes direcionados

Executados novamente nesta rodada:

- 9 arquivos Vitest;
- 78 testes aprovados;
- engine Costing: 28;
- snapshot: 6;
- router/validador: 12;
- identidade, RLS, preflight e fail-closed: 32.

## Distinção entre evidência nova e histórica

Os resultados `runtime_org_a_all_seven`, `runtime_org_b_all_seven`, `runtime_cross_update_delete_all_seven`, `runtime_cross_insert_all_seven` e `runtime_org_transfer_updates_blocked` foram executados agora e estão no log desta entrega.

Os resultados da Entrega 3B.1.13 permanecem históricos, embora tenham sido preservados no harness: `runtime_read_own_tenant`, `runtime_authorized_writes`, `runtime_cross_tenant_isolation`, `authenticated_identity_and_no_jwt`, `anon_access=blocked` e `postgresql_rls_correction=PASS`.

## Conclusão

A cobertura complementar exigida foi executada sem alteração da lógica da aplicação. Não houve push da aplicação, PR, merge, rebase, cherry-pick, deploy, migration persistente, conexão Supabase ou acesso à produção.
