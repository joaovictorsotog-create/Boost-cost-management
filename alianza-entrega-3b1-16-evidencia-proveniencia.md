# Evidência de proveniência — entrega 3b-1-16

## Aplicação

- Repositório: `joaovictorsotog-create/alianza-ai-platform`
- Branch: `costing-security-preflight-final-20261112`
- HEAD: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`
- Pai: `16fde337f707734fbca13ac311f1ebe2d01a2472`
- Working tree local: limpa
- `origin/main` observado: `0bdd0306b5630f34c3daef6e03f5f47ec8925332`
- Merge-base com `main`: `1ac2573092990c8af2793055f1924e28ff0a2c5f`
- Commits exclusivos Costing/security contra a base: 46
- Commits exclusivos de `main` contra a base: 8
- Interseção de caminhos nos dois diffs: vazia

## Verificações executadas

```text
pnpm check
=> sucesso (tsc --noEmit)

pnpm vitest run \
  server/domain/costing/engine.test.ts \
  server/domain/costing/snapshot.test.ts \
  server/routers/costing.test.ts \
  server/pg-schema-conversion.contract.test.ts
=> 4 arquivos, 47 testes aprovados
```

## Segurança da evidência

A auditoria não acessou bancos remotos, Supabase, produção, staging persistente ou dados de clientes. Não foram copiados `.env`, credenciais, tokens, planilhas, dumps ou payloads reais. Os logs anexos contêm somente a saída dos comandos acima; o aviso de depreciação do Vitest não altera o resultado.

## Limite probatório

Os testes desta entrega são locais e não substituem bootstrap PostgreSQL vazio nem teste integrado com roles/RLS. A conclusão correta é compatibilidade parcial por camada, não homologação global.
