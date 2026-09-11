#!/usr/bin/env bash
# Local CI: analyze, test, and check the committed oracle fixtures are what the
# pinned upstream source still generates.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FORMAT=skipped
ANALYZE=skipped
TEST=skipped
FIXTURES=skipped
EXAMPLE=skipped
PUBLISH=skipped
STATUS=0

step() { printf '\n=== %s ===\n' "$1"; }
fail() { STATUS=1; }

step "dart format"
if dart format --output=none --set-exit-if-changed .; then
  FORMAT=pass
else
  FORMAT=FAIL
  fail
fi

step "flutter analyze"
if flutter analyze; then ANALYZE=pass; else ANALYZE=FAIL; fail; fi

step "flutter test"
if flutter test; then TEST=pass; else TEST=FAIL; fail; fi

step "oracle fixture freshness"
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found; skipping the fixture freshness check"
  FIXTURES="skipped (no npm)"
else
  BEFORE="$(mktemp -d)"
  restore() {
    cp "$BEFORE"/*.json "$ROOT/oracle/fixtures/" 2>/dev/null || true
    rm -rf "$BEFORE"
  }
  trap restore EXIT
  cp "$ROOT"/oracle/fixtures/*.json "$BEFORE"/

  if (cd "$ROOT/oracle" \
      && { [ -d node_modules ] || npm ci --silent; } \
      && npm run --silent gen); then
    if diff -ru "$BEFORE" "$ROOT/oracle/fixtures" -x 'runtime' >/dev/null; then
      FIXTURES=pass
    else
      echo "Regenerated fixtures differ from the committed ones:"
      diff -ru "$BEFORE" "$ROOT/oracle/fixtures" -x 'runtime' | head -60
      FIXTURES=FAIL
      fail
    fi
  else
    echo "oracle generation failed"
    FIXTURES=FAIL
    fail
  fi

  restore
  trap - EXIT
fi

step "example"
if [ -f "$ROOT/example/pubspec.yaml" ]; then
  if (cd "$ROOT/example" && flutter pub get >/dev/null && flutter analyze && flutter test); then
    EXAMPLE=pass
  else
    EXAMPLE=FAIL
    fail
  fi
fi

step "publish dry run"
if dart pub publish --dry-run; then
  PUBLISH=pass
else
  PUBLISH=FAIL
  fail
fi

step "summary"
printf 'format             %s\n' "$FORMAT"
printf 'analyze            %s\n' "$ANALYZE"
printf 'test               %s\n' "$TEST"
printf 'oracle fixtures    %s\n' "$FIXTURES"
printf 'example            %s\n' "$EXAMPLE"
printf 'publish dry run    %s\n' "$PUBLISH"
printf '\n%s\n' "$([ $STATUS -eq 0 ] && echo 'CI passed' || echo 'CI failed')"
exit $STATUS
