---
title: "Database Design Recommendations"
type: reference
status: active
date: 2026-03-10
applies-to: docs/plans/2026-03-10-feat-flutter-supabase-starter-kit-plan.md
skill-source: postgresql-table-design (v1.2.0)
---

# Database Design Recommendations

Concrete schema design, RLS policies, indexing, PowerSync compatibility, and
migration best practices for the Flutter + Supabase Starter Kit.

---

## 1. Schema Design

### 1.1 `notes` Table

```sql
-- supabase/migrations/00000000000000_create_notes.sql

CREATE TABLE public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (length(title) <= 500),
  body TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- REQUIRED: FK index (PostgreSQL does NOT auto-index FK columns)
CREATE INDEX notes_user_id_idx ON public.notes (user_id);

-- Supports "ORDER BY created_at DESC" in list queries
CREATE INDEX notes_created_at_idx ON public.notes (created_at);

-- Composite index for the most common query pattern:
-- "get my notes, newest first"
CREATE INDEX notes_user_id_created_at_idx ON public.notes (user_id, created_at DESC);

-- Trigger: auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_set_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.notes IS 'User notes - synced offline via PowerSync';
```

**Design decisions (per PostgreSQL skill):**

- **UUID for PK**: Required for PowerSync sync compatibility (client-generated
  IDs during offline creates). `gen_random_uuid()` as server default for any
  server-side inserts.
- **TIMESTAMPTZ, not TIMESTAMP**: Skill rule -- never use `timestamp` without
  timezone.
- **TEXT, not VARCHAR(n)**: Skill rule -- use `TEXT` with `CHECK` constraints
  for length limits instead of `VARCHAR(n)`.
- **NOT NULL on created_at/updated_at**: Skill rule -- add `NOT NULL` everywhere
  semantically required.
- **ON DELETE CASCADE on user_id FK**: When a Supabase user is deleted, their
  notes are cleaned up automatically.
- **FK index is manual**: PostgreSQL gotcha -- FK columns are NOT auto-indexed.
  The `notes_user_id_idx` is critical for join performance and preventing
  locking issues on parent deletes.

### 1.2 `subscriptions` Table

```sql
-- supabase/migrations/00000000000001_create_subscriptions.sql

CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'inactive'
    CHECK (status IN ('active', 'inactive', 'trial', 'grace_period', 'expired', 'cancelled')),
  product_id TEXT NOT NULL,
  original_purchase_date TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One active subscription per user (business rule)
CREATE UNIQUE INDEX subscriptions_user_id_unique_idx
  ON public.subscriptions (user_id);

-- Query pattern: "find all expiring subscriptions" (for admin/cron)
CREATE INDEX subscriptions_expires_at_idx
  ON public.subscriptions (expires_at)
  WHERE status = 'active';

-- Query pattern: webhook lookups by product
CREATE INDEX subscriptions_product_id_idx
  ON public.subscriptions (product_id);

CREATE TRIGGER subscriptions_set_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.subscriptions IS
  'Subscription state from RevenueCat webhooks - read-only on client via PowerSync';
```

**Design decisions:**

- **TEXT + CHECK for status**: Skill rule -- for business-logic-driven, evolving
  values, use `TEXT + CHECK` instead of `CREATE TYPE ... AS ENUM`. Subscription
  statuses may evolve as RevenueCat adds new event types.
- **UNIQUE index on user_id**: Enforces one subscription row per user. The
  webhook upserts (not inserts) on each event.
- **Partial index on expires_at**: Only indexes active subscriptions -- saves
  space and speeds up the "expiring soon" query pattern.
- **original_purchase_date**: RevenueCat provides this; useful for analytics and
  grace period calculations.

---

## 2. Row-Level Security (RLS) Policies

### 2.1 Notes RLS (Full CRUD)

