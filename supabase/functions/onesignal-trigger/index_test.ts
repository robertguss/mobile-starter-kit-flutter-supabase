import { assertEquals, assertObjectMatch } from "@std/assert";

import { buildOneSignalTriggerHandler } from "./handler.ts";

Deno.test("returns 401 when authorization does not match", async () => {
  const handler = buildOneSignalTriggerHandler({
    appId: "app-id",
    apiKey: "api-key",
    authKey: "Bearer secret",
    fetchImpl: async () => new Response(),
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
  const handler = buildOneSignalTriggerHandler({
    appId: "app-id",
    apiKey: "api-key",
    authKey: "Bearer secret",
    fetchImpl: async () => new Response(),
  });

  const response = await handler(
    requestWithPayload({ userId: "bad", contents: "" }),
  );

  assertEquals(response.status, 400);
  assertEquals(await response.json(), {
    error: "Invalid notification payload.",
  });
});

Deno.test("sends a push request to onesignal", async () => {
  const requests: Request[] = [];
  const handler = buildOneSignalTriggerHandler({
    appId: "app-id",
    apiKey: "api-key",
    authKey: "Bearer secret",
    fetchImpl: async (input, init) => {
      requests.push(new Request(input, init));
      return Response.json({ id: "message-123" });
    },
  });

  const response = await handler(requestWithPayload(validPayload()));

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    ok: true,
    messageId: "message-123",
  });
  assertEquals(requests.length, 1);
  assertEquals(
    requests[0].headers.get("authorization"),
    "Key api-key",
  );
  assertObjectMatch(await requests[0].json(), {
    app_id: "app-id",
    include_aliases: {
      external_id: ["a87f7394-58d5-4d5d-a4e2-ec292743ff6d"],
    },
    target_channel: "push",
    contents: { en: "Build completed successfully" },
    headings: { en: "Starter kit" },
    data: { source: "tests" },
  });
});

Deno.test("returns 502 when onesignal rejects the request", async () => {
  const handler = buildOneSignalTriggerHandler({
    appId: "app-id",
    apiKey: "api-key",
    authKey: "Bearer secret",
    fetchImpl: async () =>
      Response.json({ errors: ["bad request"] }, { status: 400 }),
  });

  const response = await handler(requestWithPayload(validPayload()));

  assertEquals(response.status, 502);
  assertEquals(await response.json(), {
    error: "Notification provider request failed.",
  });
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

function validPayload() {
  return {
    userId: "a87f7394-58d5-4d5d-a4e2-ec292743ff6d",
    contents: "Build completed successfully",
    heading: "Starter kit",
    data: {
      source: "tests",
    },
  };
}
