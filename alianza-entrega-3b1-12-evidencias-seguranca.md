# Entrega 3B.1.12 — Evidências de segurança e integridade

## Escopo verificado

Os comandos foram executados sobre os objetos Git, sem alterar o repositório da aplicação:

```text
BASE_REMOTA=27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801
BASE_LOCAL=0ee6d280f39e0ac1a6c15caaa00fb2f14f71a285
FINAL=16fde337f707734fbca13ac311f1ebe2d01a2472
```

## Integridade Git

- `git merge-base --is-ancestor BASE_REMOTA FINAL`: PASS.
- `git merge-base --is-ancestor BASE_LOCAL FINAL`: PASS.
- `git rev-list --count BASE_REMOTA..FINAL`: `5`.
- `git rev-list --count BASE_LOCAL..FINAL`: `1`.
- Pai de `FINAL`: `BASE_LOCAL`.
- `git diff --check BASE_REMOTA FINAL`: PASS.
- Diff completo: 159.356 bytes.
- SHA-256 do diff: `82049d3075c55281ae29adff0972eebbd66926e7b52b3cb3631b62ee2d56b777`.

## Varredura de segredos

Foram procurados nos conteúdos finais dos 17 caminhos alterados:

- `BEGIN RSA/OPENSSH/EC/PGP PRIVATE KEY`;
- chaves AWS `AKIA...`;
- GitHub PATs `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`;
- atribuições literais de `password`, `secret`, `token` e `api_key`;
- URLs `postgresql://user:password@host`.

**Resultado:** nenhuma ocorrência.

## Varredura de nomes e artefatos

Nos caminhos alterados não foram encontrados:

- `.env` ou arquivos de configuração local;
- arquivos de credenciais, secrets, tokens ou chaves;
- `.pem`, `.key`, `.crt` ou logs;
- dumps, backups, arquivos temporários ou diretórios `tmp`/`temp`;
- `node_modules`, `dist` ou `build`.

`template.json` existe na árvore final, mas não pertence ao diff entre as bases e não seria incluído na publicação da branch para auditoria.

## Limitação da evidência

A varredura é estática e baseada em padrões. Ela não substitui revisão humana de lógica nem prova ausência de dados secretos codificados de forma não reconhecida. Ainda assim, nenhum segredo, credencial, host com senha ou dado de produção foi observado no diff entre a base remota e o commit final.

## Verificações não executadas por restrição

Nesta rodada não foram executados:

- push da aplicação;
- PR, merge, rebase ou cherry-pick;
- deploy;
- migration, DDL ou DML em banco persistente;
- conexão com Supabase ou produção.
