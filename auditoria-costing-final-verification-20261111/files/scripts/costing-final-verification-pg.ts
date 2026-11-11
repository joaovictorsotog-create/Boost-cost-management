import { once } from "node:events";
import { spawn } from "node:child_process";
import { resolve } from "node:path";
import postgres from "postgres";

const url = process.env.SUPABASE_DATABASE_URL;
if (!url) throw new Error("database unavailable");

const admin = postgres(url, { max: 1 });
const root = process.cwd();
const worker = resolve(root, "scripts/costing-publish-worker.ts");
const events: Array<Record<string, unknown>> = [];

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function waitForPending(
  promise: Promise<unknown>,
  label: string
): Promise<{ settled: boolean; value?: unknown }> {
  let settled = false;
  let value: unknown;
  const observed = promise.then(
    result => {
      settled = true;
      value = result;
    },
    error => {
      settled = true;
      value = error;
    }
  );
  await sleep(120);
  events.push({ label, waited: !settled, at: Date.now() });
  assert(!settled, `${label} did not wait for the competing lock`);
  return { settled, value };
}

async function beginWithSession(
  db: ReturnType<typeof postgres>,
  label: string
) {
  const [session] = await db`select pg_backend_pid() as pid`;
  await db`begin`;
  await db`set local statement_timeout = '5000'`;
  events.push({ label, backendPid: session?.pid, at: Date.now() });
  return session?.pid;
}

async function lockPublication(
  db: ReturnType<typeof postgres>,
  organizationId: string,
  itemId: string,
  targetId: string
) {
  return db`
    SELECT "id", "status"
    FROM "cost_structures"
    WHERE "organizationId" = ${organizationId}
      AND "itemId" = ${itemId}
      AND ("id" = ${targetId} OR "status" = 'ACTIVE')
    ORDER BY "organizationId", "id"
    FOR UPDATE
  `;
}

async function publishLocked(
  db: ReturnType<typeof postgres>,
  organizationId: string,
  itemId: string,
  targetId: string
) {
  await db`
    UPDATE "cost_structures"
    SET "status" = 'SUPERSEDED', "updatedAt" = 'now'
    WHERE "organizationId" = ${organizationId}
      AND "itemId" = ${itemId}
      AND "status" = 'ACTIVE'
  `;
  await db`
    UPDATE "cost_structures"
    SET "status" = 'ACTIVE', "updatedAt" = 'now'
    WHERE "organizationId" = ${organizationId}
      AND "id" = ${targetId}
      AND "status" = 'DRAFT'
  `;
}

type Operation = "insert" | "update" | "delete" | "move";

async function setupMutationCase(name: string, operation: Operation) {
  const itemId = `verify-item-${name}`;
  const oldId = `verify-${name}-old`;
  const targetId = `verify-${name}-draft`;
  const destinationId = `verify-${name}-destination`;
  const lineId = `verify-${name}-line`;
  await admin`
    INSERT INTO "cost_items" ("id","organizationId","name","itemType","referenceUnit","active","createdAt","updatedAt")
    VALUES (${itemId},'org-verification',${name},'COMPOSITE','un',true,'now','now')
  `;
  await admin`
    INSERT INTO "cost_structures" ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt")
    VALUES
      (${oldId},'org-verification',${itemId},1,'ACTIVE','1','now','now'),
      (${targetId},'org-verification',${itemId},2,'DRAFT','1','now','now'),
      (${destinationId},'org-verification',${itemId},3,'DRAFT','1','now','now')
  `;
  if (operation !== "insert") {
    await admin`
      INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
      VALUES (${lineId},'org-verification',${targetId},'verify-source','1','un',0,'now','now')
    `;
  }
  return { itemId, oldId, targetId, destinationId, lineId };
}

