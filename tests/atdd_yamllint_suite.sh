#!/usr/bin/env bash
# tests/atdd_yamllint_suite.sh
# Acceptance Test-Driven Development (ATDD) Suite for Scoped Yamllint CI Workflow (VMER-2235)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASSED_COUNT=0
FAILED_COUNT=0

TARGET_15_FILES=(
  "v5-0/lanes/candidate/konflux-release/payload.yaml"
  "v5-0/lanes/stable/prod/payload.yaml"
  "v5-0/lanes/stable/verify-production-release/payload.yaml"
  "v5-1/lanes/candidate/gating/payload.yaml"
  "v5-1/lanes/candidate/konflux-release/payload.yaml"
  "v5-1/lanes/candidate/release-candidate/payload.yaml"
  "v5-1/lanes/candidate/stage/payload.yaml"
  "v5-1/lanes/stable/prod/payload.yaml"
  "v5-1/lanes/stable/qe/payload.yaml"
  "v5-1/lanes/stable/verify-production-release/payload.yaml"
  "v5-2/lanes/candidate/konflux-release/payload.yaml"
  "v5-2/lanes/stable/prod/payload.yaml"
  "v5-2/lanes/stable/qe/payload.yaml"
  "v5-2/lanes/stable/stage/payload.yaml"
  "v5-2/lanes/stable/verify-production-release/payload.yaml"
)

log_test() {
  local id="$1"
  local desc="$2"
  printf "==> [%s] %s ... " "$id" "$desc"
}

pass() {
  printf "\033[0;32mPASS\033[0m\n"
  PASSED_COUNT=$((PASSED_COUNT + 1))
}

fail() {
  local reason="$1"
  printf "\033[0;31mFAIL\033[0m (%s)\n" "$reason"
  FAILED_COUNT=$((FAILED_COUNT + 1))
}

echo "=========================================================="
echo " Starting ATDD 4-Layer Verification Suite (VMER-2235)"
echo "=========================================================="

# ==============================================================================
# Layer 1: Unit & Syntax Verification
# ==============================================================================
log_test "Test 1.1" "Workflow YAML Syntax Validity"
if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/yamllint.yml'))" >/dev/null 2>&1; then
  pass
else
  fail "YAML parse error in .github/workflows/yamllint.yml"
fi

log_test "Test 1.2" "15 Placeholder Files Byte Count Assert (2 bytes: #\n)"
L1_2_ERRORS=0
for f in "${TARGET_15_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    L1_2_ERRORS=$((L1_2_ERRORS + 1))
  else
    sz=$(wc -c < "$f")
    if [ "$sz" -ne 2 ]; then
      L1_2_ERRORS=$((L1_2_ERRORS + 1))
    fi
  fi
done
if [ "$L1_2_ERRORS" -eq 0 ]; then
  pass
else
  fail "$L1_2_ERRORS of 15 files are not exactly 2 bytes (#\\n)"
fi

log_test "Test 1.3" "Strict Yamllint on 15 Placeholder Files"
L1_3_ERRORS=0
for f in "${TARGET_15_FILES[@]}"; do
  if ! yamllint -c .yamllint.yml --strict "$f" >/dev/null 2>&1; then
    L1_3_ERRORS=$((L1_3_ERRORS + 1))
  fi
done
if [ "$L1_3_ERRORS" -eq 0 ]; then
  pass
else
  fail "$L1_3_ERRORS of 15 files failed yamllint --strict"
fi

# ==============================================================================
# Layer 2: Integration & Mocked PR Execution (Isolated Simulation)
# ==============================================================================
WORKFLOW_SCRIPT_TMP=$(mktemp)
python3 -c "
import yaml
with open('.github/workflows/yamllint.yml') as f:
    doc = yaml.safe_load(f)
steps = doc['jobs']['yamllint']['steps']
lint_step = [s for s in steps if s.get('name') == 'Lint payload.yaml files']
if lint_step and 'run' in lint_step[0]:
    print(lint_step[0]['run'])
else:
    exit(1)
" > "$WORKFLOW_SCRIPT_TMP" 2>/dev/null || true

