import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("contexto RLS da role app_runtime", () => {
  it("abre transação curta, injeta identidade do request e reutiliza a conexão em chamadas tRPC", () => {
    const runtime = readFileSync(
      resolve(import.meta.dirname, "../server/lib/appRuntimeDb.ts"),
      "utf8"
    );
    const trpc = readFileSync(
      resolve(import.meta.dirname, "../server/_core/trpc.ts"),
      "utf8"
    );
    expect(runtime).toContain("transaction.execute(");
    expect(runtime).toContain("request.jwt.claim.sub");
    expect(runtime).toContain("request.app_user_id");
    expect(runtime).toContain("input.appUserId");
    expect(runtime).toContain("app_runtime.${projectRef}");
    expect(runtime).toContain("prepare: false");
    expect(runtime).toContain("db.transaction");
    expect(trpc).toContain("withRequestRuntimeDb(");
    expect(trpc).toContain("const supabaseAuthId = ctx.user.supabaseAuthId;");
    expect(trpc).toContain("if (!supabaseAuthId)");
    expect(trpc).toContain("supabaseAuthId,");
    expect(trpc).toContain("appUserId: ctx.user.id");
  });

  it("mantém a identidade app_runtime e as escritas de AI Agents no RLS canônico", () => {
    const rls = readFileSync(
      resolve(import.meta.dirname, "../drizzle/pg/rls_multitenant.sql"),
      "utf8"
    );

    expect(rls).toContain(
      "create or replace function private.current_app_runtime_user_id()"
    );
    expect(rls).toContain("current_setting('request.app_user_id', true)");
    expect(rls).toContain('"supabaseAuthId" = auth.uid()');
    expect(rls).toContain("security definer");
    expect(rls).toContain("set search_path = ''");
    expect(rls).toContain(
      "create or replace function private.current_authenticated_user_id()"
    );
    expect(rls).not.toContain("coalesce(");

    expect(rls).toContain("create policy ai_agents_app_runtime_insert");
    expect(rls).toContain("create policy ai_agents_app_runtime_update");
    expect(rls).toContain("create policy prompt_versions_app_runtime_insert");
    expect(rls).toContain("create policy prompt_versions_app_runtime_update");
    expect(rls).toContain(
      "revoke update on table public.users from app_runtime"
    );
    expect(rls).toContain(
      "grant update (name) on table public.users to app_runtime"
    );
    expect(rls).toContain(
      "create policy users_app_runtime_update_self on public.users"
    );
    expect(rls).toContain("using (id = private.current_app_runtime_user_id())");
    expect(rls).toContain("to app_runtime");
  });
});
