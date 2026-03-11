# Data Integrity Review: Flutter + Supabase Starter Kit Plan

**Reviewed:** 2026-03-10 **Scope:** Database migrations, RLS policies, PowerSync
schema, sync rules, data clearing, seed data, UUID strategy, timestamp handling
**Verdict:** Solid foundation with 14 concrete issues to address before
implementation.

---

## Critical Issues (Must Fix)

### 1. Notes migration missing `updated_at` trigger

The plan specifies `updated_at timestamptz default now()` but never creates a
trigger to auto-update it on row modification. Without this, `updated_at` will
permanently equal `created_at` in Postgres, creating a false data trail and
breaking any "last modified" sorting logic.

```sql
-- Add to 00000000000000_create_notes.sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

Make this function reusable across tables (subscriptions will need it too if
status changes).

### 2. Subscriptions table missing NOT NULL constraints and UNIQUE on user_id

The plan defines `status text` and `product_id text` with no NOT NULL
constraints. A subscription row with NULL status is semantically meaningless and
will cause silent failures in paywall logic. Additionally, there is no UNIQUE
constraint on `user_id`, meaning the RevenueCat webhook upsert (`ON CONFLICT`)
has no target column to conflict on.

```sql
CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'inactive',
  product_id text NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)  -- Required for upsert behavior
);
```

### 3. No ON DELETE CASCADE on foreign keys

The plan specifies `user_id uuid references auth.users` but does not define
cascade behavior. If a Supabase user is deleted (GDPR right-to-deletion, account
cleanup), their notes and subscriptions become orphaned rows with a dangling
foreign key. The insert will not fail, but the data becomes unreachable garbage
that violates referential integrity.

Both tables must use `ON DELETE CASCADE`:

```sql
user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE
```

This is also a GDPR compliance requirement -- when a user is deleted, all their
PII must go with them.

### 4. PowerSync SQLite schema type mismatch risk

The plan says to define a PowerSync `Schema` in Dart matching the Postgres
tables, but the STACK_BEST_PRACTICES example shows only `Column.text()` and
`Column.integer()` types. PostgreSQL `timestamptz` columns will arrive in SQLite
as TEXT strings via PowerSync. The plan does not address:

- How timestamps will be parsed in Dart (ISO 8601 string from SQLite vs DateTime
  from Postgres)
- That `uuid` columns in SQLite are plain TEXT (no UUID validation)
- That boolean-like values (if any are added later) must be stored as INTEGER in
  SQLite

**Recommendation:** Document the type mapping explicitly in the PowerSync schema
definition file. Add a parsing utility in `note_model.dart` that handles ISO
8601 string-to-DateTime conversion defensively:

```dart
DateTime parseTimestamp(dynamic value) {
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  throw FormatException('Unexpected timestamp format: $value');
}
```

### 5. No conflict resolution strategy defined

The plan mentions "server-wins resolution" in integration test scenario 5 but
never specifies how this is implemented. PowerSync's `uploadData()` connector
sends local CRUD operations to Supabase. If two devices edit the same note
offline, the last one to sync overwrites the other with no merge. This is
acceptable as a strategy, but it must be explicitly handled:

- The `uploadData()` implementation should use `upsert` (not `insert`/`update`)
  for write operations
- Consider adding an `updated_at` comparison in the upsert to implement true
  last-write-wins based on timestamp rather than sync order
- Document this behavior for users of the starter kit so they understand the
  tradeoff

---

## High Priority Issues

### 6. RLS policies are underspecified

The plan says "Enable RLS, users can only CRUD their own notes
(`auth.uid() = user_id`)" but does not define individual policies per operation.
A single permissive policy is insufficient. You need separate policies:

```sql
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own notes"
  ON notes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes"
  ON notes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes"
  ON notes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notes"
  ON notes FOR DELETE
  USING (auth.uid() = user_id);
```

The INSERT policy WITH CHECK is critical -- without it, a malicious client could
insert notes with another user's `user_id`.

### 7. Subscriptions RLS is read-only but webhook needs write access

The plan says "Users can only read their own subscription" for RLS. But the
RevenueCat webhook Edge Function uses `SUPABASE_SERVICE_ROLE_KEY`, which
bypasses RLS entirely. This is correct for the webhook, but the plan should
explicitly state that no client-side INSERT/UPDATE/DELETE policies exist for
subscriptions, and document WHY (server-only writes via webhook). This prevents
a future developer from accidentally adding client-write policies.

```sql
-- Subscriptions: read-only for authenticated users, writes only via service_role
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own subscription"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policies: writes happen server-side via Edge Function
-- using service_role key which bypasses RLS
```

### 8. Publication must be created INSIDE a migration, not separately

The plan lists `CREATE PUBLICATION powersync FOR TABLE notes, subscriptions;` as
a task but does not place it in a migration file. If this is run manually in the
SQL editor, it will not be reproducible across environments (local, staging,
production). It must be in its own migration file or appended to the
subscriptions migration:

```sql
-- supabase/migrations/00000000000002_create_powersync_publication.sql
CREATE PUBLICATION IF NOT EXISTS powersync FOR TABLE notes, subscriptions;
```

Use `IF NOT EXISTS` for idempotency.

### 9. Sync rules must mirror RLS exactly

The plan references PowerSync Sync Streams edition 3 but does not show the
actual sync rules YAML. The sync rules MUST filter by `user_id` matching
`request.user_id()`, exactly mirroring the RLS policies. If sync rules are more
permissive than RLS, PowerSync will attempt to sync data that Supabase rejects,
causing silent sync failures. If sync rules are more restrictive, users will not
see data they should have access to.

```yaml
# powersync/sync_rules.yaml
bucket_definitions:
  user_notes:
    parameters:
      - SELECT request.user_id() AS user_id
    data:
      - SELECT * FROM notes WHERE user_id = bucket.user_id

  user_subscription:
    parameters:
      - SELECT request.user_id() AS user_id
    data:
      - SELECT * FROM subscriptions WHERE user_id = bucket.user_id
