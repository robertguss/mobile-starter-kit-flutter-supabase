/**
 * OneSignal trigger handler.
 *
 * Auth model: trusted backend callers only. Requests must present the exact
 * shared authorization token configured in `ONESIGNAL_TRIGGER_AUTH_KEY`.
 */
import { errorResponse, successResponse } from "../_shared/responses.ts";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface OneSignalTriggerRequest {
  userId: string;
  contents: string;
  heading?: string;
  data?: Record<string, unknown>;
}

interface OneSignalTriggerDeps {
  appId?: string;
  apiKey?: string;
  authKey?: string;
  fetchImpl?: typeof fetch;
}

export function buildOneSignalTriggerHandler(
  deps: OneSignalTriggerDeps = {},
) {
  const appId = deps.appId ?? Deno.env.get("ONESIGNAL_APP_ID") ?? "";
  const apiKey = deps.apiKey ?? Deno.env.get("ONESIGNAL_APP_API_KEY") ?? "";
  const authKey = deps.authKey ?? Deno.env.get("ONESIGNAL_TRIGGER_AUTH_KEY") ??
    "";
  const fetchImpl = deps.fetchImpl ?? fetch;

  return async function handleOneSignalTrigger(
    request: Request,
  ): Promise<Response> {
    if (!appId || !apiKey || !authKey) {
      return errorResponse(500, "Notification trigger is not configured.");
    }

    const authorization = request.headers.get("authorization");
    if (!isAuthorized(authorization, authKey)) {
      return errorResponse(401, "Unauthorized");
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      return errorResponse(400, "Invalid notification payload.");
    }

    const parsed = parseTriggerRequest(payload);
    if (!parsed.ok) {
      return errorResponse(400, parsed.reason);
    }

    const response = await fetchImpl(
      "https://api.onesignal.com/notifications",
      {
        method: "POST",
        headers: {
          authorization: `Key ${apiKey}`,
          "content-type": "application/json; charset=utf-8",
        },
        body: JSON.stringify({
          app_id: appId,
          include_aliases: {
            external_id: [parsed.value.userId],
          },
          target_channel: "push",
          contents: {
            en: parsed.value.contents,
          },
          headings: parsed.value.heading == null
            ? undefined
            : { en: parsed.value.heading },
          data: parsed.value.data,
        }),
      },
    );

    if (!response.ok) {
      return errorResponse(502, "Notification provider request failed.");
    }

    const body = await response.json() as { id?: string };
    return successResponse({
      ok: true,
      messageId: body.id ?? null,
    });
  };
}

function parseTriggerRequest(
  payload: unknown,
):
  | { ok: true; value: OneSignalTriggerRequest }
  | { ok: false; reason: string } {
  if (payload == null || typeof payload !== "object") {
    return { ok: false, reason: "Invalid notification payload." };
  }

  const candidate = payload as Record<string, unknown>;
  if (
    typeof candidate["userId"] !== "string" ||
    !UUID_REGEX.test(candidate["userId"]) ||
    typeof candidate["contents"] !== "string" ||
    candidate["contents"].trim().length === 0
  ) {
    return { ok: false, reason: "Invalid notification payload." };
  }

  if (
    candidate["heading"] != null && typeof candidate["heading"] !== "string"
  ) {
    return { ok: false, reason: "Invalid notification payload." };
  }

  if (
    candidate["data"] != null &&
    (typeof candidate["data"] !== "object" || Array.isArray(candidate["data"]))
  ) {
    return { ok: false, reason: "Invalid notification payload." };
  }

  return {
    ok: true,
    value: {
      userId: candidate["userId"],
      contents: candidate["contents"].trim(),
      heading: candidate["heading"] as string | undefined,
      data: candidate["data"] as Record<string, unknown> | undefined,
    },
  };
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
