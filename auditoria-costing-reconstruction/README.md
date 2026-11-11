# Alianza Costing — reconstrução técnica para auditoria

Esta pasta disponibiliza, para revisão independente, o conteúdo extraído do pacote `alianza-costing-reconstruction-package-0e1457c.tar.gz`.

## Proveniência

- Repositório Boost: `joaovictorsotog-create/Boost-cost-management`
- Commit de base do repositório Boost: `fc674038281c07edad49b43d37fa2b00529073b2`
- Branch desta disponibilização: `audit-costing-reconstruction-20261111`
- Pacote original: `alianza-costing-reconstruction-package-0e1457c.tar.gz`
- SHA-256 do pacote original: `e1fc3ef9c4fab5df3405d620a3399f5ba2978fcc35207a718ed6c02da83a6715`
- Localização do conteúdo extraído: `package/`

O `.bundle` binário foi deliberadamente excluído desta disponibilização. Continua preservado no pacote original fora deste repositório e não foi alterado.

A origem da implementação é uma reconstrução técnica a partir de patches recuperados. Esta disponibilização não declara a implementação aprovada nem declara a recuperação dos commits Git antigos.

## Conteúdo extraído e hashes SHA-256

- `package/README.md` (1879 bytes) — `92183a763af6feadeb60953c50a23c298a543a5ce69ad1a8c435fbbbe3de3414`
- `package/SHA256SUMS` (3605 bytes) — `9e87e4de6abfe2695d7065ba2c93a6ed65bff1e06df02188077bb1ddf57719b4`
- `package/changed-files.txt` (362 bytes) — `0fc560844389cb5d7440c88ba9efa7379b0a75402c5d26eafb9d9aa5437a85bd`
- `package/evidence/branch-comparison.txt` (1214 bytes) — `97a9875c1c5f5b227be91f6144f3863f436dbe802c2939aa84e1ddd9429e6e6a`
- `package/evidence/bundle-heads.txt` (46 bytes) — `f867c67cb56d330e1a02b4b5dc6e904e550521278ac6bec3d710f740de9f77ac`
- `package/evidence/bundle-verify.txt` (157 bytes) — `cf29471407200836d8a211934106c5ea8e9adff7526a02d68d8540afbafb6307`
- `package/evidence/full-suite-summary.txt` (559 bytes) — `5fead5854a9d462a423b8a1a86ca4edaa1ecf68827a89ee44d4407518ce9029f`
- `package/evidence/git-diff-check.txt` (0 bytes) — `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `package/evidence/git-log.txt` (2015 bytes) — `fcff7ac4b2f5b0300490fc2f607dfabb7ce7ed06661b8304d29c1c18ab410f6e`
- `package/evidence/git-status.txt` (134 bytes) — `8a1284969f006d9b61c097c06766781fba810ec78599dbda761a5f1897b813c3`
- `package/evidence/postgresql-integration-and-rollback.txt` (626 bytes) — `7ba35c28b845d831a552c86c787ed602c456a7546a525cfe962bfbd05bea6f21`
- `package/evidence/prettier.txt` (125 bytes) — `3c27cd1e9ef238d01a8a70933e6cf868715ef22977b669396ab113f070415bc4`
- `package/evidence/targeted-tests.txt` (511 bytes) — `9dc047a4d54da1ed6eeca3c1f4273d1bd8e88d5854ccab44597079757f23b22e`
- `package/evidence/typecheck.txt` (79 bytes) — `0f89e85059f71f5474ba6998624cc99438288c8aa33f99497eb9eaaa2313243a`
- `package/files/drizzle/pg/0036_costing_foundation.sql` (6298 bytes) — `09a67f4f3d676118a29f74e613aa18e83ad8b25161c1d3da8b3ce53fcce85fa2`
- `package/files/drizzle/pg/schema.costing.ts` (9112 bytes) — `6a08050f83402ce42a70cf2f5c6390922dd64f44a6ae0052318c9033966619a6`
- `package/files/server/db/costing.ts` (7501 bytes) — `95ea167acaf45d9132fa5b1ffe17e025ade2841129cdcfdb41b9c241fb90368a`
- `package/files/server/db.ts` (6073 bytes) — `1ac4821db76daf7e90a595d8bfaf89dc2321caec60fcc970ef388256efe6e27d`
- `package/files/server/domain/costing/engine.test.ts` (19625 bytes) — `7b5ec9da10932a79d637f517d87e522e4b296a7666e668608b7b900fb05ee868`
- `package/files/server/domain/costing/engine.ts` (19596 bytes) — `4735046ed013f64bbe1761aa103f17d6343c3c781e9cb9470877284ca2d3fc26`
- `package/files/server/domain/costing/snapshot.test.ts` (5169 bytes) — `6bf300348cfa85aea0fb362c9b14da9c58c95572cde4cf8f67477fb0cdc810ab`
- `package/files/server/domain/costing/snapshot.ts` (3995 bytes) — `31a1f707b1fc6f48e374870c86c5602e0b46ac3b0b95dc59ef3123a995479f60`
- `package/files/server/domain/costing/structure-publication.ts` (1766 bytes) — `39cfb331ec98f5ab23ef6b40c16b0257664560bcd34529c0817a27ef4500febb`
- `package/files/server/routers/costing.test.ts` (446 bytes) — `cd66f7631562a29ca0fe60066c71c4d5bd4d77d99a1696098535067a8512c331`
- `package/files/server/routers/costing.ts` (4661 bytes) — `73867ad1c6d047220091f3f34332f2631d95703c41a35ab46fd6b075d96c2467`
- `package/files/tsconfig.json` (681 bytes) — `427d09c3888aa9d12a5c1b3e8a5f31f779d46edb5bf0d5d2bfda9f2ed39ca623`
- `package/patches/000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0e1457cb5a72bca6b4310bd650897c9f9080ad94.patch` (133487 bytes) — `04ce697040ecb7bea42a5ec80f10e10f60b4597efd110f0daf987f53a7b8cd84`
- `package/patches/001-5415538f70001b321ecb0443f65a35e517bbb48e.patch` (125778 bytes) — `33c3ebd187f36ec1a02c48bae377867a388756650d97a0eac0f94da8be4482e4`
- `package/patches/002-0e1457cb5a72bca6b4310bd650897c9f9080ad94.patch` (23558 bytes) — `2b96aeb78e3e05c61187c2a861d9e85cee7f847b356b43220bca971a0debdc7c`
- `package/source-patches/000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c.patch` (124643 bytes) — `103d3ce81c292605f601b1081d0fda49021bd84960a6fc1641cf131ccdd3639d`
- `package/source-patches/alianza-costing-audit-corrections-0fad8b9..0ee6d28.patch` (22692 bytes) — `af03aee5f5c07b794e974d20f6aa0c7ad7f537a99fbc52d0d4fb62851f53d287`
- `package/source-patches/normalized-000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c.patch` (93621 bytes) — `b554d0ad7deabddf23ce84ef5b6964ea5e0b58bb17e822b618be53f5fab29693`
- `package/source-patches/normalized-alianza-costing-audit-corrections-0fad8b9..0ee6d28.patch` (17726 bytes) — `08b2ae327de08ca537c45774163c30d07d3e72485807693c4d4d8c152c8f6a51`

## Árvore

```text
  package/README.md
  package/SHA256SUMS
  package/changed-files.txt
  package/evidence/branch-comparison.txt
  package/evidence/bundle-heads.txt
  package/evidence/bundle-verify.txt
  package/evidence/full-suite-summary.txt
  package/evidence/git-diff-check.txt
  package/evidence/git-log.txt
  package/evidence/git-status.txt
  package/evidence/postgresql-integration-and-rollback.txt
  package/evidence/prettier.txt
  package/evidence/targeted-tests.txt
  package/evidence/typecheck.txt
  package/files/drizzle/pg/0036_costing_foundation.sql
  package/files/drizzle/pg/schema.costing.ts
  package/files/server/db/costing.ts
  package/files/server/db.ts
  package/files/server/domain/costing/engine.test.ts
  package/files/server/domain/costing/engine.ts
  package/files/server/domain/costing/snapshot.test.ts
  package/files/server/domain/costing/snapshot.ts
  package/files/server/domain/costing/structure-publication.ts
  package/files/server/routers/costing.test.ts
  package/files/server/routers/costing.ts
  package/files/tsconfig.json
  package/patches/000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0e1457cb5a72bca6b4310bd650897c9f9080ad94.patch
  package/patches/001-5415538f70001b321ecb0443f65a35e517bbb48e.patch
  package/patches/002-0e1457cb5a72bca6b4310bd650897c9f9080ad94.patch
  package/source-patches/000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c.patch
  package/source-patches/alianza-costing-audit-corrections-0fad8b9..0ee6d28.patch
  package/source-patches/normalized-000-full-27df6b0ba4ebff3785b6bf5e62bcfdeb4ebb7801..0fad8b9c144ab6b0d2b070bdb36e2d2bb4df294c.patch
  package/source-patches/normalized-alianza-costing-audit-corrections-0fad8b9..0ee6d28.patch
```

O manifesto original está preservado em `package/SHA256SUMS`. Os hashes acima foram calculados novamente sobre os ficheiros efetivamente disponibilizados no repositório.
