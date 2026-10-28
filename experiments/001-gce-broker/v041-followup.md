# PADE v0.4.1 — GCE-backed Coder live broker follow-up

## Status

**Not yet executed from the GCE Coder workspace.** This runbook is for a new,
dated check of the released PADE v0.4.1 consumer with the deployed PADE broker.
The [Experiment 001 historical results](README.md) from October 6, 2026
remain unchanged and must not be relabeled as v0.4.1.

## 1. Update the actual Coder template

The already merged [pade-coder PR #15](https://github.com/After-Certainty/pade-coder/pull/15)
sets the module's default PADE release to v0.4.1. **It does not update a Coder
template/workspace automatically**.

In the Coder template containing `module "pade"`, select an updated module
revision and ensure the effective version is v0.4.1. For example:

```hcl
module "pade" {
  source = "git::https://github.com/After-Certainty/pade-coder.git//modules/pade?ref=ddf9667aa3add3853ebef408234d87a9b4cda560"

  agent_id            = coder_agent.main.id
  pade_version        = "v0.4.1"
  broker_endpoint     = var.pade_broker_endpoint
  broker_identity     = "gce"
  broker_capabilities = ["github.repo.read"]
}
```

This is an **example configuration**, not evidence that the existing
`gcp-pade`/GCE template currently uses these values. The actual template may
use a separate downstream writer with `broker_capabilities = []`; if so,
retain that secure workflow and ensure it writes an authorized broker binding
for `github.repo.read` after the PADE install completes.

Publish/apply the updated Coder template using the operator's normal
workflow, update/restart the existing GCE-backed workspace, and ensure the
`after-certainty-pade-install_script` Coder synchronization has completed.
Do not change workload service accounts, broker IAM, provider secrets, or
production deployments merely to make this check pass.

## 2. Run in the real GCE-backed workspace

From a shell **inside** the updated GCE workspace, with a checked-out copy
of this repository:

```bash
command -v pade
pade --version
test -f "${PADE_BINDINGS:-$HOME/.config/pade/coder-bindings.yaml}"
PADE_CODER_EXPECTED_VERSION=v0.4.1 bash experiments/001-gce-broker/run.sh
```

The environment gate deliberately **fails before any broker call** if the
installed CLI is not PADE v0.4.1. The smoke script:

1. Verifies the released PADE CLI version and module bindings.
2. Reads GCE metadata service-account identity (no ID token printed).
3. Validates the local `DevelopmentSession`, checks the broker capability.
4. Clears any ambient `GITHUB_TOKEN`/`GH_TOKEN` for `pade exec`.
5. Acquires `github.repo.read` Material from the authenticated broker and
   performs a real authorized read of `After-Certainty/after-certainty`.

**Never run `set -x`, print environment variables containing credentials,
or capture raw OIDC JWTs / GitHub token material in logs.** The test should
never fall back to `gh auth`, long-lived PATs, Coder control-plane tokens,
or unrelated CI identity.

## 3. Record only verified evidence

After running, add an append-only section here or in a follow-up PR with:
UTC execution date, workspace runtime (GCE), Coder template/module revision,
PADE version/build commit from `--version`, broker endpoint/audience,
capability, actual live result, and any safely redacted error code.

Do **not** record bearer/JWT strings, `GITHUB_TOKEN`, other provider
credentials, account IDs or numeric Google subject values.

| Check | Status before authorized run |
| --- | --- |
| Template applied and Coder workspace restarted | Not verified |
| PADE v0.4.1 installed in actual workspace | Not verified |
| GCE workload identity available | Not verified |
| `pade validate` and broker binding inspect | Not verified |
| Broker-authenticated `github.repo.read` | Not verified |
| Ordinary GitHub API read with scoped Material | Not verified |

Passing Terraform tests, successful PADE v0.4.1 release downloads, or broker
`401 missing_bearer` probes do **not** substitute for this authenticated test.
