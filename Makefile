.PHONY: setup codegen watch test analyze edge-test supabase-start supabase-reset

setup:
	flutter pub get
	$(MAKE) codegen

codegen:
	dart run slang
	dart run build_runner build --delete-conflicting-outputs

watch:
	dart run build_runner watch --delete-conflicting-outputs

test:
	flutter test

analyze:
	flutter analyze

edge-test:
	deno test --import-map supabase/functions/import_map.json \
		supabase/functions/revenuecat-webhook/handler_test.ts \
		supabase/functions/onesignal-trigger/index_test.ts

supabase-start:
	supabase start

supabase-reset:
	supabase db reset
