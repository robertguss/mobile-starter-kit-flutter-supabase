export const HANDLED_REVENUECAT_EVENT_TYPES = [
  "INITIAL_PURCHASE",
  "RENEWAL",
  "CANCELLATION",
  "EXPIRATION",
] as const;

export type RevenueCatEventType =
  (typeof HANDLED_REVENUECAT_EVENT_TYPES)[number];

export type RevenueCatEnvironment = "PRODUCTION" | "SANDBOX";
export type RevenueCatPeriodType =
  | "TRIAL"
  | "INTRO"
  | "NORMAL"
  | "PROMOTIONAL"
  | "PREPAID";

export interface RevenueCatBaseEvent {
  readonly id: string;
  readonly event_timestamp_ms: number;
  readonly app_user_id: string;
  readonly original_app_user_id: string;
  readonly product_id: string;
}

export interface RevenueCatSubscriptionEvent extends RevenueCatBaseEvent {
  readonly type: RevenueCatEventType;
  readonly expiration_at_ms: number | null;
  readonly environment: RevenueCatEnvironment;
  readonly period_type?: RevenueCatPeriodType;
}

export interface RevenueCatWebhookPayload {
  readonly api_version: string;
  readonly event: RevenueCatSubscriptionEvent;
}
