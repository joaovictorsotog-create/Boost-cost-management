# Proposta técnica de RLS — Alianza Costing

## Estado

RLS permanece pendente nesta rodada. Este documento é uma proposta para revisão independente; não contém execução de `ALTER TABLE`, `CREATE POLICY`, `GRANT`, alteração de roles ou migration aplicada.

## Tabelas que exigem isolamento por organização

As seguintes tabelas da migration `0036_costing_foundation.sql` são tenant-scoped e devem carregar políticas RLS:

- `cost_groups`
- `cost_items`
- `cost_structures`
- `cost_structure_lines`
- `cost_calculations`
- `costing_gamma_settings`
- `costing_gamma_groups`

As relações devem preservar os vínculos compostos `(organizationId, id)` ou `(organizationId, structureId)` já definidos pelas foreign keys. A política não deve confiar apenas em um identificador enviado pelo cliente.

## Critério de isolamento

A organização da linha deve ser autorizada pelo contexto autenticado da sessão. A proposta é comparar `organizationId` com a organização efetiva do membro autenticado através de uma função de segurança estável, por exemplo `app.current_organization_id()` ou a função equivalente adotada pelo runtime Supabase. A função deve ser `SECURITY DEFINER`, possuir `search_path` restrito e não permitir que o cliente escolha arbitrariamente o tenant.

O backend continua a executar `requireTenantPermission` para autorização de produto:

- `costing.read` para leitura de estruturas, histórico e cálculo;
- `workspace.manage` para criar/editar linhas DRAFT e publicar.

RLS é a segunda linha de defesa para acesso SQL direto e não substitui a verificação de permissões do router.

## Políticas futuras

A revisão de implementação deve cobrir:

1. `SELECT`: somente linhas da organização efetiva.
2. `INSERT`: `organizationId` deve corresponder à organização efetiva.
3. `UPDATE` em `cost_structures` e `cost_structure_lines`: somente DRAFT; estruturas ACTIVE, SUPERSEDED e INACTIVE permanecem imutáveis, exceto a transição controlada de ACTIVE para SUPERSEDED durante publicação.
4. `DELETE`: somente linhas de estruturas DRAFT; snapshots e estruturas publicadas não devem ser removíveis.
5. `cost_calculations`: histórico somente leitura para a sessão da organização; inserção somente pelo fluxo de backend autorizado.
6. `costing_gamma_settings` e `costing_gamma_groups`: leitura/escrita condicionada ao mesmo tenant e a `workspace.manage` no backend.

## Evidência necessária para futura aprovação

A próxima revisão deve executar, em PostgreSQL descartável ou homologação autorizada, testes A/B com duas organizações, incluindo leitura, inserção, atualização, exclusão e tentativa de atravessar tenant. Também deve verificar `ENABLE ROW LEVEL SECURITY`, `FORCE ROW LEVEL SECURITY`, policies efetivas e privilégios das roles envolvidas.

Nenhum resultado desta proposta deve ser interpretado como RLS implementada ou como autorização para produção.
