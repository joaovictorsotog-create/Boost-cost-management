# C. Publicação concorrente — análise independente

## Código executado

O teste auditado executa duas criações sequenciais de DRAFTs e, em seguida, inicia as publicações com `Promise.allSettled`:

```ts
const concurrentDrafts = [
  await createCostStructure({
    organizationId: "org-correction-a",
    itemId: "target-a",
  }),
  await createCostStructure({
    organizationId: "org-correction-a",
    itemId: "target-a",
  }),
];
const concurrent = await Promise.allSettled(
  concurrentDrafts.map(structure =>
    publishCostStructure("org-correction-a", structure.id)
  )
);
```

Depois, o teste consulta novamente todas as estruturas do item e exige exatamente uma `ACTIVE`:

```ts
const finalTargetStructures = await listCostStructures(
  "org-correction-a",
  "target-a"
);
assert(
  finalTargetStructures.filter(structure => structure.status === "ACTIVE").length === 1,
  "final target has more than one ACTIVE structure"
);
```

## Resultado observado

```text
concurrentPublication: ["fulfilled", "rejected"]
finalActiveForTarget: exatamente 1 estrutura ACTIVE
```

A transação rejeitada não deixa uma alteração parcial observável: a publicação ocorre dentro da transação do serviço; a atualização do ACTIVE anterior e a ativação do DRAFT são revertidas em conjunto quando a transação falha. O estado final SQL adicional confirmou:

```text
ACTIVE     1
DRAFT     12
INACTIVE   1
SUPERSEDED 3
```

A consulta direta de `active_count` retornou `1`.

## Conexões e sincronização

O código usa o cliente `postgres` singleton da aplicação, configurado com pool máximo de 5 conexões, e cada chamada a `db.transaction(...)` recebe uma sessão transacional do pool. As chamadas são iniciadas em paralelo por `Promise.allSettled`; a rejeição observada demonstra contenção real no banco.

Limitação: o harness não captura `pg_backend_pid()` nem instala uma barreira explícita (`pg_advisory_lock`, latch ou `pg_sleep`) para comprovar o número exato de sessões PostgreSQL simultâneas. Portanto, é possível afirmar que houve transações concorrentes observadas, mas não é possível afirmar, a partir deste artefacto, quantas conexões físicas independentes foram usadas em cada instante. Essa instrumentação fica pendente para uma auditoria posterior mais estrita.

## Ausência de alterações parciais

A publicação rejeitada não aparece como `ACTIVE`, `SUPERSEDED` ou estado inválido. A consulta final encontrou uma única ACTIVE e a restrição unique parcial permaneceu operacional. O teste não registra linhas nas duas DRAFTs concorrentes, portanto a preservação de conteúdo de linha em uma publicação rejeitada não é demonstrada por uma comparação de checksum; o estado estrutural e a atomicidade transacional são demonstrados.
