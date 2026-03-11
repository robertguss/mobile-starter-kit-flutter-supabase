import { assertEquals, assertMatch, assertObjectMatch } from "@std/assert";

import {
  buildRevenueCatWebhookHandler,
  type RevenueCatWebhookStore,
  type SubscriptionRecord,
  type WebhookAuditRecord,
} from "./handler.ts";
import type { RevenueCatWebhookPayload } from "../_shared/types.ts";

Deno.test("returns 401 when authorization does not match", async () => {
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store: createStore(),
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      headers: {
        authorization: "Bearer wrong",
      },
      body: JSON.stringify(validPayload()),
    }),
  );

  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "Unauthorized" });
});

Deno.test("returns 400 for invalid payloads", async () => {
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store: createStore(),
  });

  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      headers: {
        authorization: "Bearer secret",
        "content-type": "application/json",
      },
      body: JSON.stringify({ api_version: "1.0", event: {} }),
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(await response.json(), { error: "Invalid webhook payload." });
});

Deno.test("returns 400 for anonymous revenuecat users", async () => {
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store: createStore(),
  });

  const response = await handler(
    requestWithPayload(
      validPayload({
        event: {
          app_user_id: "$RCAnonymousID:123",
        },
      }),
    ),
  );

  assertEquals(response.status, 400);
  assertEquals(await response.json(), { error: "Invalid app user id." });
});

Deno.test("processes purchase events and marks them processed", async () => {
  const store = createStore();
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store,
    now: () => new Date("2026-03-11T12:00:00.000Z"),
  });

  const response = await handler(requestWithPayload(validPayload()));

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    ok: true,
    eventId: "event-1",
  });
  assertEquals(store.subscriptions.length, 1);
  assertObjectMatch(store.subscriptions[0], {
    userId: "a87f7394-58d5-4d5d-a4e2-ec292743ff6d",
    status: "trial",
    productId: "pro_monthly",
  });
  assertObjectMatch(
    store.auditRecords.get("event-1")!,
    {
      status: "processed",
      processedAt: "2026-03-11T12:00:00.000Z",
      lastError: null,
    },
  );
});

Deno.test("skips already processed duplicate events", async () => {
  const store = createStore();
  store.auditRecords.set("event-1", {
    eventId: "event-1",
    eventType: "INITIAL_PURCHASE",
    appUserId: "a87f7394-58d5-4d5d-a4e2-ec292743ff6d",
    payload: validPayload(),
    status: "processed",
    receivedAt: "2026-03-11T12:00:00.000Z",
    processedAt: "2026-03-11T12:00:00.000Z",
    lastError: null,
  });
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store,
  });

  const response = await handler(requestWithPayload(validPayload()));

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    duplicate: true,
    eventId: "event-1",
  });
  assertEquals(store.subscriptions.length, 0);
});

Deno.test("marks audit rows as failed and returns generic 500 on errors", async () => {
  const store = createStore({ failUpsert: true });
  const handler = buildRevenueCatWebhookHandler({
    authKey: "Bearer secret",
    store,
  });

  const response = await handler(requestWithPayload(validPayload()));

  assertEquals(response.status, 500);
  assertEquals(await response.json(), {
    error: "Webhook processing failed.",
  });
  assertMatch(store.auditRecords.get("event-1")!.status, /failed/);
});

function requestWithPayload(payload: unknown): Request {
  return new Request("https://example.com", {
    method: "POST",
    headers: {
      authorization: "Bearer secret",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

function validPayload(
  overrides: {
    api_version?: string;
    event?: Record<string, unknown>;
  } = {},
): RevenueCatWebhookPayload {
  return {
    api_version: overrides.api_version ?? "1.0",
    event: {
      id: "event-1" as const,
      type: "INITIAL_PURCHASE" as const,
      app_user_id: "a87f7394-58d5-4d5d-a4e2-ec292743ff6d",
      original_app_user_id: "a87f7394-58d5-4d5d-a4e2-ec292743ff6d",
      product_id: "pro_monthly",
      event_timestamp_ms: 1_741_692_800_000,
      expiration_at_ms: 1_744_371_200_000,
      environment: "PRODUCTION" as const,
      period_type: "TRIAL" as const,
      ...(overrides.event ?? {}),
    },
  };
}

function createStore(
  options: {
    failUpsert?: boolean;
  } = {},
): RevenueCatWebhookStore & {
  auditRecords: Map<string, WebhookAuditRecord>;
  subscriptions: SubscriptionRecord[];
} {
  const auditRecords = new Map<string, WebhookAuditRecord>();
  const subscriptions: SubscriptionRecord[] = [];

  return {
    auditRecords,
    subscriptions,
    async getAuditRecord(eventId) {
      return auditRecords.get(eventId) ?? null;
    },
    async insertAuditRecord(record) {
      auditRecords.set(record.eventId, record);
    },
    async markAuditRecord(eventId, patch) {
      const existing = auditRecords.get(eventId);
      if (existing == null) {
        throw new Error("Missing audit record");
      }

      auditRecords.set(eventId, {
        ...existing,
        status: patch.status,
        processedAt: patch.processedAt ?? existing.processedAt,
        lastError: patch.lastError ?? existing.lastError,
      });
    },
    async upsertSubscription(record) {
      if (options.failUpsert) {
        throw new Error("boom");
      }

      subscriptions.push(record);
    },
  };
}
