import postgres from "postgres";
import { publishCostStructure } from "../server/db/costing";

const url = process.env.SUPABASE_DATABASE_URL;
const barrierId = process.env.COSTING_BARRIER_ID;
const organizationId = process.env.COSTING_ORGANIZATION_ID;
const structureId = process.env.COSTING_STRUCTURE_ID;
if (!url || !barrierId || !organizationId || !structureId) {
  throw new Error("missing publication worker configuration");
}

const barrierDb = postgres(url, { max: 1 });
const startedAt = Date.now();
let exitCode = 0;
try {
  const [session] = await barrierDb`select pg_backend_pid() as pid`;
  await barrierDb`
    INSERT INTO "costing_verification_barriers" ("id", "ready", "released")
    VALUES (${barrierId}, 1, false)
    ON CONFLICT ("id") DO UPDATE
    SET "ready" = "costing_verification_barriers"."ready" + 1
  `;
  for (;;) {
    const [barrier] = await barrierDb`
      SELECT "released" FROM "costing_verification_barriers"
      WHERE "id" = ${barrierId}
    `;
    if (barrier?.released) break;
    await barrierDb`select pg_sleep(0.02)`;
  }

  const result = await publishCostStructure(organizationId, structureId);
  console.log(
    JSON.stringify({
      status: "fulfilled",
      backendPid: session?.pid,
      structureId,
      publishedStatus: result.published.status,
      supersededStructureIds: result.supersededStructureIds,
      startedAt,
      finishedAt: Date.now(),
    })
  );
} catch (error) {
  console.log(
    JSON.stringify({
      status: "rejected",
      structureId,
      error: String(error),
      startedAt,
      finishedAt: Date.now(),
    })
  );
  exitCode = 1;
} finally {
  await barrierDb.end();
  // The real service owns a separate postgres pool. This worker is a
  // one-shot process, so terminate after the result is flushed instead of
  // leaving the pool's idle socket alive indefinitely.
  process.exit(exitCode);
}