```sql
-- Enable RLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owner too (prevents bypassing in Edge Functions
-- unless explicitly using service_role key)
ALTER TABLE public.notes FORCE ROW LEVEL SECURITY;

-- SELECT: users see only their own notes
CREATE POLICY "Users can read own notes"
  ON public.notes FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- INSERT: users can only create notes for themselves
CREATE POLICY "Users can create own notes"
  ON public.notes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: users can only update their own notes
CREATE POLICY "Users can update own notes"
  ON public.notes FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: users can only delete their own notes
CREATE POLICY "Users can delete own notes"
  ON public.notes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
```

**RLS pattern notes:**

- **Separate policies per operation**: More readable and auditable than a single
  `FOR ALL` policy. Easier to modify one operation without risking others.
- **`TO authenticated` role**: Restricts to logged-in users only. Anonymous
  users get zero access.
- **Both USING and WITH CHECK on UPDATE**: `USING` filters which rows can be
  seen for update; `WITH CHECK` ensures the updated row still belongs to the
  user (prevents changing `user_id` to hijack notes).
- **FORCE ROW LEVEL SECURITY**: Prevents accidental bypass if Edge Functions run
  as table owner. The `service_role` key explicitly bypasses RLS when needed
  (e.g., admin operations).

### 2.2 Subscriptions RLS (Read-Only for Client)

```sql
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions FORCE ROW LEVEL SECURITY;

-- SELECT: users can read their own subscription
CREATE POLICY "Users can read own subscription"
  ON public.subscriptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policies for authenticated role.
-- Only the service_role (used by Edge Functions) can write.
-- This ensures subscriptions are ONLY modified by the RevenueCat webhook handler.
```

**Why read-only on client:**

- Subscriptions are the source of truth from RevenueCat. Client-side writes
  would create inconsistency.
- The RevenueCat webhook Edge Function uses the `service_role` key which
  bypasses RLS, allowing it to upsert freely.
- PowerSync syncs the read-only subscription state to the device for offline
  entitlement checks.

---

## 3. PowerSync Compatibility

### 3.1 Postgres Publication

```sql
-- Required for PowerSync to detect changes via logical replication
CREATE PUBLICATION powersync FOR TABLE public.notes, public.subscriptions;
```

### 3.2 PowerSync Schema (Dart Side)

```dart
// lib/core/database/schema.dart
import 'package:powersync/powersync.dart';

const schema = Schema([
  Table('notes', [
    Column.text('user_id'),    // UUID stored as text in SQLite
    Column.text('title'),
    Column.text('body'),
    Column.text('created_at'), // ISO8601 string in SQLite
    Column.text('updated_at'),
  ]),
  Table('subscriptions', [
    Column.text('user_id'),
    Column.text('status'),
    Column.text('product_id'),
    Column.text('original_purchase_date'),
    Column.text('expires_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
]);
```

### 3.3 PowerSync Sync Rules (YAML)

```yaml
# powersync.yaml (PowerSync dashboard or config)
bucket_definitions:
  user_data:
    parameters:
      - SELECT token_parameters.user_id AS user_id
    data:
      - SELECT id, user_id, title, body, created_at, updated_at FROM notes WHERE
        notes.user_id = bucket.user_id
      - SELECT id, user_id, status, product_id, original_purchase_date,
        expires_at, created_at, updated_at FROM subscriptions WHERE
        subscriptions.user_id = bucket.user_id
```

### 3.4 Critical PowerSync Compatibility Rules

1. **UUID primary keys are mandatory**: PowerSync requires `id` column as UUID
   text. The schema uses `id UUID PRIMARY KEY` which maps to `TEXT` in SQLite.

2. **All columns map to TEXT in SQLite**: PowerSync's SQLite schema uses text
   for everything. Dates become ISO8601 strings, UUIDs become text. Parse on the
   Dart side.

3. **No PostgreSQL-specific types in synced columns**: Avoid `JSONB`, arrays, or
   custom types in columns that PowerSync syncs. Use plain `TEXT`,
   `TIMESTAMPTZ`, `UUID`, `BOOLEAN`, `INTEGER`, `REAL`.

