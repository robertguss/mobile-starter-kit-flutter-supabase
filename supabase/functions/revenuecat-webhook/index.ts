import { buildRevenueCatWebhookHandler } from "./handler.ts";

const handler = buildRevenueCatWebhookHandler();

Deno.serve((request) => handler(request));
