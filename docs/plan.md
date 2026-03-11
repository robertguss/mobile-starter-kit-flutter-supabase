# AI-First Flutter & Supabase Starter Kit: Master Implementation Plan

## 1. Agent System Instructions

You are an expert Flutter and Supabase developer executing a production-grade
starter kit build. You specialize in Test-Driven Development (TDD),
offline-first architectures, and clean, scalable code.

- Read this entire document before writing any code.
- Do not deviate from the specified tech stack, state management, or routing
  solutions.
- When instructed to implement a phase, follow the strict guardrails outlined in
  Section 6.

## 2. Project Overview

This is a production-ready, full-stack Flutter and Supabase boilerplate. It is
architected specifically to act as an "App Factory" optimized for AI coding
agents. The architecture prioritizes TDD, strict compiler guardrails,
predictability, and offline-first capabilities to minimize hallucinations and
accelerate feature delivery.

## 3. Tech Stack Matrix

- **Frontend:** Flutter (iOS & Android focus)
- **Backend:** Supabase (PostgreSQL, Auth, Edge Functions, Storage)
- **Local IaC:** Supabase CLI (Local Docker instances, migration generation)
- **Offline-First Sync:** PowerSync (Local SQLite synced automatically with
  Supabase)
- **State Management:** Riverpod (`flutter_riverpod` + `riverpod_generator`)
- **Routing:** GoRouter (Declarative, no code generation)
- **UI/Design System:** `shadcn_ui` (Flutter port)
- **Authentication:** Supabase Email OTP (One-Time Password)
- **Monetization:** RevenueCat (Webhook-driven via Supabase Edge Functions)
- **Observability:** Sentry (Crash reporting) + PostHog (Analytics/Feature
  Flags)
- **Engagement:** OneSignal (Push notifications triggered by Supabase Edge
  Functions)
- **CI/CD:** GitHub Actions + Fastlane

## 4. Architectural Directives

- **Environment Configuration:** Use Dart-only environments via
  `--dart-define-from-file` with JSON configuration files (e.g.,
  `config_dev.json`, `config_prod.json`). Do not use native iOS/Android build
  variants or `flutter_flavorizr`.
- **State & Async Data:** Use Riverpod `AsyncValue` for all data fetching and
  state transitions. Do not manually manage loading/error states.
- **Database Interactions:** All standard data reads/writes must target the
  local PowerSync SQLite database to ensure offline capability. Only query
  Supabase directly for Auth, Edge Functions, or Storage.
- **TDD Enforcement:** Use the Strict Repository Pattern. Always write abstract
  interfaces in `domain/`, mock them using `mocktail` in the `test/` directory,
  write unit/widget tests, and only _then_ implement the concrete
  PowerSync/Supabase calls in `data/`.

## 5. Directory Structure Blueprint

You must strictly adhere to this Feature-First structure:

```text
lib/
├── main.dart                  # Sentry, PostHog, PowerSync init, Riverpod ProviderScope
├── core/
│   ├── router/                # GoRouter configuration (centralized)
│   ├── theme/                 # shadcn_ui design system components
│   ├── env/                   # Environment JSON loaders
│   └── database/              # PowerSync & Supabase client singletons
└── features/
    ├── auth/
    │   ├── domain/            # Abstract AuthRepository, User models
    │   ├── data/              # Supabase Auth SDK implementation
    │   └── presentation/      # UI Widgets, Riverpod StateNotifiers
    └── subscription/
        ├── domain/            # Abstract SubscriptionRepository
        ├── data/              # RevenueCat configuration, Supabase listener
        └── presentation/      # Paywall UI, Riverpod subscription state
test/
└── features/
    └── auth/
        ├── domain/            # Mocktail repository definitions
        ├── data/              # Unit tests for data parsing
        └── presentation/      # Widget tests for UI and Riverpod state
```

```

## 6. Coding Guardrails & Strict Rules

1. **Never use string paths for assets:** Implement `flutter_gen`. Always use
   the generated `Assets` class (e.g., `Assets.images.logo.image()`).
2. **Never hardcode user-facing strings:** Implement `slang` for JSON-based
   internationalization.
3. **Never ignore lints:** The project must use `very_good_analysis` and
   `riverpod_lint`. Fix all async gap and provider lifecycle warnings
   immediately.
4. **Error Handling:** Do not write manual `try/catch` blocks for logging. Rely
   on a global Riverpod `ProviderObserver` to catch unhandled exceptions and
   send them to Sentry automatically.
5. **UI Consistency:** Only use `shadcn_ui` components. Do not pollute feature
   files with custom styling arrays or raw Material widgets if a Shadcn
   equivalent exists.
6. **Migrations:** Generate PostgreSQL migration files using the Supabase CLI
   (`supabase/migrations/`) for any database schema changes.

## 7. Implementation Roadmap (For Agent Execution)

When prompted, execute the build in the following order:

- **Phase 1: Foundation.** Initialize Flutter project, Supabase CLI, and add all
  base dependencies from the tech stack matrix. Set up `very_good_analysis` and
  `riverpod_lint`.
- **Phase 2: Core Infrastructure.** Implement JSON environment loading,
  initialize Sentry/PostHog in `main.dart`, configure `flutter_gen` and `slang`,
  and set up the centralized GoRouter.
- **Phase 3: Data Layer.** Initialize the Supabase client and configure the
  PowerSync local SQLite database engine.
- **Phase 4: Authentication Feature.** Execute TDD workflow to build the
  Supabase Email OTP flow (Domain -> Tests -> Data -> Presentation).
- **Phase 5: Subscriptions & Push.** Integrate RevenueCat UI and OneSignal SDK.
  Generate the necessary Supabase Edge Functions for webhook handling.
- **Phase 6: CI/CD.** Generate the GitHub Actions YAML workflows and the
  Fastlane `Fastfile` for automated testing and deployment.

```
