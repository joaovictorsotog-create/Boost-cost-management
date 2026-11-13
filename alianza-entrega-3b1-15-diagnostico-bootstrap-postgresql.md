# Alianza — Diagnóstico do bootstrap PostgreSQL

## Escopo

Auditoria exclusivamente de leitura da branch remota `costing-security-preflight-final-20261112` do repositório `joaovictorsotog-create/alianza-ai-platform`. Não foram executados migrations, DDL, DML, conexões Supabase ou banco persistente. Nenhum arquivo da aplicação foi alterado.

## Estado Git remoto confirmado

Consulta direta a `git ls-remote` e clone temporário somente para leitura:

- `main`: `0bdd0306b5630f34c3daef6e03f5f47ec8925332`
- `costing-security-preflight-final-20261112`: `ecbd686b2c58c46ec7c114c07e3bf22fdfbab028`
- ancestral comum: `1ac2573092990c8af2793055f1924e28ff0a2c5f`
- commits exclusivos da branch Costing: 46
- commits exclusivos de `main`: 8
- caminhos sobrepostos no diff contra o ancestral: nenhum

Os números anteriores de divergência não foram reutilizados: os refs remotos foram consultados novamente nesta entrega.

## Conclusão

Não existe atualmente uma cadeia PostgreSQL comprovadamente instalável a partir de banco vazio. O diretório contém 41 arquivos SQL, sendo 40 numerados até `0036` e o payload `rls_multitenant.sql`; o journal PostgreSQL possui somente `0000` e `0001`, há duplicidades de numeração (`0007`, `0021`, `0027`, `0032`), lacuna `0016`, snapshots ausentes e a migration Costing `0036` não está journalizada.

O RLS global também não é um bootstrap independente: depende de baseline amplo, de `auth.uid()`, roles Supabase, helpers históricos e tabelas fora do Costing. Ele contém referência a `public.rls_auto_enable()` sem definição localizada. O preflight de conexão está protegido contra destinos incorretos, mas executar o payload global para validar Costing alteraria escopo de vários módulos.

A alternativa recomendada é um **baseline PostgreSQL autoritativo, versionado e reproduzível**, seguido de migrations incrementais reconciliadas. Não se recomenda reconstruir automaticamente a cadeia histórica nem executar `drizzle-kit migrate` sobre o estado atual.

## Prova de viabilidade

Ferramentas observadas nesta sessão:

- `psql`: disponível;
- `pg_isready`: disponível;
- `initdb`: ausente;
- `pg_ctl`: ausente;
- `postgres`: ausente;
- Docker/Podman: ausentes.

Não é possível criar um PostgreSQL descartável completo neste ambiente sem instalar/fornecer um servidor ou usar outro ambiente autorizado. Logo, não há aprovação de bootstrap: a prova fica **BLOQUEADA**.

## Recomendação de decisão

1. Aprovar um baseline PostgreSQL único e identificável por SHA.
2. Reconciliar o histórico sem renumerar nem fabricar journal.
3. Gerar uma instalação nova verificável em cluster descartável.
4. Aplicar `0036` somente depois de `organizations` e dependências estarem comprovadas.
5. Separar RLS Costing do payload global, mantendo um teste explícito dos demais módulos.
6. Só então publicar uma sequência incremental aprovada para uso persistente.
