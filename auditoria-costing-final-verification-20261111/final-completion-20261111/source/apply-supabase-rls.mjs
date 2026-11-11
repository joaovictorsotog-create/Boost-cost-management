import { readFile } from "node:fs/promises";
import postgres from "postgres";

const databaseUrl = process.env.SUPABASE_DATABASE_URL;
const supabaseUrl = process.env.VITE_SUPABASE_URL;
if (!databaseUrl || !supabaseUrl)
  throw new Error(
    "SUPABASE_DATABASE_URL e VITE_SUPABASE_URL são obrigatórias."
  );

function normalizeDatabaseUrl(value) {
  const url = new URL(value);
  const projectRef = new URL(supabaseUrl).hostname.split(".")[0];
  if (!url.hostname.startsWith("db.")) return url.toString();
  url.hostname = "aws-0-sa-east-1.pooler.supabase.com";
  url.port = "6543";
  url.username = `postgres.${projectRef}`;
  url.searchParams.set("pgbouncer", "true");
  return url.toString();
}

const sql = postgres(normalizeDatabaseUrl(databaseUrl), {
  prepare: false,
  max: 1,
  ssl: "require",
});
try {
  const migration = await readFile(
    new URL("../drizzle/pg/rls_multitenant.sql", import.meta.url),
    "utf8"
  );
  const costingMigration = await readFile(
    new URL("../drizzle/pg/0039_costing_rls_security.sql", import.meta.url),
    "utf8"
  );
  await sql.begin(async transaction => {
    await transaction.unsafe(migration);
    await transaction.unsafe(costingMigration);
  });
  console.log(
    JSON.stringify({
      applied: ["rls_multitenant", "0039_costing_rls_security"],
      status: "ok",
    })
  );
} finally {
  await sql.end({ timeout: 5 });
}