4. **`updated_at` is essential for conflict detection**: PowerSync uses
   server-wins by default. The `updated_at` trigger ensures the server timestamp
   is always current for conflict resolution.

5. **Publication must include all synced tables**: If you add a new table that
   needs offline sync, add it to the `powersync` publication:

   ```sql
   ALTER PUBLICATION powersync ADD TABLE public.new_table;
   ```

6. **Client-generated UUIDs**: During offline creates, the Flutter app generates
   the UUID via `const Uuid().v4()`. The server default `gen_random_uuid()` is
   only used for server-side inserts (e.g., seed data).

---

## 4. Indexing Strategy Summary

| Table           | Index                                  | Purpose                                  | Type   |
| --------------- | -------------------------------------- | ---------------------------------------- | ------ |
| `notes`         | PK on `id`                             | Primary key (auto B-tree)                | B-tree |
| `notes`         | `(user_id)`                            | FK lookups, RLS filtering, CASCADE perf  | B-tree |
| `notes`         | `(created_at)`                         | Sort by date                             | B-tree |
| `notes`         | `(user_id, created_at DESC)`           | "My notes, newest first" composite query | B-tree |
| `subscriptions` | PK on `id`                             | Primary key (auto B-tree)                | B-tree |
| `subscriptions` | UNIQUE on `(user_id)`                  | One subscription per user + FK lookups   | B-tree |
| `subscriptions` | `(expires_at) WHERE status = 'active'` | Expiring subscriptions (partial)         | B-tree |
| `subscriptions` | `(product_id)`                         | Webhook lookups by product               | B-tree |

**Indexing principles applied (from skill):**

- Index every FK column (PostgreSQL does not auto-index them)
- Create indexes for access paths you actually query
- Use partial indexes for hot subsets (`WHERE status = 'active'`)
- Composite index column order: most selective / most frequently filtered first
- The `notes` table has 4 indexes which is reasonable for a read-heavy,
  moderate-write CRUD table

---

## 5. Migration Best Practices

### 5.1 Migration File Naming

```
supabase/migrations/
  00000000000000_create_notes.sql
  00000000000001_create_subscriptions.sql
  00000000000002_create_powersync_publication.sql
```

Use the Supabase CLI timestamp convention. Each migration is idempotent and
forward-only (no down migrations in Supabase).

### 5.2 Migration Structure Template

```sql
-- Migration: 00000000000000_create_notes.sql
-- Purpose: Create notes table with RLS for offline-first CRUD via PowerSync
-- Dependencies: auth.users (Supabase built-in)

BEGIN;

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.notes ( ... );

-- 2. Create indexes
CREATE INDEX IF NOT EXISTS ...;

-- 3. Create triggers
CREATE TRIGGER IF NOT EXISTS ...;

-- 4. Enable RLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes FORCE ROW LEVEL SECURITY;

-- 5. Create policies
CREATE POLICY ... ;

-- 6. Grant permissions (Supabase convention)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notes TO authenticated;
GRANT SELECT ON public.notes TO anon;

COMMIT;
```

**Key practices (from skill):**

- **Transactional DDL**: Wrap in `BEGIN/COMMIT` -- PostgreSQL supports
  transactional DDL, so failures roll back cleanly.
- **`IF NOT EXISTS` guards**: Prevents errors on re-run during development.
- **Explicit GRANT statements**: Supabase uses PostgreSQL roles. The
  `authenticated` role needs explicit grants alongside RLS policies.
- **Comments in migrations**: State purpose and dependencies at the top.

### 5.3 Seed Data

```sql
-- supabase/seed.sql
-- Development seed data - runs on `supabase db reset`

-- Insert test notes for the default test user
-- (Supabase local dev creates a test user via dashboard)
INSERT INTO public.notes (id, user_id, title, body, created_at, updated_at)
VALUES
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
   '00000000-0000-0000-0000-000000000000', -- replace with test user UUID
   'Welcome to Notes',
   'This is your first note. Edit or delete it to get started.',
   now(), now()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
   '00000000-0000-0000-0000-000000000000',
   'Offline Support',
   'This app works offline. Changes sync automatically when you reconnect.',
   now(), now());
```

