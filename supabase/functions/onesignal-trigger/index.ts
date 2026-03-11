import { buildOneSignalTriggerHandler } from "./handler.ts";

const handler = buildOneSignalTriggerHandler();

Deno.serve((request) => handler(request));
