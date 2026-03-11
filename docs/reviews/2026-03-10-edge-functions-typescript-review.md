# Edge Functions TypeScript Review -- Kieran

**Date:** 2026-03-10 **Reviewer:** Kieran (super senior TypeScript) **Scope:**
Plan review for `supabase/functions/revenuecat-webhook/index.ts` and
`supabase/functions/onesignal-trigger/index.ts` **Status:** Pre-implementation
-- no code exists yet. These are recommendations for when you build Phase 6.

---

## 1. CRITICAL: Webhook Signature Verification

The plan says "Verify webhook signature" but gives no detail. This is the most
security-sensitive code in the entire starter kit. RevenueCat uses HMAC-SHA256
with a shared secret.

**Recommendation -- use Deno's native `crypto.subtle`, not a third-party HMAC
library:**

```ts
async function verifyRevenueCatSignature(
  body: string,
  signatureHeader: string,
  secret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expectedHex = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Constant-time comparison to prevent timing attacks
  if (expectedHex.length !== signatureHeader.length) return false;
  let mismatch = 0;
  for (let i = 0; i < expectedHex.length; i++) {
    mismatch |= expectedHex.charCodeAt(i) ^ signatureHeader.charCodeAt(i);
  }
  return mismatch === 0;
}
```

**Why this matters:**

- `crypto.subtle` is built into Deno -- zero dependencies.
- Constant-time comparison prevents timing attacks. Never use `===` for
  signature comparison.
- RevenueCat sends the signature in the `X-RevenueCat-Signature` header (verify
  current docs at implementation time).

---

## 2. CRITICAL: Type Safety for Webhook Payloads

The plan mentions parsing events (INITIAL_PURCHASE, RENEWAL, CANCELLATION,
EXPIRATION) but does not specify types. Without explicit types, you will end up
with `any` everywhere, which I will reject.

**Recommendation -- define a discriminated union for RevenueCat events:**

```ts
// types.ts (shared across the function)

type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "CANCELLATION"
  | "EXPIRATION"
  | "BILLING_ISSUE"
  | "PRODUCT_CHANGE";

interface RevenueCatBaseEvent {
  readonly id: string;
  readonly event_timestamp_ms: number;
  readonly app_user_id: string;
  readonly original_app_user_id: string;
  readonly product_id: string;
}

interface RevenueCatSubscriptionEvent extends RevenueCatBaseEvent {
  readonly type: RevenueCatEventType;
  readonly expiration_at_ms: number | null;
  readonly environment: "SANDBOX" | "PRODUCTION";
}

interface RevenueCatWebhookPayload {
  readonly api_version: string;
  readonly event: RevenueCatSubscriptionEvent;
}
```

**Why this matters:**

- Discriminated union on `type` lets TypeScript narrow correctly in switch
  statements.
- `readonly` prevents accidental mutation of incoming data.
- Explicit nullability on `expiration_at_ms` forces you to handle the null case.

---

## 3. CRITICAL: Input Validation -- the `$RCAnonymousID` Problem

The plan correctly identifies this risk: "Validate that `app_user_id` is a valid
Supabase UUID (not `$RCAnonymousID`)". This needs a concrete implementation
pattern.

**Recommendation -- validate early, fail loudly:**

```ts
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseAndValidateEvent(
  raw: unknown,
):
  | { ok: true; event: RevenueCatSubscriptionEvent }
  | { ok: false; reason: string } {
  // Step 1: Structural validation
  if (raw === null || typeof raw !== "object" || !("event" in raw)) {
    return { ok: false, reason: "Missing event field in payload" };
  }

  const payload = raw as RevenueCatWebhookPayload;
  const { event } = payload;

  // Step 2: Reject anonymous IDs -- these cannot map to a Supabase user
  if (!event.app_user_id || event.app_user_id.startsWith("$RCAnonymousID")) {
    return {
      ok: false,
      reason: `Anonymous RevenueCat ID received: ${event.app_user_id}`,
    };
  }

  // Step 3: Validate UUID format
  if (!UUID_REGEX.test(event.app_user_id)) {
    return {
      ok: false,
      reason: `app_user_id is not a valid UUID: ${event.app_user_id}`,
    };
  }

  // Step 4: Validate event type is one we handle
  const HANDLED_TYPES: ReadonlySet<string> = new Set([
    "INITIAL_PURCHASE",
    "RENEWAL",
    "CANCELLATION",
    "EXPIRATION",
  ]);
  if (!HANDLED_TYPES.has(event.type)) {
    return { ok: false, reason: `Unhandled event type: ${event.type}` };
  }

  return { ok: true, event };
}
```

