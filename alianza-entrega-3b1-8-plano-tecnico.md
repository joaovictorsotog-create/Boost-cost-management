# Entrega 3B.1.8 — Plano técnico da role PostgreSQL de auditoria

## Escopo e segurança

Esta entrega é exclusivamente documental e de testes locais. Nenhum comando foi enviado ao Supabase, nenhum migration foi criado e nenhum código da aplicação foi alterado. O SQL continua sendo um plano revisável; os comandos de criação da role permanecem comentados.

## Protocolo de revisão individual

A definição é obtida da mesma sessão e do mesmo inventário que produzem a revisão. Para `f` e `p`, a representação é `pg_get_functiondef(oid)`. Para `a`, a representação canônica é formada por identidade, owner, linguagem, segurança e os metadados de `pg_aggregate` (transição, finalização, combinação, serialização, desserialização e transição/movimento). Para `w`, a unidade revisada é a entrada `pg_proc`, com representação canônica de seus metadados; não se inventa uma definição de código.

O cliente preserva os bytes UTF-8 exatamente, sem normalização, transporta `definition_bytes_hex`, `definition_encoding`, `definition_source`, `snapshot_id` e calcula `definition_sha256_calculated` externamente. A reconciliação compara esse valor ao `definition_sha256` apresentado, exige 64 hexadecimais, evidencia não vazia, `definition_normalized = false`, identidade completa, owner, linguagem, extensão, segurança, auditor, data e justificativa. O `snapshot_id` é fixado na sessão por `alianza.audit_snapshot_id`; divergência ou ausência de evidência invalida a revisão. Alteração de identidade/metadados ou mudança de snapshot torna a revisão stale/`INDETERMINADA`.

Esse transporte externo é deliberado: o SQL não presume `pgcrypto` e não grava evidência na base auditada. O manifesto externo deve registrar a origem textual, a codificação, os bytes, o cálculo, o objeto completo, a sessão/inventário e a assinatura ou referência de evidência. `sha256_verified` não é consumido como prova isolada.

## Aceitação TEMPORARY

A CTE `temporary_acceptance` é alimentada por uma entrada externa tipada e não por valores fixos. São obrigatórios: `audit_id`, `role_name`, responsável, data, referência de evidência, justificativa, escopo do risco e marcador de validade. O registro deve ser associado à auditoria e à role avaliada. Ausência ou incompletude não é aceitação. A interface não exige escrita persistente nem privilégio TEMPORARY na role auditada.

A precedência permanece `REPROVADA`, `INDETERMINADA`, `APROVACAO_CONDICIONAL_TEMPORARY`, `APROVADA`. Um risco crítico prevalece sobre qualquer aceitação.

## Compatibilidade

A suíte foi executada em PostgreSQL 16.15. PostgreSQL 16 não expõe `has_large_object_privilege`; o SQL usa a ACL de `pg_largeobject_metadata` com `aclexplode`. `pg_ts_parser` e `pg_ts_template` não possuem colunas de owner nessa versão; esses catálogos não são tratados como objetos operacionais pertencentes à role auditada. A ausência de `w` no fixture PostgreSQL 16 é observada pelo inventário, não preenchida artificialmente.
