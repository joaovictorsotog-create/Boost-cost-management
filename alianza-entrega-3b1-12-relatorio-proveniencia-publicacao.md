# Entrega 3B.1.12 — Auditoria de proveniência antes de publicação da aplicação

## Parecer executivo

**Parecer: PUBLICAÇÃO EXCLUSIVA PARA AUDITORIA REMOTA — APROVADA COM RESSALVAS.**

A branch `costing-security-preflight-final-20261112` é uma cadeia linear de cinco commits desde a base remota informada `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801` até `16fde337f707734fbca13ac311f1ebe2d01a2472`. A base local efetiva `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` é o quarto commit dessa cadeia; não houve troca de base dentro da cadeia final.

A publicação é segura **somente como branch de auditoria remota**, não como release, deploy, merge ou candidato a produção. O diff não contém segredos, credenciais, configurações locais, dumps, temporários ou dados sensíveis detectáveis. A ressalva principal é de escopo: quatro commits intermediários são funcionalmente necessários para preservar o Costing completo e o quinto adiciona o hardening de segurança/RLS/preflight.

## 1. Cinco commits que seriam publicados

| Ordem | SHA completo | Pai | Mensagem | Escopo |
|---:|---|---|---|---|
| 1 | `3571f34f34a8d46af1f07924eef389035ca81dd0` | `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801` | `feat(costing): implement exact gamma calculation domain` | Motor racional, Gama, snapshots e testes |
| 2 | `0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c` | `3571f34f34a8d46af1f07924eef389035ca81dd0` | `feat(costing): persist snapshots and publish structures transactionally` | Migration, persistência, publicação e integração |
| 3 | `4ae1ffb5500a93bc076ba7d8a1aa17a42bc4ca39` | `0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c` | `fix(costing): validate decimals and authoritative gamma snapshots` | Validação, Gama autoritativa e testes do router |
| 4 | `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` | `4ae1ffb5500a93bc076ba7d8a1aa17a42bc4ca39` | `fix(costing): enforce snapshot integrity and database constraints` | Constraints, imutabilidade e integridade de persistência |
| 5 | `16fde337f707734fbca13ac311f1ebe2d01a2472` | `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` | `fix(security): fail closed before Supabase RLS connections` | Preflight, RLS, identidade e contratos de segurança |

`git rev-list --count 27df6b0...16fde337...` retorna **5** e a base remota é ancestral do final.

## 2. Diff completo e escopo

O diff binário completo está em `alianza-entrega-3b1-12-diff-27df6b0-a-16fde337.patch`.

- Tamanho: **159.356 bytes**.
- SHA-256: `82049d3075c55281ae29adff0972eebbd66926e7b52b3cb3631b62ee2d56b777`.
- Resultado de `git diff --check`: PASS.
- Resultado agregado: **17 arquivos**, **2.250 adições**, **344 remoções**.
- Status agregado: **3 arquivos adicionados e 14 modificados; nenhum removido**.

## 3. Arquivos alterados

### Adicionados

- `drizzle/pg/0036_costing_foundation.sql`
- `server/apply-supabase-rls.preflight.test.ts`
- `server/db/costing.ts`
- `server/routers/costing.test.ts`

### Modificados

- `drizzle/pg/rls_multitenant.sql`
- `drizzle/pg/schema.costing.ts`
- `scripts/apply-supabase-rls.mjs`
- `server/app-runtime-rls-context.contract.test.ts`
- `server/db.ts`
- `server/domain/costing/engine.test.ts`
- `server/domain/costing/engine.ts`
- `server/domain/costing/snapshot.test.ts`
- `server/domain/costing/snapshot.ts`
- `server/domain/costing/structure-publication.ts`
- `server/routers/costing.ts`
- `server/supabase-rls.contract.test.ts`
- `tsconfig.json`

### Removidos

Nenhum arquivo removido.

## 4. Alterações fora do núcleo Costing

