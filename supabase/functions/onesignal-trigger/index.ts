/**
 * OneSignal trigger entry point.
 *
 * Auth model: trusted backend callers only via the shared authorization token
 * checked in `handler.ts`.
 */
import { buildOneSignalTriggerHandler } from "./handler.ts";

const handler = buildOneSignalTriggerHandler();

Deno.serve((request) => handler(request));
