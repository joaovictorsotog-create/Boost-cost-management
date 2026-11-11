import { and, eq, isNull } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { InsertUser, users } from "../drizzle/schema";
import { ENV } from "./_core/env";
import { normalizeSupabasePostgresUrl } from "./lib/supabasePostgres";
import { getRequestRuntimeDb } from "./lib/appRuntimeDb";

let _db: ReturnType<typeof drizzle> | null = null;
let _sql: ReturnType<typeof postgres> | null = null;

// Lazily create the drizzle instance so local tooling can run without a DB.
export async function getDb(): Promise<ReturnType<typeof drizzle> | null> {
  const requestRuntimeDb = getRequestRuntimeDb();
  if (requestRuntimeDb) return requestRuntimeDb as ReturnType<typeof drizzle>;
  if (!_db && process.env.SUPABASE_DATABASE_URL) {
    try {
      const databaseUrl = normalizeSupabasePostgresUrl(
        process.env.SUPABASE_DATABASE_URL,
        process.env.VITE_SUPABASE_URL
      );
      const localDatabase =
        new URL(databaseUrl).hostname === "127.0.0.1" ||
        new URL(databaseUrl).hostname === "localhost";
      const connectionOptions = localDatabase
        ? { ssl: false }
        : { ssl: "require" as const };
      _sql = postgres(databaseUrl, {
        prepare: false,
        max: 5,
        ...connectionOptions,
      });
      _db = drizzle(_sql, {
        logger: process.env.NODE_ENV === "development",
      });
    } catch (error) {
      console.warn("[Database] Failed to connect:", error);
      _db = null;
    }
  }
  return _db;
}

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) {
    throw new Error("User openId is required for upsert");
  }

  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot upsert user: database not available");
    return;
  }

  try {
    const values: InsertUser = {
      openId: user.openId,
    };
    const updateSet: Record<string, unknown> = {};

    const textFields = ["name", "email", "loginMethod"] as const;
    type TextField = (typeof textFields)[number];

    const assignNullable = (field: TextField) => {
      const value = user[field];
      if (value === undefined) return;
      const normalized = value ?? null;
      values[field] = normalized;
      updateSet[field] = normalized;
    };

    textFields.forEach(assignNullable);

    if (user.lastSignedIn !== undefined) {
      values.lastSignedIn = user.lastSignedIn;
      updateSet.lastSignedIn = user.lastSignedIn;
    }
    if (user.role !== undefined) {
      values.role = user.role;
      updateSet.role = user.role;
    } else if (user.openId === ENV.ownerOpenId) {
      values.role = "platform_admin";
      updateSet.role = "platform_admin";
    }
    if (user.supabaseAuthId !== undefined) {
      values.supabaseAuthId = user.supabaseAuthId;
      updateSet.supabaseAuthId = user.supabaseAuthId;
    }

    if (!values.lastSignedIn) {
      values.lastSignedIn = new Date();
    }

    if (Object.keys(updateSet).length === 0) {
      updateSet.lastSignedIn = new Date();
    }

    await db.insert(users).values(values).onConflictDoUpdate({
      target: users.openId,
      set: updateSet,
    });
  } catch (error) {
    console.error("[Database] Failed to upsert user:", error);
    throw error;
  }
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot get user: database not available");
    return undefined;
  }

  const result = await db
    .select()
    .from(users)
    .where(eq(users.openId, openId))
    .limit(1);

  return result.length > 0 ? result[0] : undefined;
}

export async function getUserByEmail(email: string) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db
    .select()
    .from(users)
    .where(eq(users.email, email.trim().toLowerCase()))
    .limit(1);

  return result.length > 0 ? result[0] : undefined;
}

export async function getUserBySupabaseAuthId(supabaseAuthId: string) {
  const db = await getDb();
  if (!db) return undefined;

  const result = await db
    .select()
    .from(users)
    .where(eq(users.supabaseAuthId, supabaseAuthId))
    .limit(1);

  return result.length > 0 ? result[0] : undefined;
}

export async function updateUserDisplayName(userId: number, name: string) {
  const db = await getDb();
  if (!db) throw new Error("Banco de dados indisponível");

  const [user] = await db
    .update(users)
    .set({ name: name.trim() })
    .where(eq(users.id, userId))
    .returning({ name: users.name });

  if (!user) throw new Error("Conta não encontrada");
  return user;
}

/**
 * Links a verified Supabase identity to an existing local account exactly once.
 * The NULL predicate makes the link race-safe and prevents replacing an
 * already-owned identity. The unique constraint on users.supabaseAuthId is a
 * second line of defense against cross-account linking.
 */
export async function linkSupabaseAuthIdentity(
  supabaseAuthId: string,
  email: string
) {
  const db = await getDb();
  if (!db) return undefined;

  const normalizedEmail = email.trim().toLowerCase();
  const linked = await db
    .update(users)
    .set({ supabaseAuthId, lastSignedIn: new Date() })
    .where(and(eq(users.email, normalizedEmail), isNull(users.supabaseAuthId)))
    .returning();

  return linked[0];
}

/**
 * Creates the local account for a verified Supabase identity that has no
 * legacy row yet. The openId is deterministic so concurrent first logins are
 * safe through the existing unique constraint.
 */
export async function provisionSupabaseAuthUser(
  supabaseAuthId: string,
  email: string
) {
  const normalizedEmail = email.trim().toLowerCase();
  const displayName = normalizedEmail.split("@")[0] || "Usuário";

  await upsertUser({
    openId: `supabase:${supabaseAuthId}`,
    name: displayName,
    email: normalizedEmail,
    loginMethod: "supabase",
    supabaseAuthId,
  });

  return getUserBySupabaseAuthId(supabaseAuthId);
}

// TODO: add feature queries here as your schema grows.
