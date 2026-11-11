import { defineConfig } from "drizzle-kit";
import { normalizeSupabasePostgresUrl } from "./server/lib/supabasePostgres";

const connectionString = process.env.SUPABASE_DATABASE_URL;
if (!connectionString) {
  throw new Error(
    "SUPABASE_DATABASE_URL is required for PostgreSQL Drizzle commands"
  );
}
const poolerConnectionString = normalizeSupabasePostgresUrl(
  connectionString,
  process.env.VITE_SUPABASE_URL
);

export default defineConfig({
  schema: ["./drizzle/schema.pg.ts", "./drizzle/pg/schema.costing.ts"],
  out: "./drizzle/pg",
  dialect: "postgresql",
  dbCredentials: {
    url: poolerConnectionString,
  },
});
