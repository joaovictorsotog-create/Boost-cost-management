# Entrega 3B.1.10 — Matriz de controles e evidências

| ID | Controle | Implementação verificada | Evidência | Estado |
|---|---|---|---|---|
| SEC-01 | Não conectar antes de validar destino | `createValidatedPostgresClient()` chama `validateDestination()` antes de `postgresFactory` | 8 testes do preflight; factory não chamada nos casos recusados | PASS |
| SEC-02 | Produção sempre bloqueada | `validateDestination()` lança para `production` | Caso explícito de production | PASS |
| SEC-03 | Local restrito a loopback | Hosts aceitos: `localhost`, `127.0.0.1`, `::1` | Caso local remoto recusado e loopback aceito | PASS |
| SEC-04 | Staging exige par autorizado | allowlist fixa no código; sem override de ambiente | Fixture autorizada aceita; produção/remoto/não autorizado recusados | PASS local / staging real bloqueado |
| SEC-05 | Project ref público válido | HTTPS e hostname `<ref>.supabase.co` | Casos do preflight | PASS |
| SEC-06 | RLS Costing habilitado e forçado | Sete tabelas com `ENABLE/FORCE ROW LEVEL SECURITY` | Harness local verifica 7/7 | PASS |
| SEC-07 | Isolamento A/B | Políticas usam `private.has_organization_access("organizationId")` | `auth.uid()` vê somente org A | PASS |
| SEC-08 | JWT ausente não autoriza | `current_app_user_id()` usa `auth.uid()` para authenticated | Sessão sem claim retorna zero linhas | PASS |
| SEC-09 | GUC não suplanta usuário | `request.app_user_id` aceito apenas para `session_user = 'app_runtime'` | Harness separa sessões reais das roles | PASS |
| SEC-10 | Menor privilégio de snapshot | `cost_calculations` recebe select/insert; não update/delete | `has_table_privilege`: `t,t,f,f` | PASS |
| SEC-11 | Snapshot imutável | Trigger da `0036_costing_foundation.sql` bloqueia UPDATE/DELETE | Migration instalada em PostgreSQL descartável | PASS |
| SEC-12 | SECURITY DEFINER endurecido | `search_path = ''` e objetos qualificados; hardening condicional de funções existentes | Contratos + instalação idempotente | PASS local |
| SEC-13 | Idempotência | RLS executado duas vezes | `rls_run_1=ok`, `rls_run_2=ok` | PASS |
| SEC-14 | Nenhum alvo de produção acessado | Sem credenciais/conexões externas | Execução somente local; preflight recusa production | PASS |
| SEC-15 | Cadeia de migrations íntegra | Journal deve registrar SQLs aplicáveis | Journal atual só contém 0000/0001, SQLs chegam a 0036 | BLOQUEADO |
| SEC-16 | Suíte global verde | Todos os testes do projeto | 840/842; duas falhas ambientais conhecidas | BLOQUEADO |