**Why a Result type instead of throwing:**

- Edge Functions should return proper HTTP status codes, not crash on bad input.
- A Result type (`{ ok, event } | { ok, reason }`) makes the caller explicitly
  handle both paths.
- Throwing inside a Deno `serve` handler can produce opaque 500 errors with no
  useful logging.

---

## 4. Supabase Client Usage from Edge Functions

**Recommendation -- use the service role key, not the anon key:**

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Service role bypasses RLS -- required for webhook-initiated writes
// where there is no authenticated user session.
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
```

**Why:**

- Webhooks have no user session. The anon key with RLS will block every write.
- The service role key is already available as an environment variable in
  Supabase Edge Functions.
- Create the client at module scope (outside the handler) so it is reused across
  invocations.

**Guard the non-null assertions:** Those `!` operators on `Deno.env.get` are
acceptable here because Supabase injects these variables automatically. Add a
startup guard if you want belt-and-suspenders:

```ts
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !key) {
  throw new Error("Missing required Supabase environment variables");
}
const supabase = createClient(url, key);
```

---

## 5. Deno-Specific Patterns

### 5a. Use `Deno.serve`, not the deprecated `serve` from std/http

```ts
// CORRECT for Supabase Edge Functions (Deno 1.38+)
Deno.serve(async (req: Request): Promise<Response> => {
  // ...
});
```

Do NOT import `serve` from `https://deno.land/std/http/server.ts` -- that
pattern is deprecated and Supabase's runtime expects `Deno.serve`.

### 5b. Import Maps

Supabase Edge Functions support import maps via
`supabase/functions/import_map.json`. Use it to pin `@supabase/supabase-js`
version:

```json
{
  "imports": {
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2.49.0"
  }
}
```

Then import cleanly:

```ts
import { createClient } from "@supabase/supabase-js";
```

### 5c. No `node:` Built-ins Without Explicit Compat

Deno supports `node:crypto`, `node:buffer`, etc., but prefer Deno/Web APIs
(`crypto.subtle`, `TextEncoder`, `Response`, `Request`) for Edge Functions. They
are lighter and guaranteed available.

---

## 6. Error Handling -- Full Handler Structure

Here is the recommended structure for the RevenueCat webhook handler. Note the
deliberate separation of concerns:

```ts
import { createClient } from "@supabase/supabase-js";

// --- Types (extract to types.ts if shared) ---
// [See Section 2 above]

// --- Validation (extract to validation.ts) ---
// [See Section 3 above]

// --- Signature Verification (extract to verify.ts) ---
// [See Section 1 above]

// --- Database Operations ---
async function upsertSubscription(
  supabase: ReturnType<typeof createClient>,
  event: RevenueCatSubscriptionEvent,
): Promise<void> {
  const statusMap: Record<string, string> = {
    INITIAL_PURCHASE: "active",
    RENEWAL: "active",
    CANCELLATION: "canceled",
    EXPIRATION: "expired",
  };

  const { error } = await supabase.from("subscriptions").upsert(
    {
      user_id: event.app_user_id,
      status: statusMap[event.type] ?? "unknown",
      product_id: event.product_id,
      expires_at: event.expiration_at_ms
        ? new Date(event.expiration_at_ms).toISOString()
        : null,
    },
    { onConflict: "user_id" },
  );

  if (error) {
    throw new Error(`Supabase upsert failed: ${error.message}`);
  }
}

// --- Handler ---
const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
if (!webhookSecret) {
  throw new Error("REVENUECAT_WEBHOOK_SECRET not configured");
}

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !supabaseKey) {
  throw new Error("Missing Supabase environment variables");
}
const supabase = createClient(supabaseUrl, supabaseKey);

Deno.serve(async (req: Request): Promise<Response> => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();

  // Verify signature
  const signature = req.headers.get("x-revenuecat-signature");
  if (!signature) {
    return new Response("Missing signature", { status: 401 });
  }

  const isValid = await verifyRevenueCatSignature(
    body,
    signature,
    webhookSecret,
  );
  if (!isValid) {
    return new Response("Invalid signature", { status: 401 });
  }

  // Parse and validate
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const result = parseAndValidateEvent(parsed);
  if (!result.ok) {
    // Log but return 200 -- RevenueCat will retry on non-2xx
    // and we do not want retries for structurally invalid events
    console.warn(`Skipping event: ${result.reason}`);
    return new Response(
      JSON.stringify({ skipped: true, reason: result.reason }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  // Process
  try {
    await upsertSubscription(supabase, result.event);
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Failed to process webhook:", err);
    // Return 500 so RevenueCat retries
    return new Response("Internal error", { status: 500 });
  }
});
```