### 5.4 Safe Schema Evolution Rules

For future migrations after initial release:

1. **Adding columns**: Use `ALTER TABLE ADD COLUMN ... DEFAULT ...` with a
   non-volatile default (fast, no table rewrite).
2. **Adding NOT NULL columns**: Add as nullable first, backfill, then add
   `NOT NULL` constraint. Volatile defaults (like `gen_random_uuid()`) cause
   full table rewrites.
3. **Adding indexes**: Use `CREATE INDEX CONCURRENTLY` to avoid blocking writes
   (cannot run inside a transaction).
4. **Changing PowerSync-synced columns**: Update both the Postgres schema AND
   the Dart `Schema` definition. PowerSync requires schema alignment.
5. **Adding new synced tables**: Add the migration, then
   `ALTER PUBLICATION powersync ADD TABLE ...`, then update Dart schema and sync
   rules.

---

## 6. Edge Function Database Access Pattern

### RevenueCat Webhook (Subscriptions Upsert)

```sql
-- Used by supabase/functions/revenuecat-webhook/index.ts
-- Runs with service_role key (bypasses RLS)

INSERT INTO public.subscriptions (id, user_id, status, product_id, original_purchase_date, expires_at)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (user_id)
DO UPDATE SET
  status = EXCLUDED.status,
  product_id = EXCLUDED.product_id,
  expires_at = EXCLUDED.expires_at,
  updated_at = now()
WHERE subscriptions.status IS DISTINCT FROM EXCLUDED.status
   OR subscriptions.product_id IS DISTINCT FROM EXCLUDED.product_id
   OR subscriptions.expires_at IS DISTINCT FROM EXCLUDED.expires_at;
```

**Upsert design (from skill):**

- **`ON CONFLICT (user_id)`**: Requires the UNIQUE index on `user_id`.
- **`EXCLUDED.column`** references would-be-inserted values.
- **`IS DISTINCT FROM` guard**: Only updates columns that actually changed,
  reducing write overhead and avoiding unnecessary `updated_at` bumps.
- **`DO UPDATE` over `DO NOTHING`**: We need to update status on renewals,
  cancellations, and expirations.

---

## 7. Plan Corrections

The current plan (Phase 3) specifies the schema inline. These recommendations
refine it:

| Plan Says                              | Recommendation                                           | Reason                                            |
| -------------------------------------- | -------------------------------------------------------- | ------------------------------------------------- |
| `id uuid PK default gen_random_uuid()` | Keep as-is                                               | Correct for PowerSync (client-generated UUIDs)    |
| `user_id uuid references auth.users`   | Add `NOT NULL` and `ON DELETE CASCADE`                   | Skill: NOT NULL everywhere semantically required  |
| `title text not null`                  | Add `CHECK (length(title) <= 500)`                       | Defensive constraint                              |
| `body text`                            | Keep nullable (optional field)                           | Correct                                           |
| `created_at timestamptz default now()` | Add `NOT NULL`                                           | Skill: NOT NULL + DEFAULT for timestamps          |
| `updated_at timestamptz default now()` | Add `NOT NULL` + auto-update trigger                     | Ensures PowerSync conflict detection works        |
| No FK index mentioned                  | Add `CREATE INDEX ON notes (user_id)`                    | Skill gotcha: PG does NOT auto-index FKs          |
| No publication details                 | Add `CREATE PUBLICATION powersync` as separate migration | Clean separation of concerns                      |
| Subscriptions: `status text`           | Add `CHECK` constraint with valid values                 | Prevents invalid webhook data                     |
| Subscriptions: no unique constraint    | Add `UNIQUE (user_id)`                                   | Business rule: one subscription per user          |
| No `GRANT` statements                  | Add explicit grants to `authenticated` role              | Required for Supabase RLS to work with client SDK |
| No `FORCE ROW LEVEL SECURITY`          | Add to both tables                                       | Prevents accidental RLS bypass                    |
