# Entrega 3B.1.11 — Inventário de proveniência Git

## Repositório da aplicação

- Repositório local: `/home/ubuntu/work/alianza-ai-platform`
- Branch verificada: `costing-security-preflight-final-20261112`
- HEAD: `16fde337f707734fbca13ac311f1ebe2d01a2472`
- Pai direto: `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285`
- Working tree na verificação: limpa
- Árvore do base: `2694ffde410fa85d4930cc451156e55b7b3e544d`
- Árvore do final: `3fed12b69bdac72a957ddd14adc6307f66da25a5`
- Commits exclusivos entre base e final: `1`
- Caminhos alterados entre base e final: `5`

## Tabela de referências

| Referência | Estado local | SHA | Pai/relação | Observação |
|---|---|---|---|---|
| `costing-security-preflight-final-20261112` | Existe | `16fde337f707734fbca13ac311f1ebe2d01a2472` | Filho direto de `0ee6d280...` | Branch auditada |
| `0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285` | Existe | mesmo SHA | Pai de `16fde337...` | Base efetiva local |
| `feature/alianza-costing-foundation-20261110` | Existe | `0ee6d280...` | Quatro commits à frente do remoto homônimo | Branch local que forneceu a base |
| `origin/feature/alianza-costing-foundation-20261110` | Existe | `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801` | Ancestral comum, quatro commits atrás da local | Não foi usada como base silenciosa |
| `costing-security-bootstrap-final-20261112` | Não existe | — | — | Comparação impossível |
| `costing-completion-20261111` | Não existe | — | — | Comparação impossível |

## Commits locais à frente do remoto homônimo

1. `3571f34` — `feat(costing): implement exact gamma calculation domain`
2. `0fad8b9` — `feat(costing): persist snapshots and publish structures transactionally`
3. `4ae1ffb` — `fix(costing): validate decimals and authoritative gamma snapshots`
4. `0ee6d28` — `fix(costing): enforce snapshot integrity and database constraints`

## Commit final

`16fde337f707734fbca13ac311f1ebe2d01a2472` — `fix(security): fail closed before Supabase RLS connections`

Alterações diretas do commit final:

- `drizzle/pg/rls_multitenant.sql` — modificado
- `scripts/apply-supabase-rls.mjs` — modificado
- `server/app-runtime-rls-context.contract.test.ts` — modificado
- `server/apply-supabase-rls.preflight.test.ts` — adicionado
- `server/supabase-rls.contract.test.ts` — modificado

Nenhum commit foi criado na aplicação durante esta reconciliação. Nenhum merge, rebase, cherry-pick, push ou deploy foi realizado.