```

---

## Medium Priority Issues

### 10. Sign-out data clearing has a race condition window

The plan specifies: `PowerSync.disconnectAndClear()` then
`Supabase.auth.signOut()`. But the system interaction graph shows:
"PowerSync.disconnectAndClear() -> Purchases.logOut() -> OneSignal.logout() ->
Supabase.auth.signOut()". If PowerSync disconnect fails (throws), the remaining
sign-out steps never execute, leaving the user in a partial sign-out state where
auth tokens are still valid but local data is in an inconsistent state.

**Recommendation:** Wrap sign-out in a sequence that continues on individual
failures:

```dart
Future<void> signOut() async {
  // Clear local data first (privacy)
  try { await powerSync.disconnectAndClear(); } catch (e) { log(e); }
  try { await Purchases.logOut(); } catch (e) { log(e); }
  try { OneSignal.logout(); } catch (e) { log(e); }
  // Auth sign-out must happen last and must succeed
  await Supabase.instance.client.auth.signOut();
}
```

### 11. Seed data must respect RLS and use a real user ID

The plan mentions `supabase/seed.sql` for development data. Seed data for the
`notes` table requires a valid `user_id` that references `auth.users`. If
seed.sql tries to INSERT notes with a hardcoded UUID that does not exist in
`auth.users`, the foreign key constraint will reject it.

**Options:**

- Seed script should first create a test user in `auth.users` using Supabase's
  `auth.create_user()` function (requires service_role context)
- Or, seed data should be inserted after first login using a seeding Edge
  Function
- Or, document that `supabase db reset` + seed requires manual user creation
  first

### 12. UUID generation strategy inconsistency

The notes table uses `DEFAULT gen_random_uuid()` (server-generated), but
PowerSync operates offline-first. When a note is created offline, the client
must generate the UUID locally before the row ever reaches Postgres. If the
client also relies on the server default, there is a conflict about who owns
UUID generation.

**Recommendation:** Always generate UUIDs client-side using the `uuid` Dart
package. The server `DEFAULT gen_random_uuid()` serves as a fallback for direct
SQL inserts (like seed data or webhooks) but should never be the primary
strategy for synced tables. Document this explicitly.

### 13. Missing index on user_id columns

Neither migration mentions creating an index on `user_id`. Every RLS policy
evaluation, every sync rule query, and every "get my notes" query filters on
`user_id`. Without an index, these become full table scans as data grows.

```sql
CREATE INDEX idx_notes_user_id ON notes (user_id);
CREATE INDEX idx_subscriptions_user_id ON subscriptions (user_id);
```

### 14. Notes table `body` column allows NULL but `title` is NOT NULL

This is intentional per the plan (`body text` vs `title text not null`), which
is fine. However, the PowerSync schema and the `note_model.dart` must both
handle `body` being null. Ensure the Dart model uses `String?` for body, and
that the UI gracefully renders notes with no body content. This is not a bug,
but a data contract that must be consistently enforced across all three layers
(Postgres, PowerSync schema, Dart model).

---

## Additional Recommendations

### Timestamp consistency across layers

- Postgres uses `timestamptz` (timezone-aware, stored as UTC)
- PowerSync SQLite stores these as ISO 8601 TEXT strings
- Dart should parse all timestamps as UTC and convert to local only at the
  presentation layer
- Consider adding a `CHECK` constraint or application-level validation that
  `created_at <= updated_at`

### Migration idempotency

Both migrations should use `CREATE TABLE IF NOT EXISTS` for safety during
development resets. While Supabase migrations track applied state, defensive SQL
prevents errors during manual debugging.

### RevenueCat webhook data validation

The webhook Edge Function should validate that `app_user_id` is a valid UUID
format before upserting. The plan mentions checking for `$RCAnonymousID` prefix,
which is good, but also validate UUID format to prevent injection:

```typescript
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!UUID_REGEX.test(appUserId)) {
  return new Response("Invalid user ID format", { status: 400 });
}
```

---

## Summary

| Priority | Count | Categories                                                                                     |
| -------- | ----- | ---------------------------------------------------------------------------------------------- |
| Critical | 5     | Missing trigger, missing constraints, no cascade, type mismatches, no conflict resolution      |
| High     | 4     | Underspecified RLS, webhook vs RLS gap, publication not in migration, sync rule parity         |
| Medium   | 5     | Sign-out race condition, seed data FK, UUID ownership, missing indexes, nullable body contract |

The plan's architecture is sound -- feature-first layout, repository pattern,
offline-first with PowerSync, proper RLS intent. The issues above are
implementation details that, if missed, would cause silent data corruption,
orphaned rows, or sync failures in production. Addressing them during migration
authoring (Phase 3) will prevent every one of them.
