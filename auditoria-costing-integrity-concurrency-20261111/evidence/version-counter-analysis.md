# A. Contador de versões — análise independente

## Código SQL de inicialização

A migration auditada cria o contador e inicializa uma linha por item que já possui estruturas:

```sql
CREATE TABLE IF NOT EXISTS "cost_structure_version_counters" (
  "organizationId" varchar(32) NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "itemId" varchar(32) NOT NULL,
  "nextVersion" integer NOT NULL CHECK ("nextVersion" > 0),
  CONSTRAINT "cost_structure_version_counters_org_item_unique" UNIQUE ("organizationId", "itemId"),
  CONSTRAINT "cost_structure_version_counters_org_item_fk" FOREIGN KEY ("organizationId", "itemId") REFERENCES "cost_items" ("organizationId", "id") ON DELETE CASCADE
);
INSERT INTO "cost_structure_version_counters" ("organizationId", "itemId", "nextVersion")
SELECT "organizationId", "itemId", MAX("version") + 1
FROM "cost_structures"
GROUP BY "organizationId", "itemId"
ON CONFLICT ("organizationId", "itemId") DO UPDATE
SET "nextVersion" = GREATEST("cost_structure_version_counters"."nextVersion", EXCLUDED."nextVersion");
```

O código exato encontra-se também em `files/drizzle/pg/0037_costing_correction_integrity.sql`.

## Código TypeScript de reserva

```ts
const [versionRow] = await tx
  .select({ maxVersion: max(costStructures.version) })
  .from(costStructures)
  .where(
    and(
      eq(costStructures.organizationId, input.organizationId),
      eq(costStructures.itemId, input.itemId)
    )
  );
const [counter] = await tx
  .insert(costStructureVersionCounters)
  .values({
    organizationId: input.organizationId,
    itemId: input.itemId,
    nextVersion: Number(versionRow?.maxVersion ?? 0) + 1,
  })
  .onConflictDoUpdate({
    target: [
      costStructureVersionCounters.organizationId,
      costStructureVersionCounters.itemId,
    ],
    set: {
      nextVersion: sql`${costStructureVersionCounters.nextVersion} + 1`,
    },
  })
  .returning({ version: costStructureVersionCounters.nextVersion });
```

O transaction de criação utiliza `READ COMMITTED` deliberadamente. Ao contrário do cálculo de snapshots, essa transação não constrói um grafo de leitura consistente; a fronteira de consistência é a atualização atômica da linha do contador. Em `REPEATABLE READ`, a segunda transação pode receber `40001` depois de esperar por uma atualização legítima do mesmo contador devido ao snapshot antigo.

Há ainda retry máximo de três tentativas, somente para `40001` e `40P01`, repetindo a transação completa. Não existem efeitos externos entre a reserva e o `INSERT` da estrutura; se uma transação falhar, o contador e a estrutura são revertidos juntos.

## Resultado observado

- Fixtures iniciais do item `target-a`: versões `1`, `2`, `3` e `4`.
- A migration inicializou `nextVersion = 5`.
- A primeira criação posterior encontrou a linha existente e executou o ramo `DO UPDATE`, retornando `6`, não `5`.
- As dez criações simultâneas seguintes retornaram `7` a `16`.
- Foram observadas dez versões únicas, consecutivas e sem falhas.

## Pendência identificada: salto inicial

O resultado `7..16` não significa que as versões `1..6` já existissem todas como estruturas. A versão `6` foi a primeira DRAFT criada pelo próprio harness depois das versões legadas `1..4`; a versão `5` ficou sem utilização devido à interação entre a inicialização `MAX(version)+1` e o `DO UPDATE ... + 1` do primeiro `ON CONFLICT`.

Portanto, a implementação evita colisões concorrentes, mas possui um salto inicial de versão em itens que já têm contador pré-inicializado. A auditoria deve tratar a eliminação desse salto como pendência. Não foi feita correção nesta etapa documental.

## Escopos diferentes

Foram executadas dez criações adicionais em paralelo:

- cinco para `org-correction-a / target-c`;
- cinco para `org-correction-b / target-b`.

Todas completaram, preservando o isolamento por `(organizationId, itemId)`.

## Rollback

O harness abre uma transação, altera uma DRAFT, lança deliberadamente `rollback marker` e confirma depois que `outputQuantity` voltou ao valor original. A evidência integral está em `evidence/postgres-harness.txt`.
