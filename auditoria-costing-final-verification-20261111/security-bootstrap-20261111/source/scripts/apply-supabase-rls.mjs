import { readFile } from "node:fs/promises";
import postgres from "postgres";

const databaseUrl = process.env.SUPABASE_DATABASE_URL;
const supabaseUrl = process.env.VITE_SUPABASE_URL;
const environment = process.env.SUPABASE_RLS_ENV;
const applyGlobal = process.env.SUPABASE_RLS_APPLY_GLOBAL === "true";

if (!databaseUrl || !supabaseUrl) {
  throw new Error(
    "SUPABASE_DATABASE_URL e VITE_SUPABASE_URL são obrigatórias; nenhuma conexão foi iniciada."
  );
}
if (environment !== "local" && environment !== "staging") {
  throw new Error(
    "SUPABASE_RLS_ENV deve ser explicitamente local ou staging; produção é recusada."
  );
}
if (environment === "staging" && process.env.SUPABASE_RLS_ALLOW_STAGING !== "true") {
  throw new Error(
    "Staging exige SUPABASE_RLS_ALLOW_STAGING=true; nenhuma conexão foi iniciada."
  );
}

const targetUrl = new URL(supabaseUrl);
const projectRef = targetUrl.hostname.split(".")[0];
if (!projectRef || projectRef === targetUrl.hostname) {
  throw new Error("Não foi possível determinar o project ref do Supabase.");
}
if (environment === "staging") {
  const allowed = (process.env.SUPABASE_RLS_ALLOWED_PROJECT_REFS ?? "")
    .split(",")
    .map(value => value.trim())
    .filter(Boolean);
  if (!allowed.includes(projectRef)) {
    throw new Error(
      `Project ref ${projectRef} não está na allowlist de staging; nenhuma conexão foi iniciada.`
    );
  }
}

const connectionUrl = new URL(databaseUrl);
if (environment === "local" && !["127.0.0.1", "localhost"].includes(connectionUrl.hostname)) {
  throw new Error(
    `Ambiente local só aceita PostgreSQL local; host recebido: ${connectionUrl.hostname}.`
  );
}
if (applyGlobal && process.env.SUPABASE_RLS_CONFIRM !== "APPLY_GLOBAL_RLS") {
  throw new Error(
    "A aplicação global exige SUPABASE_RLS_CONFIRM=APPLY_GLOBAL_RLS; Costing permanece separado."
  );
}

console.log(
  JSON.stringify({
    environment,
    projectRef,
    applyGlobal,
    targetHost: connectionUrl.hostname,
    status: "preflight-passed",
  })
);

const sql = postgres(databaseUrl, {
  prepare: false,
  max: 1,
  ssl: environment === "staging" ? "require" : false,
});
try {
  const costingMigration = await readFile(
    new URL("../drizzle/pg/0039_costing_rls_security.sql", import.meta.url),
    "utf8"
  );
  const statements = [];
  if (applyGlobal) {
    statements.push(
      await readFile(
        new URL("../drizzle/pg/rls_multitenant.sql", import.meta.url),
        "utf8"
      )
    );
  }
  statements.push(costingMigration);
  await sql.begin(async transaction => {
    for (const statement of statements) await transaction.unsafe(statement);
  });
  console.log(
    JSON.stringify({
      applied: [
        ...(applyGlobal ? ["rls_multitenant"] : []),
        "0039_costing_rls_security",
      ],
      status: "ok",
    })
  );
} finally {
  await sql.end({ timeout: 5 });
}
