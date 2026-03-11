import { errorResponse, successResponse } from "../_shared/responses.ts";
import { getServiceRoleClient } from "../_shared/supabase-client.ts";
import {
  HANDLED_REVENUECAT_EVENT_TYPES,
  type RevenueCatSubscriptionEvent,
  type RevenueCatWebhookPayload,
} from "../_shared/types.ts";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type WebhookProcessingStatus = "processing" | "processed" | "failed";

export interface WebhookAuditRecord {
  eventId: string;
  eventType: RevenueCatSubscriptionEvent["type"];
  appUserId: string;
  payload: RevenueCatWebhookPayload;
  status: WebhookProcessingStatus;
  receivedAt: string;
  processedAt: string | null;
  lastError: string | null;
}

export interface SubscriptionRecord {
  userId: string;
  status: "active" | "trial" | "cancelled" | "expired";
  productId: string;
  expiresAt: string | null;
}

export interface RevenueCatWebhookStore {
  getAuditRecord(eventId: string): Promise<WebhookAuditRecord | null>;
  insertAuditRecord(record: WebhookAuditRecord): Promise<void>;
  markAuditRecord(
    eventId: string,
    patch: {
      status: WebhookProcessingStatus;
      processedAt?: string | null;
      lastError?: string | null;
    },
  ): Promise<void>;
  upsertSubscription(record: SubscriptionRecord): Promise<void>;
}

export interface RevenueCatWebhookDeps {
  authKey?: string;
  now?: () => Date;
  store?: RevenueCatWebhookStore;
}

export function buildRevenueCatWebhookHandler(
  deps: RevenueCatWebhookDeps = {},
) {
  const authKey = deps.authKey ?? Deno.env.get("REVENUECAT_WEBHOOK_AUTH_KEY") ??
    "";
  const now = deps.now ?? (() => new Date());
  const store = deps.store ?? createSupabaseRevenueCatWebhookStore();

  return async function handleRevenueCatWebhook(
    request: Request,
  ): Promise<Response> {
    if (!authKey) {
      return errorResponse(500, "Webhook is not configured.");
    }

    const authorization = request.headers.get("authorization");
    if (!isAuthorized(authorization, authKey)) {
      return errorResponse(401, "Unauthorized");
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      return errorResponse(400, "Invalid webhook payload.");
    }

    const parsedEvent = parseRevenueCatEvent(payload);
    if (!parsedEvent.ok) {
      return errorResponse(400, parsedEvent.reason);
    }

    const event = parsedEvent.event;
    const existingAuditRecord = await store.getAuditRecord(event.id);
    if (existingAuditRecord?.status == "processed") {
      return successResponse({
        duplicate: true,
        eventId: event.id,
      });
    }

    const timestamp = now().toISOString();
    if (existingAuditRecord == null) {
      await store.insertAuditRecord({
        eventId: event.id,
        eventType: event.type,
        appUserId: event.app_user_id,
        payload: parsedEvent.payload,
        status: "processing",
        receivedAt: timestamp,
        processedAt: null,
        lastError: null,
      });
    } else {
      await store.markAuditRecord(event.id, {
        status: "processing",
        processedAt: null,
        lastError: null,
      });
    }

    try {
      await store.upsertSubscription(mapSubscriptionRecord(event));
      await store.markAuditRecord(event.id, {
        status: "processed",
        processedAt: timestamp,
        lastError: null,
      });
      return successResponse({ ok: true, eventId: event.id });
    } catch {
      await store.markAuditRecord(event.id, {
        status: "failed",
        processedAt: null,
        lastError: "processing_failed",
      });
      return errorResponse(500, "Webhook processing failed.");
    }
  };
}