log_test "Test 2.0" "Workflow Run Script Extracted"
if [ -s "$WORKFLOW_SCRIPT_TMP" ] && grep -q "DIFF_OUT" "$WORKFLOW_SCRIPT_TMP"; then
  pass
else
  fail "Workflow does not yet have hardened scoped script"
fi

if [ -s "$WORKFLOW_SCRIPT_TMP" ] && grep -q "DIFF_OUT" "$WORKFLOW_SCRIPT_TMP"; then
  TMP_CLONE=$(mktemp -d)
  git clone "$REPO_ROOT" "$TMP_CLONE" -q

  cleanup_clone() {
    rm -rf "$TMP_CLONE"
    rm -f "$WORKFLOW_SCRIPT_TMP"
  }
  trap cleanup_clone EXIT

  # Copy current working tree changes (the repaired placeholders and workflow) into the isolated clone
  cp "$REPO_ROOT/.github/workflows/yamllint.yml" "$TMP_CLONE/.github/workflows/yamllint.yml"
  for f in "${TARGET_15_FILES[@]}"; do
    cp "$REPO_ROOT/$f" "$TMP_CLONE/$f"
  done

  # Commit these base fixes in the clone so origin/main is the base and HEAD is the fixed baseline
  ORIG_DIR=$(pwd)
  cd "$TMP_CLONE"
  git config user.email "test@example.com"
  git config user.name "Test Runner"
  git commit -am "fix(base): apply placeholder repairs and workflow updates" -q
  # Update origin/main in the clone to point to this baseline commit
  git update-ref refs/remotes/origin/main HEAD

  # Test 2.1: Non-YAML PR (only README changed)
  git checkout -b pr-non-yaml -q
  echo "test non-yaml modification" >> README.md
  git commit -am "test: non-yaml commit" -q
  OUT_2_1=$(mktemp)
  if EVENT_NAME="pull_request" BASE_REF="main" BEFORE_SHA="" bash "$WORKFLOW_SCRIPT_TMP" > "$OUT_2_1" 2>&1; then
    if grep -q "No payload.yaml files were modified in this run. Skipping lint" "$OUT_2_1"; then
      log_test "Test 2.1" "Mock PR: Non-YAML change only (skip lint)" && pass
    else
      log_test "Test 2.1" "Mock PR: Non-YAML change only (skip lint)" && fail "Unexpected output: $(cat "$OUT_2_1")"
    fi
  else
    log_test "Test 2.1" "Mock PR: Non-YAML change only (skip lint)" && fail "Script failed on non-yaml PR"
  fi
  rm -f "$OUT_2_1"
  git checkout main -q

  # Test 2.2: Single Payload PR
  git checkout -b pr-single-payload -q
  TEST_FILE="v4-13/lanes/stable/prod/payload.yaml"
  echo "# extra comment" >> "$TEST_FILE"
  git commit -am "test: single payload commit" -q
  OUT_2_2=$(mktemp)
  if EVENT_NAME="pull_request" BASE_REF="main" BEFORE_SHA="" bash "$WORKFLOW_SCRIPT_TMP" > "$OUT_2_2" 2>&1; then
    if grep -q "Linting modified payload.yaml file(s):" "$OUT_2_2" && grep -q "$TEST_FILE" "$OUT_2_2"; then
      log_test "Test 2.2" "Mock PR: Single payload modified (lints exactly 1)" && pass
    else
      log_test "Test 2.2" "Mock PR: Single payload modified (lints exactly 1)" && fail "Failed to lint target file: $(cat "$OUT_2_2")"
    fi
  else
    log_test "Test 2.2" "Mock PR: Single payload modified (lints exactly 1)" && fail "Script failed lint on modified payload"
  fi
  rm -f "$OUT_2_2"
  git checkout main -q

  # Test 2.3: Deleted Payload PR
  git checkout -b pr-delete-payload -q
  git rm -q "$TEST_FILE"
  git commit -m "test: delete payload" -q
  OUT_2_3=$(mktemp)
  if EVENT_NAME="pull_request" BASE_REF="main" BEFORE_SHA="" bash "$WORKFLOW_SCRIPT_TMP" > "$OUT_2_3" 2>&1; then
    if grep -q "No payload.yaml files were modified in this run. Skipping lint" "$OUT_2_3"; then
      log_test "Test 2.3" "Mock PR: Deleted payload excluded via diff-filter" && pass
    else
      log_test "Test 2.3" "Mock PR: Deleted payload excluded via diff-filter" && fail "Deleted file was not excluded: $(cat "$OUT_2_3")"
    fi
  else
    log_test "Test 2.3" "Mock PR: Deleted payload excluded via diff-filter" && fail "Script failed when payload was deleted"
  fi
  rm -f "$OUT_2_3"
  git checkout main -q

  # Test 2.4: Yamllint Config PR
  git checkout -b pr-config-change -q
  echo "# config comment" >> .yamllint.yml
  git commit -am "test: update config" -q
  OUT_2_4=$(mktemp)
  if EVENT_NAME="pull_request" BASE_REF="main" BEFORE_SHA="" bash "$WORKFLOW_SCRIPT_TMP" > "$OUT_2_4" 2>&1; then
    if grep -q ".yamllint.yml was modified in range; triggering full repository scan" "$OUT_2_4"; then
      log_test "Test 2.4" "Mock PR: .yamllint.yml change triggers full scan" && pass
    else
      log_test "Test 2.4" "Mock PR: .yamllint.yml change triggers full scan" && fail "Config change did not trigger full scan: $(cat "$OUT_2_4")"
    fi
  else
    log_test "Test 2.4" "Mock PR: .yamllint.yml change triggers full scan" && fail "Script failed on config update full scan"
  fi
  rm -f "$OUT_2_4"
  git checkout main -q

  # Test 2.5: Invalid Base Ref Fallback
  OUT_2_5=$(mktemp)
  if EVENT_NAME="pull_request" BASE_REF="non-existent-branch-12345" BEFORE_SHA="" bash "$WORKFLOW_SCRIPT_TMP" > "$OUT_2_5" 2>&1; then
    if grep -q "Base ref origin/non-existent-branch-12345 unresolvable; falling back to full scan" "$OUT_2_5"; then
      log_test "Test 2.5" "Mock PR: Invalid base ref falls back to full scan" && pass
    else
      log_test "Test 2.5" "Mock PR: Invalid base ref falls back to full scan" && fail "Did not fall back on invalid base ref: $(cat "$OUT_2_5")"
    fi
  else
    log_test "Test 2.5" "Mock PR: Invalid base ref falls back to full scan" && fail "Script failed on invalid base ref fallback"
  fi
  rm -f "$OUT_2_5"
  cd "$ORIG_DIR"

  cleanup_clone
  trap - EXIT
