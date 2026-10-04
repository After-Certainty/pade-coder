#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS="${PADE_BINDINGS:-$HOME/.config/pade/coder-bindings.yaml}"
TARGET_REPO="${PADE_CODER_TARGET_REPO:-After-Certainty/after-certainty}"

die() {
  echo "experiment-001: $*" >&2
  exit 1
}

command -v pade >/dev/null 2>&1 || die "pade is not on PATH; start a new shell after the Coder startup script completes"
command -v curl >/dev/null 2>&1 || die "curl is required"
test -f "$BINDINGS" || die "module-managed bindings not found at $BINDINGS"

echo "=== PADE installation ==="
pade version

echo "=== GCE workload identity substrate ==="
metadata_email="$(curl -fsS -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email')" \
  || die "GCE metadata identity is unavailable; this experiment requires a GCE-backed Coder workspace"
test -n "$metadata_email" || die "GCE metadata returned an empty service-account email"
echo "metadata service account: $metadata_email"
echo "note: Coder is not the identity provider; PADE uses GCE metadata to mint the broker-audience ID token"

echo "=== PADE configuration ==="
pade validate -f "$ROOT/pade.yaml"
caps="$(pade capabilities -f "$ROOT/pade.yaml" --bindings "$BINDINGS")"
echo "$caps"
grep -q 'github.repo.read' <<<"$caps" || die "github.repo.read is not configured"
grep -q 'provider: broker' <<<"$caps" || die "github.repo.read is not configured for broker resolution"

echo "=== broker-authenticated capability ==="
pade exec -f "$ROOT/pade.yaml" --bindings "$BINDINGS" \
  --capability github.repo.read --quiet -- \
  sh -eu -c '
    test -n "${GITHUB_TOKEN:-}" || {
      echo "experiment-001: broker returned no GITHUB_TOKEN material" >&2
      exit 1
    }
    body="$(curl -fsSL \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/'"$TARGET_REPO"'")"
    printf "%s" "$body" | grep -q "\"full_name\": \"'"$TARGET_REPO"'\"" || {
      echo "experiment-001: GitHub response did not identify the expected repository" >&2
      exit 1
    }
    echo "repo_full_name='"$TARGET_REPO"'"
    echo "pade-coder experiment 001: success"
  '
