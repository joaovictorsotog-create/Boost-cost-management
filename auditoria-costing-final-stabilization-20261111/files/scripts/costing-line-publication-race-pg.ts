import postgres from "postgres";

const url = process.env.SUPABASE_DATABASE_URL;
if (!url) throw new Error("database unavailable");

const admin = postgres(url, { max: 1 });
const a = postgres(url, { max: 1 });
const b = postgres(url, { max: 1 });

try {
  await admin`
    INSERT INTO "cost_items" ("id","organizationId","name","itemType","referenceUnit","active","createdAt","updatedAt")
    VALUES
      ('race-item-a','org-correction-a','Race item A','COMPOSITE','un',true,'now','now'),
      ('race-item-b','org-correction-a','Race item B','COMPOSITE','un',true,'now','now')
  `;
  await admin`
    INSERT INTO "cost_structures" ("id","organizationId","itemId","version","status","outputQuantity","createdAt","updatedAt")
    VALUES
      ('race-a-old','org-correction-a','race-item-a',1,'ACTIVE','1','now','now'),
      ('race-a-draft','org-correction-a','race-item-a',2,'DRAFT','1','now','now'),
      ('race-b-old','org-correction-a','race-item-b',1,'ACTIVE','1','now','now'),
      ('race-b-draft','org-correction-a','race-item-b',2,'DRAFT','1','now','now')
  `;

  const [pidA, pidB] = await Promise.all([
    a`select pg_backend_pid() as pid`,
    b`select pg_backend_pid() as pid`,
  ]);
  if (pidA[0]?.pid === pidB[0]?.pid) {
    throw new Error("race test did not obtain independent PostgreSQL sessions");
  }

  // Barrier: both independent sessions are in a transaction before either
  // side starts its state transition.
  await Promise.all([a`begin`, b`begin`]);
  await a`
    INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
    VALUES ('race-a-line','org-correction-a','race-a-draft','source-a','1','un',0,'now','now')
  `;
  await a`commit`;
  await b`
    UPDATE "cost_structures" SET "status" = 'SUPERSEDED', "updatedAt" = 'now'
    WHERE "id" = 'race-a-old'
  `;
  await b`
    UPDATE "cost_structures" SET "status" = 'ACTIVE', "updatedAt" = 'now'
    WHERE "id" = 'race-a-draft'
  `;
  await b`commit`;

  await b`begin`;
  await b`
    SELECT "id" FROM "cost_structures"
    WHERE "id" = 'race-b-draft'
    FOR UPDATE
  `;
  await a`begin`;
  const rejectedInsert = a`
    INSERT INTO "cost_structure_lines" ("id","organizationId","structureId","componentItemId","quantity","quantityUnit","position","createdAt","updatedAt")
    VALUES ('race-b-line','org-correction-a','race-b-draft','source-a','1','un',0,'now','now')
  `;
  await b`
    UPDATE "cost_structures" SET "status" = 'SUPERSEDED', "updatedAt" = 'now'
    WHERE "id" = 'race-b-old'
  `;
  await b`
    UPDATE "cost_structures" SET "status" = 'ACTIVE', "updatedAt" = 'now'
    WHERE "id" = 'race-b-draft'
  `;
  await b`commit`;
  let rejected = false;
  try {
    await rejectedInsert;
  } catch (error) {
    rejected = String(error).includes(
      "Lines of published cost structures are immutable"
    );
  }
  await a`rollback`;
  if (!rejected)
    throw new Error("line insert after publication was not rejected");

  const [finalA] = await admin`
    SELECT "status" FROM "cost_structures" WHERE "id" = 'race-a-draft'
  `;
  const [finalB] = await admin`
    SELECT "status" FROM "cost_structures" WHERE "id" = 'race-b-draft'
  `;
  const [lineA] = await admin`
    SELECT count(*)::int AS count FROM "cost_structure_lines" WHERE "id" = 'race-a-line'
  `;
  const [lineB] = await admin`
    SELECT count(*)::int AS count FROM "cost_structure_lines" WHERE "id" = 'race-b-line'
  `;
  if (finalA?.status !== "ACTIVE" || finalB?.status !== "ACTIVE") {
    throw new Error("race publication did not produce ACTIVE structures");
  }
  if (lineA?.count !== 1 || lineB?.count !== 0) {
    throw new Error("race line state was not atomic");
  }
  console.log(
    JSON.stringify({
      independentBackendPids: [pidA[0]?.pid, pidB[0]?.pid],
      lineBeforePublication: "committed-before-publication",
      lineAfterPublication: "rejected",
      finalStatuses: [finalA?.status, finalB?.status],
      finalLineCounts: [lineA?.count, lineB?.count],
    })
  );
} finally {
  await Promise.all([a.end(), b.end(), admin.end()]);
}