else
  echo "Skipping Layer 2 detailed mock tests until workflow script is updated."
fi

# ==============================================================================
# Layer 3: Full Repository Regression
# ==============================================================================
log_test "Test 3.1" "Full Repository Regression (All 202 Payloads Pass Strict Yamllint)"
if git ls-files -z '**/payload.yaml' | xargs -0 -r yamllint -c .yamllint.yml --strict >/dev/null 2>&1; then
  pass
else
  fail "Full repository scan failed (malformed payloads present)"
fi

# ==============================================================================
# Layer 4: Edge Cases & Resilience
# ==============================================================================
log_test "Test 4.1" "Checkout fetch-depth is 0 in yamllint.yml"
if python3 -c "
import yaml
with open('.github/workflows/yamllint.yml') as f:
    doc = yaml.safe_load(f)
steps = doc['jobs']['yamllint']['steps']
checkout_steps = [s for s in steps if 'actions/checkout' in s.get('uses', '')]
assert checkout_steps and checkout_steps[0].get('with', {}).get('fetch-depth') == 0
" >/dev/null 2>&1; then
  pass
else
  fail "actions/checkout@v4 does not have fetch-depth: 0"
fi

echo "=========================================================="
echo " ATDD Suite Summary: $PASSED_COUNT Passed, $FAILED_COUNT Failed"
echo "=========================================================="

if [ "$FAILED_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