function parseRevenueCatEvent(
  payload: unknown,
):
  | {
    ok: true;
    payload: RevenueCatWebhookPayload;
    event: RevenueCatSubscriptionEvent;
  }
  | { ok: false; reason: string } {
  if (payload == null || typeof payload !== "object") {
    return { ok: false, reason: "Invalid webhook payload." };
  }

  const candidate = payload as Record<string, unknown>;
  if (
    typeof candidate["api_version"] !== "string" ||
    candidate["event"] == null ||
    typeof candidate["event"] !== "object"
  ) {
    return { ok: false, reason: "Invalid webhook payload." };
  }

  const event = candidate["event"] as Record<string, unknown>;
  if (
    typeof event["id"] !== "string" ||
    typeof event["type"] !== "string" ||
    typeof event["app_user_id"] !== "string" ||
    typeof event["original_app_user_id"] !== "string" ||
    typeof event["product_id"] !== "string" ||
    typeof event["event_timestamp_ms"] !== "number" ||
    (typeof event["expiration_at_ms"] !== "number" &&
      event["expiration_at_ms"] !== null) ||
    (event["environment"] !== "PRODUCTION" &&
      event["environment"] !== "SANDBOX")
  ) {
    return { ok: false, reason: "Invalid webhook payload." };
  }

  if (
    !HANDLED_REVENUECAT_EVENT_TYPES.includes(
      event["type"] as RevenueCatSubscriptionEvent["type"],
    )
  ) {
    return { ok: false, reason: "Unhandled event type." };
  }

  const appUserId = event["app_user_id"];
  if (
    appUserId.startsWith("\$RCAnonymousID") ||
    !UUID_REGEX.test(appUserId)
  ) {
    return { ok: false, reason: "Invalid app user id." };
  }

  const parsedPayload = candidate as unknown as RevenueCatWebhookPayload;
  return {
    ok: true,
    payload: parsedPayload,
    event: parsedPayload.event,
  };
}

function mapSubscriptionRecord(
  event: RevenueCatSubscriptionEvent,
): SubscriptionRecord {
  return {
    userId: event.app_user_id,
    status: mapSubscriptionStatus(event),
    productId: event.product_id,
    expiresAt: event.expiration_at_ms == null
      ? null
      : new Date(event.expiration_at_ms).toISOString(),
  };
}

function mapSubscriptionStatus(
  event: RevenueCatSubscriptionEvent,
): SubscriptionRecord["status"] {
  if (event.type === "CANCELLATION") {
    return "cancelled";
  }

  if (event.type === "EXPIRATION") {
    return "expired";
  }

  if (event.period_type === "TRIAL") {
    return "trial";
  }

  return "active";
}

function isAuthorized(
  headerValue: string | null,
  expectedValue: string,
): boolean {
  if (headerValue == null || headerValue.length !== expectedValue.length) {
    return false;
  }

  let mismatch = 0;
  for (let index = 0; index < expectedValue.length; index += 1) {
    mismatch |= headerValue.charCodeAt(index) ^ expectedValue.charCodeAt(index);
  }

  return mismatch === 0;
}

function createSupabaseRevenueCatWebhookStore(): RevenueCatWebhookStore {
  const supabase = getServiceRoleClient();

  return {
    async getAuditRecord(eventId) {
      const { data, error } = await supabase
        .from("webhook_audit_log")
        .select(
          "event_id, event_type, app_user_id, payload, status, received_at, processed_at, last_error",
        )
        .eq("event_id", eventId)
        .maybeSingle();

      if (error != null) {
        throw new Error(error.message);
      }

      if (data == null) {
        return null;
      }

      return {
        eventId: data.event_id as string,
        eventType: data.event_type as RevenueCatSubscriptionEvent["type"],
        appUserId: data.app_user_id as string,
        payload: data.payload as RevenueCatWebhookPayload,
        status: data.status as WebhookProcessingStatus,
        receivedAt: data.received_at as string,
        processedAt: data.processed_at as string | null,
        lastError: data.last_error as string | null,
      };
    },
    async insertAuditRecord(record) {
      const { error } = await supabase.from("webhook_audit_log").insert({
        event_id: record.eventId,
        event_type: record.eventType,
        app_user_id: record.appUserId,
        payload: record.payload,
        status: record.status,
        received_at: record.receivedAt,
        processed_at: record.processedAt,
        last_error: record.lastError,
      });

      if (error != null) {
        throw new Error(error.message);
      }
    },
    async markAuditRecord(eventId, patch) {
      const { error } = await supabase.from("webhook_audit_log").update({
        status: patch.status,
        processed_at: patch.processedAt ?? null,
        last_error: patch.lastError ?? null,
      }).eq("event_id", eventId);

      if (error != null) {
        throw new Error(error.message);
      }
    },
    async upsertSubscription(record) {
      const { error } = await supabase.from("subscriptions").upsert({
        id: record.userId,
        user_id: record.userId,
        status: record.status,
        product_id: record.productId,
        expires_at: record.expiresAt,
      }, { onConflict: "user_id" });

      if (error != null) {
        throw new Error(error.message);
      }
    },
  };
}