Não há alteração de produto não relacionada, mas há quatro alterações de suporte transversal que devem ser identificadas corretamente:

1. `scripts/apply-supabase-rls.mjs`: preflight genérico de destino Supabase/PostgreSQL. Não é lógica de cálculo Costing, mas é o gate de segurança que impede aplicar o RLS Costing em produção ou em staging não autorizado.
2. `drizzle/pg/rls_multitenant.sql`: além do bloco Costing, endurece helpers `SECURITY DEFINER`, identidade `app_runtime` e funções históricas de budgets/convites/e-mail. É hardening tenant-wide, não exclusivamente Costing.
3. `server/app-runtime-rls-context.contract.test.ts` e `server/supabase-rls.contract.test.ts`: contratos de segurança gerais ampliados para cobrir a separação de identidade e as tabelas Costing.
4. `server/db.ts`: exceção de TLS sem criptografia limitada a hosts locais, necessária para PostgreSQL descartável local; conexões remotas continuam exigindo TLS. É infraestrutura de teste/conexão, não regra de negócio Costing.

`tsconfig.json` é alteração de suporte ao motor Costing: `target: ES2020` habilita `BigInt` usado na aritmética racional. Não é alteração de produto independente.

Todos os demais caminhos alterados pertencem diretamente ao domínio Costing, à sua migration, persistência, router ou testes.

## 5. Verificação de segredos, configurações e dados

Foram verificados os conteúdos dos 17 caminhos no commit final e os nomes do diff:

- chaves privadas PEM/OpenSSH/EC/PGP: nenhuma ocorrência;
- chaves AWS, GitHub PATs e URLs PostgreSQL com credencial: nenhuma ocorrência;
- atribuições literais suspeitas de `password`, `secret`, `token` ou `api_key`: nenhuma ocorrência;
- `.env`, arquivos de credenciais, dumps, backups, temporários, logs, certificados e chaves: nenhum caminho alterado;
- `node_modules`, `dist` e `build`: nenhum caminho alterado;
- `template.json` aparece na árvore final, mas não foi alterado entre as bases e não seria publicado como parte do diff desta auditoria;
- nomes de variáveis como `SUPABASE_DATABASE_URL` aparecem apenas como interfaces de configuração, sem valores ou credenciais.

Os testes usam fixtures e URLs locais, não dados de produção. Não houve acesso a banco nesta auditoria.

## 6. Necessidade dos quatro commits intermediários

**Confirmado para preservação da implementação final.** Cada commit intermediário acrescenta uma camada que não está presente na base remota:

- `3571f34`: introduz o motor exato, tipos e aplicação da Gama; sem ele não existe a lógica matemática final nem os snapshots de domínio.
- `0fad8b9`: conecta o domínio ao schema, migration, persistência e publicação transacional; sem ele não existe armazenamento/integração operacional.
- `4ae1ffb`: torna o snapshot calculado no servidor e adiciona validação decimal/autoridade da Gama; sem ele o contrato final de input e a proteção contra resultado do cliente não são preservados.
- `0ee6d28`: adiciona constraints, trigger de imutabilidade e integridade de persistência; sem ele a proteção estrutural dos snapshots e dados de Costing desaparece.

O commit `16fde337` depende diretamente do estado consolidado em `0ee6d28` e adiciona o gate fail-closed, RLS Costing e hardening de identidade. Os cinco commits são uma cadeia linear; publicar somente o quinto não preservaria a implementação completa.

## 7. Conclusão de segurança para auditoria remota

É seguro publicar a branch **exclusivamente para auditoria remota**, desde que ela permaneça isolada e não seja tratada como release. A publicação não deve ser acompanhada de PR, merge, deploy ou migration. O diff é auditável, não contém segredos detectáveis e mantém a proveniência completa da implementação.

Nesta rodada não foi feito push da aplicação, não foi criado PR, não houve merge/rebase/cherry-pick, deploy ou acesso a banco. O único commit autorizado é documental no Boost.
