# Entrega 3B.1.9 — Plano técnico

A 3B.1.9 preserva os controles válidos da 3B.1.8 e fecha os bloqueadores remanescentes sem conexão com produção. A entrada de revisão continua sendo uma CTE `VALUES` tipada, substituível por fixture SQL controlada, arquivo CSV importado para staging local ou tabela temporária local. Nenhuma dessas alternativas grava no Supabase.

## Prova SHA-256 vinculada ao objeto atual

A Etapa 13 inventaria o objeto PostgreSQL atual na mesma sessão e produz `canonical_definition`. Para funções e procedures, a fonte é `pg_get_functiondef(oid)`; para aggregates, a representação inclui identidade, owner, linguagem, segurança, volatilidade, paralelismo, leakproof, origem/argumentos e todos os campos relevantes de `pg_aggregate`; para window functions, usa-se a representação de metadados de `pg_proc`, sem inventar código.

O registro externo fornece `canonical_definition`, `definition_bytes_hex`, `definition_encoding = UTF-8`, `hash_algorithm = SHA-256`, `definition_sha256` e `definition_sha256_calculated`, além da identidade completa e do `snapshot_id`. A consulta exige simultaneamente:

- `canonical_definition` do registro igual à representação atual do inventário;
- `definition_bytes_hex` igual a `encode(convert_to(canonical_definition, 'UTF8'), 'hex')` calculado na consulta;
- algoritmo explícito `SHA-256`;
- hash apresentado igual ao hash calculado externamente sobre esses bytes atuais;
- identidade, owner, linguagem, extensão, segurança, estado, auditor, data e evidência válidos;
- role e snapshot iguais aos valores da sessão.

Assim, um hash antigo não passa depois que a definição ou seus metadados mudam. O SQL não presume `pgcrypto`: a verificação de bytes usa funções nativas de conversão/encoding; o cálculo SHA-256 permanece uma atestação externa reproduzível sobre os bytes que a consulta reconcilia. Um booleano isolado não é aceito.

## Integridade do registro

A Etapa 13 marca duplicidades, registros sem objeto correspondente, campos obrigatórios ausentes e snapshots divergentes. A ausência de revisão continua sendo `INDETERMINADA`. A interface não aceita linhas ambíguas, identidade divergente, hash adulterado, bytes diferentes ou status não aprovado.

## TEMPORARY

A entrada possui nove campos: `audit_id`, `role_name`, `snapshot_id`, responsável, data, evidência, justificativa, escopo e validade. Ela é aceita somente quando vinculada a uma revisão do mesmo `audit_id`, role e snapshot. A decisão usa `COALESCE(NOT temporary_acceptance_valid, true)`: `NULL`, ausência, divergência ou incompletude nunca avançam para aprovação condicional.

## Escopo operacional

A entrega é exclusivamente documental e local. Não altera migrations, schema, RLS, permissões ou roles do sistema Alianza, não usa Supabase e não publica/implanta alterações.
