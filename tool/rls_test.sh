#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/flutter-supabase-rls.XXXXXX")"
base_port="${SUPABASE_RLS_BASE_PORT:-$((55000 + RANDOM % 2000))}"
db_port="$((base_port))"
shadow_port="$((base_port + 1))"
api_port="$((base_port + 2))"

cleanup() {
  supabase stop --workdir "$tmp_root" --yes >/dev/null 2>&1 || true
  rm -rf "$tmp_root"
}

trap cleanup EXIT

cp -R "$repo_root/supabase" "$tmp_root/supabase"

ruby - "$tmp_root/supabase/config.toml" "$api_port" "$db_port" "$shadow_port" <<'RUBY'
config_path, api_port, db_port, shadow_port = ARGV

contents = File.read(config_path)
contents.sub!(/^project_id = ".*"$/, %(project_id = "rls-test-#{Process.pid}"))
contents.sub!(/^port = 54321$/, "port = #{api_port}")
contents.sub!(/^port = 54322$/, "port = #{db_port}")
contents.sub!(/^shadow_port = 54320$/, "shadow_port = #{shadow_port}")
File.write(config_path, contents)
RUBY

supabase db start --workdir "$tmp_root" >/dev/null
supabase db reset --workdir "$tmp_root" --local --no-seed --yes >/dev/null

PGPASSWORD=postgres psql \
  "postgresql://postgres:postgres@127.0.0.1:${db_port}/postgres" \
  -v ON_ERROR_STOP=1 \
  -f "$repo_root/supabase/tests/rls_policies.sql"

printf 'RLS policy verification passed on local Supabase database (port %s).\n' "$db_port"
