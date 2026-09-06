#!/bin/sh
# Run `make check` at every commit on this branch that main does not have.
#
# Agents work unattended here, and a commit message saying "all gates passed"
# is worth exactly as much as the shell that produced it. One did not: on the
# night of 2026-09-06 the guard was `make check | tail -2 && git commit`, and
# a pipe masks make's exit status, so the && was testing whether `tail`
# succeeded. Every commit happened to be green anyway except one -- which this
# script is how we know.
#
# Uses a detached worktree, so it never touches your working tree.
#
#   ./scripts/verify_history.sh [base]      (base defaults to main)
set -u
BASE="${1:-main}"
WT="$(mktemp -d)/verify"

git rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo "verify_history: no such base '$BASE'"; exit 1; }

git worktree add -q --detach "$WT" HEAD || { echo "verify_history: worktree failed"; exit 1; }
trap 'git worktree remove --force "$WT" >/dev/null 2>&1' EXIT

pass=0; fail=0; failed=""
for c in $(git log --reverse --format=%h "$BASE"..HEAD); do
  git -C "$WT" checkout -q --detach "$c" 2>/dev/null || { echo "  skip $c"; continue; }
  if (cd "$WT" && make check >/dev/null 2>&1); then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); failed="$failed $c"
  fi
done

echo "verify_history: $pass green, $fail red across $BASE..HEAD"
if [ -n "$failed" ]; then
  echo "  red:$failed"
  exit 1
fi
