# Entrega 3B.1.11 — Relatório de reconciliação de proveniência e escopo RLS

## 1. Resumo executivo

**Conclusão: APROVADO COM RESSALVAS.** A branch final local existe, está íntegra e possui o commit `16fde337f707734fbca13ac311f1ebe2d01a2472` como filho direto do SHA-base `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285`. A base efetiva foi a branch local `feature/alianza-costing-foundation-20261110`, não a mesma referência remota, que permanece em `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801`.

A reconciliação direta do schema, migration, SQL RLS e testes encontra **sete tabelas Costing**, não oito. Todas as sete têm RLS habilitado e forçado no SQL final. Nenhuma oitava tabela Costing existe no schema Drizzle ou na migration `0036_costing_foundation.sql`; a alegação anterior de oito não pôde ser atribuída a um artefato Git local verificável.

A implementação anterior do Costing continua presente no histórico ancestral: motor exato, Gama, snapshots, persistência autoritativa, publicação transacional e router. As verificações locais desta rodada passaram. Permanecem ressalvas: as branches históricas solicitadas `costing-security-bootstrap-final-20261112` e `costing-completion-20261111` não existem localmente; o journal de migrations continua incompleto; e staging/produção não foram acessados.

## 2. Proveniência Git observada diretamente

- Repositório: `joaovictorsotog-create/alianza-ai-platform`.
- Branch atual: `costing-security-preflight-final-20261112`.
- HEAD: `16fde337f707734fbca13ac311f1ebe2d01a2472`.
- Pai direto do HEAD: `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285`.
- Working tree: limpa.
- O SHA-base é ancestral direto do HEAD; `git rev-list base..HEAD` retorna exatamente 1 commit.
- Árvore do HEAD: `3fed12b69bdac72a957ddd14adc6307f66da25a5`.
- O commit final altera exatamente cinco caminhos.

A branch local `feature/alianza-costing-foundation-20261110` aponta para o SHA-base e está quatro commits à frente de `origin/feature/alianza-costing-foundation-20261110`, que aponta para `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801`. Não houve troca silenciosa: a base usada foi explicitamente o objeto local `0ee6d280...`, identificado no momento da criação da branch final.

## 3. Referências solicitadas

| Referência informada | Referência encontrada | SHA | Ancestralidade/relação | Conclusão |
|---|---|---|---|---|
| `costing-security-preflight-final-20261112` | Branch local existente | `16fde337f707734fbca13ac311f1ebe2d01a2472` | HEAD atual | Confirmada |
| `16fde337f707734fbca13ac311f1ebe2d01a2472` | Objeto commit local | mesmo SHA | Filho direto da base | Confirmado |
| `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` | Branch local `feature/alianza-costing-foundation-20261110` | mesmo SHA | Pai direto do final | Confirmado como base efetiva |
| `feature/alianza-costing-foundation-20261110` | Branch local | `0ee6d280...` | 4 commits à frente do remoto homônimo | Origem efetiva da base |
| `origin/feature/alianza-costing-foundation-20261110` | Ref remota local | `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801` | Ancestral comum; não é a base final usada | Divergente, não substituída |
| `costing-security-bootstrap-final-20261112` | Não encontrada | — | Não verificável localmente | Ausente |
| `costing-completion-20261111` | Não encontrada | — | Não verificável localmente | Ausente |

## 4. Reconciliação das tabelas Costing

A enumeração direta encontrou exatamente estas sete tabelas em `schema.costing.ts` e `0036_costing_foundation.sql`: `cost_groups`, `cost_items`, `cost_structures`, `cost_structure_lines`, `cost_calculations`, `costing_gamma_settings` e `costing_gamma_groups`. Não foi encontrada uma oitava tabela Costing.