async function mutate(
  db: ReturnType<typeof postgres>,
  operation: Operation,
  ids: Awaited<ReturnType<typeof setupMutationCase>>
) {
  if (operation === "insert") {
    return db`
      INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
      VALUES (${ids.lineId},'org-verification',${ids.targetId},'verify-source','1','un',0,'now','now')
    `;
  }
  if (operation === "update") {
    return db`
      UPDATE "cost_structure_lines"
      SET "quantity" = '2', "notes" = 'verification-update'
      WHERE "id" = ${ids.lineId}
    `;
  }
  if (operation === "delete") {
    return db`DELETE FROM "cost_structure_lines" WHERE "id" = ${ids.lineId}`;
  }
  return db`
    UPDATE "cost_structure_lines"
    SET "structureId" = ${ids.destinationId}, "updatedAt" = 'now'
    WHERE "id" = ${ids.lineId}
  `;
}

async function runMutationRace(
  operation: Operation,
  winner: "mutation" | "publication"
) {
  const name = `${operation}-${winner}`;
  const ids = await setupMutationCase(`${operation[0]}${winner[0]}`, operation);
  const mutationDb = postgres(url, { max: 1 });
  const publicationDb = postgres(url, { max: 1 });
  try {
    const mutationPid = await beginWithSession(mutationDb, `${name}:mutation`);
    const publicationPid = await beginWithSession(
      publicationDb,
      `${name}:publication`
    );
    events.push({
      case: name,
      operation,
      winner,
      mutationPid,
      publicationPid,
      barrier: "both transactions began before the critical section",
    });

    if (winner === "mutation") {
      await mutate(mutationDb, operation, ids);
      const publicationLock = lockPublication(
        publicationDb,
        "org-verification",
        ids.itemId,
        ids.targetId
      );
      await waitForPending(publicationLock, `${name}:publication-lock`);
      await mutationDb`commit`;
      await publicationLock;
      await publishLocked(
        publicationDb,
        "org-verification",
        ids.itemId,
        ids.targetId
      );
      await publicationDb`commit`;
      events.push({
        case: name,
        result: "mutation-committed-before-publication",
      });
    } else {
      await lockPublication(
        publicationDb,
        "org-verification",
        ids.itemId,
        ids.targetId
      );
      const mutationResult = mutate(mutationDb, operation, ids).then(
        () => ({ ok: true }),
        error => ({ ok: false, error: String(error) })
      );
      await waitForPending(mutationResult, `${name}:mutation-lock`);
      await publishLocked(
        publicationDb,
        "org-verification",
        ids.itemId,
        ids.targetId
      );
      await publicationDb`commit`;
      const result = await mutationResult;
      assert(
        !result.ok,
        `${name}: mutation unexpectedly changed a published structure`
      );
      await mutationDb`rollback`;
      events.push({
        case: name,
        result: "publication-committed-before-mutation",
        mutationError: result.error,
      });
    }

    const structures = await admin`
      SELECT "id", "status" FROM "cost_structures"
      WHERE "organizationId" = 'org-verification' AND "itemId" = ${ids.itemId}
      ORDER BY "id"
    `;
    const lines = await admin`
      SELECT "id", "structureId", "quantity", "notes"
      FROM "cost_structure_lines"
      WHERE "organizationId" = 'org-verification'
        AND "id" = ${ids.lineId}
    `;
    assert(
      structures.filter(row => row.status === "ACTIVE").length === 1,
      `${name}: expected exactly one ACTIVE structure`
    );
    assert(
      structures.find(row => row.id === ids.oldId)?.status === "SUPERSEDED",
      `${name}: previous ACTIVE was not SUPERSEDED`
    );
    const line = lines[0];
    if (winner === "mutation") {
      if (operation === "delete")
        assert(!line, `${name}: deleted line remained`);
      if (operation === "move")
        assert(
          line?.structureId === ids.destinationId,
          `${name}: line was not moved`
        );
      if (operation === "update")
        assert(
          line?.quantity === "2.000",
          `${name}: line quantity was not updated`
        );
      if (operation === "insert")
        assert(
          line?.structureId === ids.targetId,
          `${name}: inserted line missing from target`
        );
    } else {
      if (operation === "insert")
        assert(!line, `${name}: rejected insert left a line`);
      if (operation === "move")
        assert(
          line?.structureId === ids.targetId,
          `${name}: rejected move changed the line`
        );
      if (operation === "update")
        assert(
          line?.quantity === "1.000",
          `${name}: rejected update changed the line`
        );
      if (operation === "delete")
        assert(
          line?.structureId === ids.targetId,
          `${name}: rejected delete removed the line`
        );
    }
    events.push({
      case: name,
      finalStructures: structures,
      finalLine: line ?? null,
    });
  } finally {
    await Promise.all([mutationDb.end(), publicationDb.end()]);
  }
}

