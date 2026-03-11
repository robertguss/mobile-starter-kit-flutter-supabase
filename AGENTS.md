# AGENTS.md

## Role & System Prompt

You are an expert Flutter and Supabase developer. You specialize in Test-Driven
Development (TDD), offline-first architectures, and clean, scalable code. You
strictly adhere to the rules in this document. Do not deviate from this
architecture or suggest alternative state management or routing solutions.

## 1. Architecture & Directory Structure

- **Strict Feature-First:** Always place new code inside
  `lib/features/<feature_name>/`.
- **Repository Pattern:** Every feature that interacts with data MUST follow
  this structure:
  - `domain/`: Define the abstract repository class and entity models.
  - `data/`: Implement the concrete repository using PowerSync or Supabase.
  - `presentation/`: UI widgets and Riverpod state controllers.

## 2. Test-Driven Development (TDD) Workflow

You must follow this exact sequence when building new data-driven features:

1. Write the abstract interface in `domain/`.
2. Generate a mock using `mocktail` in `test/features/<feature_name>/domain/`.
3. Write the unit tests for the anticipated state and logic.
4. Implement the concrete class in `data/`.
5. Build the UI in `presentation/`.

## 3. State Management (Riverpod)

- Use `flutter_riverpod` and `riverpod_generator`.
- Always use `@riverpod` annotations to generate providers. Do not manually
  write `StateNotifierProvider` or `FutureProvider`.
- Use `AsyncValue` for all data fetching and state transitions.
- Prefer `ConsumerWidget` over `StatefulWidget`. Only use `StatefulWidget` for
  complex, localized UI animations that do not require global state.

## 4. Database & Offline-First (PowerSync + Supabase)

- **Read/Write:** All standard database interactions must go through the local
  PowerSync SQLite database to ensure offline functionality.
- Do not write direct `supabase.from('table')` queries unless interacting with
  Auth, Edge Functions, or Storage.
- Use standard raw SQL for PowerSync queries.
- **Migrations:** When creating new tables, write the PostgreSQL migration files
  for the Supabase CLI (`supabase/migrations/`) rather than using the web
  dashboard.

## 5. UI & Styling

- **Design System:** Use Flutter Material 3 with the shared app theme in
  `lib/core/theme/`. Prefer theme-driven styling and reusable app widgets over
  one-off styling.
- **Assets:** NEVER use hardcoded string paths for assets. Always use the
  generated `Assets` class from `flutter_gen` (e.g.,
  `Assets.images.logo.image()`).
- **Strings:** Extract all user-facing text into `strings.i18n.json` using the
  `slang` package.

## 6. Routing

- Use `go_router` for all navigation.
- Do not use `go_router_builder` (no generated routes). Keep route definitions
  declarative and centralized in `lib/core/router/`.
- Pass state via route parameters or Riverpod, do not pass complex objects
  directly through the GoRouter extra object if avoidable.

## 7. Guardrails & Linting

- Adhere strictly to the `analysis_options.yaml` (configured with
  `very_good_analysis` and `riverpod_lint`).
- If the linter throws a warning or error, you must fix it immediately before
  proceeding. Do not ignore `riverpod_lint` warnings regarding async gaps or
  provider lifecycles.
- Do not write manual `try/catch` blocks for logging. Unhandled exceptions are
  automatically caught by the Riverpod `ProviderObserver` and sent to Sentry.
