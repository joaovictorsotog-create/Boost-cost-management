# Alianza Costing — Security & CRUD Completion Audit

**Application repository:** `joaovictorsotog-create/alianza-ai-platform`
**Local branch:** `costing-security-bootstrap-final-20261111`
**Base:** `d9ff4dd7024674c54af128e4bdc816a0b459e22a`
**Final local commit:** `3350e6e884be85b410d31e5ca9e6d133b643bf7f`
**Documentary repository:** `joaovictorsotog-create/Boost-cost-management`
**Status:** technical evidence package only; **not production approval**.

## Scope and disposition

This round addressed the identified security boundary failure, application of Costing RLS, operational preflight, and missing DRAFT edit operations. It did not connect to production, deploy, change production roles/grants, or publish the application branch. RLS production deployment remains **pending**.

The `authenticated` path is now derived exclusively from `auth.uid()` mapped to `public.users.supabaseAuthId`. The `app_runtime` path is derived exclusively from the trusted transaction-local `request.app_user_id`, and its helper is not executable by `authenticated`. Legacy helper names remain only as compatibility wrappers that choose the already-separated identity by session role; new Costing policies use the explicit helpers.

## Mandatory audit questions — explicit answers

### 1. How is the version allocated under concurrency?

Publication locks the organization/item scope in deterministic order and allocates the next version through the organization/item counter row. The counter is locked before the publication state transition, so concurrent publishers serialize for the same item, while independent items can overlap. No version is allocated from an unlocked `MAX(version)` calculation.

### 2. Can a version be skipped or duplicated after a rollback/error?

The counter increment and publication transition occur in the same transaction. A failed transaction rolls both back; a committed publication consumes one version. The disposable PostgreSQL harness covers concurrent publication and reports the resulting active/superseded states and service PIDs. A database crash/recovery drill was not run in this round.

### 3. What protects published structures and their lines?

Integrity triggers reject UPDATE/DELETE of `ACTIVE`, `SUPERSEDED`, and `INACTIVE` structures and their lines. The RLS layer does not weaken those triggers. The final verification harness includes line INSERT/UPDATE/DELETE/move races against publication and records the expected immutable error.

### 4. What is the DRAFT lifecycle and what may be edited?

Groups and items can now be edited through tenant-scoped service methods and protected router procedures requiring `workspace.manage`. Draft structures/lines retain their existing lifecycle. Physical deletion is not introduced by this round. Published structures and snapshots remain immutable; changing an item reference unit after publication or snapshot creation is rejected.

### 5. How is tenant isolation enforced for authenticated clients and runtime writes?

Every Costing table is `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY`. `authenticated` has explicit SELECT policies based on `auth.uid()` membership. `app_runtime` has explicit tenant-scoped SELECT/INSERT/UPDATE/DELETE policies (snapshot tables are INSERT/SELECT only). Grants are least privilege and `anon` has no Costing access. A forged `request.app_user_id=B` with JWT identity A returns A data only; the before/after harness demonstrates the former leak and corrected result.

### 6. What happens if identity or required auth dependencies are missing?

The Costing migration fails closed if `auth.uid()`, `public.users`, or `public.organization_members` is absent. The apply script refuses unspecified or production environments, requires explicit staging allowlisting, rejects remote hosts for local mode, does not rewrite database hosts, and applies the global RLS script only with an explicit confirmation flag.

### 7. What is the rollback behavior and what remains unverified?

Migration rollback is not represented as an automatic down migration. Application transaction failures roll back their own writes; immutable publication state cannot be reverted by ordinary UPDATE/DELETE. A logical rollback/recovery test was not executed in this security round, so production rollback readiness remains pending. The original Costing rollback evidence is preserved in the parent package, and this round adds explicit immutable-state and failed-operation evidence.

## Verification results

- `pnpm check`: passed.
- Targeted Vitest: 32/32 passed.
- `run-costing-identity-boundary-pg.sh`: `IDENTITY_BOUNDARY_TEST=PASS`.
- `run-costing-rls-pg.sh`: `COSTING_RLS_TEST=PASS`; authenticated-without-JWT and anon cases included.
- `run-costing-final-verification-pg.sh`: first and second Drizzle migrations passed; CRUD service harness passed; mutation/publication concurrency passed.
- CRUD service marker: `COSTING_CRUD_EDIT_TEST=PASS`.
- Apply preflight cases: fail-closed cases passed; no database operation was performed by the preflight-only remote/production checks.

## Evidence map

- `artifacts/diff-d9ff4dd-to-3350e6e.patch`: complete local round diff.
- `artifacts/commit-3350e6e.patch`: individual commit evidence.
- `source/`: byte copies of final committed files.
- `evidence/identity-boundary-before-after.log`: before/after tenant identity proof.
- `evidence/rls-harness.log`: RLS policy, grants, tenant and immutability proof.
- `evidence/final-install-concurrency.log`: empty-DB installation, idempotency, CRUD and concurrency proof.
- `evidence/preflight-cases.txt`: environment safety evidence.

No statement in this package constitutes production approval. Production deployment of RLS remains pending independent audit and controlled release authorization.