---

## 7. OneSignal Trigger Function -- Recommendations

The plan is light on this function. Key points:

1. **Authenticate the caller.** This function should not be publicly callable.
   Use the Supabase auth JWT from the calling client:

```ts
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
  return new Response("Unauthorized", { status: 401 });
}

const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  global: { headers: { Authorization: authHeader } },
});

const {
  data: { user },
  error,
} = await supabaseClient.auth.getUser();
if (error || !user) {
  return new Response("Unauthorized", { status: 401 });
}
```

2. **Type the request body:**

```ts
interface SendNotificationRequest {
  readonly targetUserIds: readonly string[];
  readonly title: string;
  readonly message: string;
  readonly data?: Record<string, string>;
}
```

3. **Use the OneSignal REST API with the server API key** (stored in Deno.env,
   never exposed to client).

4. **Rate limit or scope.** Consider whether this function should only be
   callable by authenticated admins or by server-side triggers (e.g., a Postgres
   trigger via `pg_net`).

---

## 8. Shared Patterns -- Extract a `_shared/` Directory

Supabase Edge Functions support a `_shared/` directory for code shared across
functions.

```
supabase/functions/
  _shared/
    supabase-client.ts    # Shared client initialization
    types.ts              # Shared types
    responses.ts          # Helper: jsonResponse, errorResponse
  revenuecat-webhook/
    index.ts
  onesignal-trigger/
    index.ts
```

Example `responses.ts`:

```ts
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
```

---

## 9. Testing Edge Functions

The plan has no mention of testing Edge Functions. This is a gap.

**Recommendation:** Use Deno's built-in test runner. Structure each function so
the handler logic is importable and testable independently of `Deno.serve`:

```ts
// revenuecat-webhook/handler.ts -- pure logic, testable
export async function handleWebhook(
  req: Request,
  deps: { supabase: SupabaseClient; webhookSecret: string },
): Promise<Response> {
  // all logic here
}

// revenuecat-webhook/index.ts -- thin entry point
import { handleWebhook } from "./handler.ts";

Deno.serve((req) => handleWebhook(req, { supabase, webhookSecret }));
```

Then in tests:

```ts
// revenuecat-webhook/handler_test.ts
import { assertEquals } from "https://deno.land/std/assert/mod.ts";
import { handleWebhook } from "./handler.ts";

Deno.test("rejects GET requests", async () => {
  const req = new Request("http://localhost", { method: "GET" });
  const res = await handleWebhook(req, {
    supabase: mockClient,
    webhookSecret: "test",
  });
  assertEquals(res.status, 405);
});

Deno.test("rejects invalid signature", async () => {
  const req = new Request("http://localhost", {
    method: "POST",
    body: "{}",
    headers: { "x-revenuecat-signature": "invalid" },
  });
  const res = await handleWebhook(req, {
    supabase: mockClient,
    webhookSecret: "test",
  });
  assertEquals(res.status, 401);
});
```

---

## Summary of Findings

| #   | Severity | Finding                                                                                                       |
| --- | -------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | CRITICAL | Plan lacks signature verification detail -- use `crypto.subtle` HMAC-SHA256 with constant-time comparison     |
| 2   | CRITICAL | No types defined for webhook payloads -- use discriminated unions with `readonly`                             |
| 3   | CRITICAL | `$RCAnonymousID` validation is mentioned but has no implementation pattern -- use Result type with UUID regex |
| 4   | HIGH     | Must use service role key for webhook function (no user session available)                                    |
| 5   | HIGH     | Use `Deno.serve` (not deprecated `serve` import), prefer Web APIs over Node compat                            |
| 6   | HIGH     | Separate handler logic from `Deno.serve` entry point for testability                                          |
| 7   | MEDIUM   | OneSignal trigger needs caller authentication -- pass through JWT and validate                                |
| 8   | MEDIUM   | Extract shared code to `_shared/` directory                                                                   |
| 9   | MEDIUM   | Plan has no Edge Function tests -- add Deno test runner tests                                                 |
| 10  | LOW      | Use import maps to pin dependency versions                                                                    |

**Bottom line:** The plan identifies the right concerns (signature verification,
anonymous ID rejection) but lacks implementation specificity. The patterns above
give you a type-safe, testable, Deno-idiomatic foundation. The biggest gap is
the complete absence of Edge Function tests from the plan -- add them.
