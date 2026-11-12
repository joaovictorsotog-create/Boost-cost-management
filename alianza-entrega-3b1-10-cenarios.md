# Entrega 3B.1.10 — Cenários de auditoria executados

| Grupo | Cenário | Resultado |
|---|---|---|
| Preflight | Local + `127.0.0.1` | Aceito; cliente fake recebe `ssl: false` |
| Preflight | Local + host Supabase remoto | Recusado antes da fábrica PostgreSQL |
| Preflight | Staging + project ref/host fixture autorizado | Aceito somente na função pura de teste |
| Preflight | Staging + banco de produção | Recusado antes da conexão |
| Preflight | Staging + host remoto não relacionado | Recusado antes da conexão |
| Preflight | Staging + project ref não autorizado | Recusado antes da conexão |
| Preflight | Production, qualquer URL | Recusado antes da conexão |
| Preflight | Staging direto `db.<ref>.supabase.co` | Normalizado para pooler somente após validação |
| RLS | Sete tabelas Costing com RLS | 7/7 enabled e forced |
| RLS | Usuário A lê itens de A e não B | PASS |
| RLS | Usuário A tenta contexto sem JWT | zero linhas |
| RLS | `app_runtime` com app_user_id válido | vê somente tenant A |
| RLS | authenticated tenta usar app_user_id | não substitui auth.uid |
| RLS | anon consulta Costing | sem privilégio |
| Grants | Snapshot SELECT | permitido |
| Grants | Snapshot INSERT | permitido |
| Grants | Snapshot UPDATE | negado |
| Grants | Snapshot DELETE | negado |
| Migration | `0036_costing_foundation.sql` em banco vazio artificial | PASS |
| Idempotência | RLS primeira execução | `rls_run_1=ok` |
| Idempotência | RLS segunda execução | `rls_run_2=ok` |
| Regressão | Contracts RLS/identity/app_runtime | 32/32 PASS |
| Regressão | Engine/snapshot/router Costing | 46/46 PASS |
| Regressão | Typecheck | PASS |
| Regressão | Prettier e diff check | PASS |
| Global | Suíte geral | 840 PASS; 2 falhas ambientais conhecidas |

Todos os valores e identidades do harness PostgreSQL foram artificiais. Nenhum teste abriu conexão para Supabase ou produção.