| Tabela | Finalidade | RLS/force | Policies | Grants | Update/Delete | Conclusão |
|---|---|---|---|---|---|---|
| `cost_groups` | Grupos de itens de custo | ENABLE + FORCE | `costing_tenant_read` SELECT authenticated; `costing_app_runtime_insert/update/delete` tenant-scoped | authenticated SELECT; app_runtime SELECT/INSERT/UPDATE/DELETE; anon revogado | Permitidos somente dentro do tenant | Incluída |
| `cost_items` | Itens simples/compostos, unidade e custo manual | ENABLE + FORCE | Mesmo conjunto, filtrado por `organizationId` | Mesmo padrão de catálogo | Permitidos somente dentro do tenant | Incluída |
| `cost_structures` | Versões e estado DRAFT/ACTIVE/SUPERSEDED/INACTIVE | ENABLE + FORCE | Mesmo conjunto tenant-scoped | Mesmo padrão de catálogo | Permitidos pelo RLS; publicação usa transação/lock; índice garante um ACTIVE | Incluída |
| `cost_structure_lines` | Consumos das estruturas | ENABLE + FORCE | Mesmo conjunto tenant-scoped | Mesmo padrão de catálogo | Permitidos somente dentro do tenant | Incluída |
| `cost_calculations` | Snapshots calculados | ENABLE + FORCE | `costing_tenant_read` SELECT; `costing_app_runtime_insert` INSERT | authenticated SELECT; app_runtime SELECT/INSERT; anon revogado | Sem grant/policy de UPDATE/DELETE e trigger `cost_calculations_immutable` | Incluída; proteção mais restritiva |
| `costing_gamma_settings` | Percentual e estado da Gama por organização | ENABLE + FORCE | Mesmo conjunto tenant-scoped | Mesmo padrão de configuração | Permitidos somente dentro do tenant | Incluída |
| `costing_gamma_groups` | Grupos selecionados para Gama | ENABLE + FORCE | Mesmo conjunto tenant-scoped | Mesmo padrão de configuração | Permitidos somente dentro do tenant | Incluída |

A tabela `organizations` não é uma oitava tabela Costing: é tabela central do domínio e possui sua própria policy `organization_read`. A contagem de sete é, portanto, a contagem das tabelas declaradas pelo schema/migration Costing. Não há evidência direta de uma oitava tabela omitida; a divergência anterior permanece sem origem local verificável.

## 5. Continuidade funcional observada

A árvore final preserva os commits ancestrais `3571f34` (engine Gama), `0fad8b9` (persistência/publicação transacional), `4ae1ffb` (validação decimal e snapshots autoritativos) e `0ee6d28` (constraints e integridade). A leitura direta confirmou:

- cálculo genérico por quantidade consumida × custo unitário;
- composição recursiva e divisão pela quantidade de saída;
- aritmética racional com `bigint` e arredondamento somente na apresentação;
- Gama aplicada uma vez sobre bases manuais selecionadas;
- snapshot calculado pelo servidor a partir de itens/estruturas/configuração carregados por organização;
- payload autocontido com versão, engine, itens de origem, Gama e fração exata;
- trigger de imutabilidade de snapshots;
- publicação com `FOR UPDATE`, supersession e índice único de ACTIVE;
- proteção de organização no router, persistência e RLS;
- CRUD de grupos/itens preservado nos módulos e schema ancestrais;
- identidade `authenticated` baseada em `auth.uid()` e contexto GUC restrito a `app_runtime`;
- preflight que valida ambiente, project ref e hostname antes de chamar a fábrica PostgreSQL.

## 6. Evidência executada nesta rodada

- `vitest` direcionado: **78/78 testes PASS**, em 9 arquivos, cobrindo engine, snapshots, router, RLS, identidade, app_runtime e preflight.
- `pnpm check`: PASS.
- `git diff --check`: PASS.
- Reconciliação de refs, ancestry, árvore e working tree: PASS.
- Não foram executados DDL/DML em banco persistente, migrations remotas, deploy ou conexão Supabase nesta rodada.

## 7. Resultados apenas relatados por rodada anterior

O harness PostgreSQL descartável de instalação, idempotência, RLS A/B, grants e identidade foi executado na rodada anterior e relatado como PASS. Ele não foi reexecutado nesta rodada, porque esta etapa foi limitada a reconciliação read-only e testes locais sem banco persistente.

A suíte geral anterior foi relatada como 840/842, com duas falhas ambientais (`supabase-server-client.contract.test.ts` e `app-runtime-password.contract.test.ts`). Esse resultado não foi repetido nesta rodada e permanece evidência histórica, não novo resultado.

## 8. Riscos e ressalvas

1. A base efetiva é local e diverge quatro commits da ref remota homônima; o pacote deve preservar essa proveniência explícita.
2. As duas branches históricas solicitadas não existem localmente; sua comparação não é verificável.
3. O journal PostgreSQL registra somente `0000` e `0001`, embora existam SQLs até `0036`; a cadeia instalável continua pendente.
4. A allowlist de staging efetiva está vazia por ausência de destino autorizado identificável; staging remoto permanece bloqueado.
5. A contagem de oito tabelas não pode ser reconciliada com o código disponível; não deve ser tratada como fato sem referência Git ou schema correspondente.

## 9. Conclusão

A implementação final local e a cobertura RLS de **sete** tabelas Costing estão comprovadas no código e nos testes direcionados. A continuidade funcional ancestral também está comprovada por histórico e leitura direta. A entrega é **APROVADA COM RESSALVAS** para auditoria de código local, mas não para instalação em staging/produção até resolver proveniência remota, cadeia de migrations e destino de staging autorizado.
