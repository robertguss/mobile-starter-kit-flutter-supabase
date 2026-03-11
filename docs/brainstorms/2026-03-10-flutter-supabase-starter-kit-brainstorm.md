---
date: 2026-03-10
topic: flutter-supabase-starter-kit
---

# Flutter & Supabase Starter Kit — Brainstorm

## What We're Building

A production-ready, full-stack Flutter + Supabase starter kit distributed as a
GitHub template repository. It serves two audiences equally: **solo developers /
indie hackers** who want a batteries-included mobile app foundation, and **AI
coding agents** (Claude Code, etc.) that benefit from predictable conventions
and strict architecture.

The kit ships as a **full monolith** — every integration wired in and working
out of the box. Users click "Use this template" on GitHub and get a complete
production stack with auth, offline-first data sync, monetization, push
notifications, observability, and CI/CD.

## Why This Approach

We considered three approaches:

1. **Full Monolith** (chosen) — Everything wired in, one cohesive template
2. **Core + Feature Branches** — Solid core on main, optional integrations as
   mergeable branches
3. **Layered with Feature Flags** — Single repo with config-driven feature
   toggling

We chose the full monolith because the entire value proposition is "clone this
and have a production stack." Cherry-picking and feature flags add complexity
that undermines the batteries-included promise. Users who don't need a specific
integration can remove it — that's simpler than merging it in.

## Key Decisions

- **Target audience:** Both human developers and AI agents equally. Architecture
  optimized for predictability and conventions.
- **UI system:** Material 3 with a custom theme layer (centralized color
  palette, typography scale, component overrides in `core/theme/`) — NOT
  shadcn_ui. The Flutter shadcn ports are still maturing and risk component
  gaps. Material 3 is battle-tested and well-understood by AI agents.
- **Auth strategy:** Email OTP for v1, with the abstract `AuthRepository`
  pattern designed so Apple Sign In + Google Sign In slot in cleanly later. No
  social login in v1.
- **Offline depth:** Full offline CRUD via PowerSync. Users can create, update,
  and delete data offline with automatic sync on reconnection. Conflict
  resolution uses **server-wins** strategy (PowerSync default) — simple,
  predictable, and appropriate for a starter kit. This is a major
  differentiator.
- **Platform scope:** iOS and Android only. No web, no desktop. Keeps scope
  tight and avoids platform-specific edge cases.
- **Testing strategy:** Full TDD coverage across all features using mocktail.
  Tests serve as both verification and documentation/examples for users of the
  starter kit.
- **Distribution model:** GitHub template repository. Users click "Use this
  template" for a fresh copy. Low friction, easy to maintain.
- **Stack scope:** All integrations ship in v1 (PowerSync, RevenueCat,
  OneSignal, Sentry, PostHog, slang, flutter_gen). The full stack IS the value
  prop.
- **Code generation:** Three packages use build_runner (riverpod_generator,
  flutter_gen, slang). The starter kit needs a well-configured `build.yaml` and
  clear dev workflow for running codegen.

## Tech Stack (Confirmed)

| Category      | Choice                             | Notes                                      |
| ------------- | ---------------------------------- | ------------------------------------------ |
| Frontend      | Flutter (iOS + Android)            | Mobile only                                |
| Backend       | Supabase                           | PostgreSQL, Auth, Edge Functions, Storage  |
| Local IaC     | Supabase CLI                       | Local Docker, migration generation         |
| Offline sync  | PowerSync                          | Full offline CRUD                          |
| State mgmt    | Riverpod                           | flutter_riverpod + riverpod_generator      |
| Routing       | GoRouter                           | Declarative, no codegen                    |
| UI system     | Material 3 + custom theme          | Changed from shadcn_ui                     |
| Auth          | Supabase Email OTP                 | Social login designed for but not included |
| Monetization  | RevenueCat                         | Webhook-driven via Edge Functions          |
| Observability | Sentry + PostHog                   | Crash reporting + analytics/feature flags  |
| Push          | OneSignal                          | Triggered by Edge Functions                |
| i18n          | slang                              | JSON-based internationalization            |
| Assets        | flutter_gen                        | Generated asset references                 |
| Linting       | very_good_analysis + riverpod_lint | Strict analysis                            |
| CI/CD         | GitHub Actions + Fastlane          | Automated testing + deployment             |
| Testing       | mocktail                           | Full TDD, strict repository pattern        |

## Open Questions

_(All resolved during brainstorm session — none remaining.)_

## Next Steps

→ `/ce:plan` for detailed implementation plan covering all 6 phases