async function waitForBarrier(id: string) {
  for (let i = 0; i < 500; i += 1) {
    const [row] = await admin`
      SELECT "ready" FROM "costing_verification_barriers" WHERE "id" = ${id}
    `;
    if (Number(row?.ready) === 2) return;
    await sleep(20);
  }
  throw new Error(`barrier ${id} was not reached`);
}

async function runServicePublicationPair(
  label: string,
  pairs: Array<{ organizationId: string; itemId: string; structureId: string }>
) {
  const barrierId = `barrier-${label}`;
  await admin`
    INSERT INTO "costing_verification_barriers" ("id", "ready", "released")
    VALUES (${barrierId}, 0, false)
  `;
  const children = pairs.map(pair => {
    const child = spawn("pnpm", ["exec", "tsx", worker], {
      cwd: root,
      env: {
        ...process.env,
        SUPABASE_DATABASE_URL: url,
        COSTING_BARRIER_ID: barrierId,
        COSTING_ORGANIZATION_ID: pair.organizationId,
        COSTING_STRUCTURE_ID: pair.structureId,
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", chunk => (stdout += String(chunk)));
    child.stderr.on("data", chunk => (stderr += String(chunk)));
    const closePromise = once(child, "close") as Promise<[number]>;
    return {
      child,
      pair,
      closePromise,
      getOutput: () => ({ stdout, stderr }),
    };
  });
  await waitForBarrier(barrierId);
  await admin`
    UPDATE "costing_verification_barriers" SET "released" = true WHERE "id" = ${barrierId}
  `;
  const results = [];
  for (const entry of children) {
    const [code] = await entry.closePromise;
    const output = entry.getOutput();
    const jsonLine = output.stdout
      .trim()
      .split("\n")
      .map(line => line.trim())
      .filter(line => line.startsWith("{"))
      .at(-1);
    assert(jsonLine, `${label}: worker produced no JSON: ${output.stderr}`);
    results.push({ ...JSON.parse(jsonLine), exitCode: code });
  }
  await admin`DELETE FROM "costing_verification_barriers" WHERE "id" = ${barrierId}`;
  events.push({ label, serviceResults: results });
  return results;
}

try {
  await admin`
    INSERT INTO "organizations" ("id", "name", "slug", "createdAt", "updatedAt")
    VALUES ('org-verification','Verification Org','verification-org',0,0)
    ON CONFLICT ("id") DO NOTHING
  `;
  await admin`
    INSERT INTO "cost_items" ("id","organizationId","name","itemType","referenceUnit","active","createdAt","updatedAt")
    VALUES ('verify-source','org-verification','Verification source','SIMPLE','un',true,'now','now')
  `;
  await admin`
    CREATE TABLE IF NOT EXISTS "costing_verification_barriers" (
      "id" varchar(120) PRIMARY KEY,
      "ready" integer NOT NULL DEFAULT 0,
      "released" boolean NOT NULL DEFAULT false
    )
  `;

  for (const operation of [
    "insert",
    "update",
    "delete",
    "move",
  ] as Operation[]) {
    await runMutationRace(operation, "mutation");
    await runMutationRace(operation, "publication");
  }

  await admin`
    INSERT INTO "cost_items" ("id","organizationId","name","itemType","referenceUnit","active","createdAt","updatedAt")
    VALUES
      ('service-same-item','org-verification','Service same item','COMPOSITE','un',true,'now','now'),
      ('service-independent-a','org-verification','Service independent A','COMPOSITE','un',true,'now','now'),
      ('service-independent-b','org-verification','Service independent B','COMPOSITE','un',true,'now','now')
  `;
  await admin`
    INSERT INTO "cost_structures" ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt")
    VALUES
      ('service-same-old','org-verification','service-same-item',1,'ACTIVE','1','now','now'),
      ('service-same-draft-a','org-verification','service-same-item',2,'DRAFT','1','now','now'),
      ('service-same-draft-b','org-verification','service-same-item',3,'DRAFT','1','now','now'),
      ('service-ind-a-old','org-verification','service-independent-a',1,'ACTIVE','1','now','now'),
      ('service-ind-a-draft','org-verification','service-independent-a',2,'DRAFT','1','now','now'),
      ('service-ind-b-old','org-verification','service-independent-b',1,'ACTIVE','1','now','now'),
      ('service-ind-b-draft','org-verification','service-independent-b',2,'DRAFT','1','now','now')
  `;

  const same = await runServicePublicationPair("same-item", [
    {
      organizationId: "org-verification",
      itemId: "service-same-item",
      structureId: "service-same-draft-a",
    },
    {
      organizationId: "org-verification",
      itemId: "service-same-item",
      structureId: "service-same-draft-b",
    },
  ]);
  assert(
    same.filter(result => result.status === "fulfilled").length >= 1,
    `same-item service race had no successful publication: ${JSON.stringify(same)}`
  );
  const sameStructures = await admin`
    SELECT "id", "status" FROM "cost_structures"
    WHERE "organizationId" = 'org-verification' AND "itemId" = 'service-same-item'
    ORDER BY "id"
  `;
  assert(
    sameStructures.filter(row => row.status === "ACTIVE").length === 1,
    "same-item service race left multiple ACTIVE structures"
  );
  assert(
    sameStructures.find(row => row.id === "service-same-old")?.status ===
      "SUPERSEDED",
    "same-item old structure not superseded"
  );
  const sameDrafts = sameStructures.filter(
    row => row.id !== "service-same-old"
  );
  assert(
    sameDrafts.some(row => row.status === "ACTIVE") &&
      sameDrafts.every(row =>
        ["ACTIVE", "SUPERSEDED", "DRAFT"].includes(String(row.status))
      ),
    `same-item service race left an invalid draft state: ${JSON.stringify(sameStructures)}`
  );

  const independent = await runServicePublicationPair("independent-items", [
    {
      organizationId: "org-verification",
      itemId: "service-independent-a",
      structureId: "service-ind-a-draft",
    },
    {
      organizationId: "org-verification",
      itemId: "service-independent-b",
      structureId: "service-ind-b-draft",
    },
  ]);
  assert(
    independent.every(result => result.status === "fulfilled"),
    "independent service publications did not both succeed"
  );
  const independentA = await admin`
    SELECT "status" FROM "cost_structures" WHERE "id" = 'service-ind-a-draft'
  `;
  const independentB = await admin`
    SELECT "status" FROM "cost_structures" WHERE "id" = 'service-ind-b-draft'
  `;
  assert(
    independentA[0]?.status === "ACTIVE" &&
      independentB[0]?.status === "ACTIVE",
    "independent items did not publish"
  );

  console.log(
    JSON.stringify(
      {
        lineMutationCases: events.filter(
          event => typeof event.case === "string"
        ),
        publicationService: events.filter(event => event.serviceResults),
        independentServiceOverlap: independent.map(result => ({
          backendPid: result.backendPid,
          startedAt: result.startedAt,
          finishedAt: result.finishedAt,
        })),
      },
      null,
      2
    )
  );
} finally {
  await admin.end();
}
