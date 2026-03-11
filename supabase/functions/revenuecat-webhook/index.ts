/**
 * RevenueCat webhook entry point.
 *
 * Auth model: server-to-server only via the shared authorization token checked
 * in `handler.ts`.
 */
import { buildRevenueCatWebhookHandler } from "./handler.ts";

const handler = buildRevenueCatWebhookHandler();

Deno.serve((request) => handler(request));
