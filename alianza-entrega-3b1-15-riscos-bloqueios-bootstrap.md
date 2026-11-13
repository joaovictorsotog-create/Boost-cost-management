# Riscos e bloqueios — Bootstrap PostgreSQL Alianza

## Bloqueios atuais

1. `initdb`, `pg_ctl` e `postgres` ausentes no ambiente; somente `psql` e `pg_isready` estão disponíveis.
2. Não há prova de instalação completa em banco vazio; o bootstrap não pode ser aprovado.
3. Journal PostgreSQL incompleto: somente `0000` e `0001`.
4. Snapshots ausentes para migrations posteriores.
5. Duplicidades `0007`, `0021`, `0027`, `0032` e lacuna `0016`.
6. `0036_costing_foundation.sql` fora do journal.
7. `public.rls_auto_enable()` é referenciada para revogação, mas não foi localizada uma definição.
8. Configuração principal Drizzle usa MySQL; PostgreSQL depende de configuração separada.
9. RLS global depende de tabelas, roles, funções e `auth.uid()` externos ao Costing.

## Riscos de segurança

- Aplicar o RLS global para validar Costing altera módulos não relacionados.
- Funções históricas `SECURITY DEFINER` usam `search_path = public` ou não o definem; não atendem ao requisito de path vazio sem hardening efetivo.
- Um `REVOKE` sobre função inexistente pode interromper o runner global.
- `app_runtime` exige role sem `BYPASSRLS` e contexto `request.app_user_id`; grants excessivos ou sessão incorreta podem romper isolamento.
- O arquivo histórico e o journal não provam qual schema já foi aplicado em instalações existentes.

## Riscos operacionais

- Rodar `drizzle-kit migrate` usando configuração errada pode selecionar MySQL em vez de PostgreSQL.
- Reconstruir ou renumerar migrations sem evidência destrói proveniência.
- Aplicar diretamente no Supabase sem ambiente descartável pode afetar dados ou políticas de outros módulos.
- `CREATE TABLE IF NOT EXISTS` não valida que a definição existente seja estruturalmente igual à esperada.

## Limites desta entrega

- Nenhum SQL foi executado.
- Nenhuma conexão a banco persistente, Supabase ou produção foi aberta.
- Nenhuma migration, DDL ou DML foi realizada.
- Nenhuma aprovação de bootstrap foi emitida.
- A análise é estática e remota; a prova final exige ambiente PostgreSQL descartável.
