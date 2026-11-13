# Entrega 3B.1.14 — Matriz de cobertura RLS e origem das rejeições

Aplicação auditada: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`.

| Cenário | cost_groups | cost_items | cost_structures | cost_structure_lines | cost_calculations | costing_gamma_settings | costing_gamma_groups |
|---|---|---|---|---|---|---|---|
| A lê A; A não lê B | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop |
| B lê B; B não lê A | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop | PASS — consulta individual no loop |
| A tenta UPDATE de B | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — privilégio ausente | PASS — zero linhas visíveis | PASS — zero linhas visíveis |
| A tenta DELETE de B | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — zero linhas visíveis | PASS — privilégio ausente | PASS — zero linhas visíveis | PASS — zero linhas visíveis |
| A tenta INSERT em B | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS | PASS — `42501`, mensagem RLS |
| A transfere registro A→B | PASS — `42501`, RLS | PASS — `42501`, RLS | PASS — `42501`, RLS | PASS — `42501`, RLS | PASS — `42501`, privilégio ausente | PASS — `42501`, RLS | PASS — `42501`, RLS |

## Critério de atribuição

Os INSERTs só são PASS quando o harness captura `RETURNED_SQLSTATE = 42501` e `MESSAGE_TEXT` contendo `row-level security policy`. Erro de constraint, duplicidade, referência inválida ou qualquer mensagem diferente faz o teste falhar.

Para transferência, cada fixture A é verificada como visível antes do UPDATE e o comando altera somente `organizationId`. Seis tabelas retornaram mensagem de RLS. `cost_calculations` retornou `permission denied for table cost_calculations`; portanto, esse caso é PASS de bloqueio, mas **não** é evidência isolada de RLS.

## Forma de execução

- Isolamento: duas consultas individuais por tabela dentro de loop PL/pgSQL compartilhado.
- INSERT: sete comandos explícitos, cada um com fixture e identificador exclusivos.
- Transferência: sete UPDATEs explícitos, com confirmação de existência/visibilidade anterior.
- Runtime: conexão direta como `app_runtime`, sem `SET ROLE`.

## Controles preservados

A matriz não infere resultados entre tabelas. Também foram preservados: autenticação por `auth.uid()`, resistência à adulteração de `request.app_user_id`, sessão sem JWT, bloqueio de `anon`, imutabilidade de snapshots e idempotência da aplicação RLS.
