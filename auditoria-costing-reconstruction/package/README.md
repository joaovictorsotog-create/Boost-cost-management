# Alianza Costing — reconstrução técnica auditável

Esta entrega é uma reconstrução técnica local a partir de patches recuperados. Não declara recuperação dos commits antigos ausentes.

**Repositório:** `joaovictorsotog-create/alianza-ai-platform`  
**Branch local:** `feature/alianza-costing-foundation-20261110`  
**SHA base oficial:** `27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801`  
**SHA final novo:** `0e1457cb5a72bca6b4310bd650897c9f9080ad94`

## Commits novos

- `5415538f70001b321ecb0443f65a35e517bbb48e` — `reconstruct(costing): restore initial costing implementation`
- `0e1457cb5a72bca6b4310bd650897c9f9080ad94` — `reconstruct(costing): apply recovered audit corrections`

A branch local está dois commits à frente de `origin/feature/alianza-costing-foundation-20261110`. Não foi feito push.

## Conteúdo

O pacote inclui o patch completo, os diffs individuais, um bundle Git completo, os 12 caminhos finais exportados diretamente dos objetos do novo HEAD, a migration PostgreSQL, testes, evidências de integração/rollback, resultados de `git status`, `git log`, comparação remota e manifesto SHA-256.

## Validação

A suíte direcionada de Costing passou 46/46 testes. O typecheck passou. A verificação Prettier passou para os ficheiros suportados; a migration SQL foi excluída porque o projeto não possui parser SQL configurado no Prettier. O harness PostgreSQL local descartável passou cálculo, Gama, isolamento por organização, publicação concorrente, imutabilidade, constraints e rollback.

A suíte completa executou 831/833 testes: 229/231 ficheiros passaram. Os dois failures são contratos externos de `app_runtime` e Supabase sem configuração no sandbox, não testes de Costing.

A ausência de RLS continua uma pendência explícita; nenhum patch desta reconstrução deve ser interpretado como implementação de RLS.
