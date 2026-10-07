# Experiment 001 — minimal Coder → PADE broker path

## Question

Can a Coder workspace acquire the released PADE Consumer, use runtime-native workload identity, and resolve an explicitly configured capability through an existing PADE broker without durable provider credentials in the workspace?

## Prior evidence

This experiment deliberately builds on earlier `rc-pade` evidence rather than re-designing the identity layer:

- [005A](https://github.com/After-Certainty/rc-pade/tree/main/experiments/005-coder-identity-discovery) showed that a Docker-backed Coder workspace did **not** expose a PADE-fit workload identity. The Coder agent token is control-plane material, not a general audience-bound workload token.
- [005C](https://github.com/After-Certainty/rc-pade/tree/main/experiments/005c-deployed-pade) showed that a **GCE-backed** Coder workspace can use GCE metadata identity with PADE v0.3.0 to resolve `github.repo.read` through the deployed multi-issuer broker, with no durable workspace credentials.

The integration therefore keeps the ownership boundary explicit:

```text
Coder                         workspace lifecycle
GCE                           workload identity
pade-coder                    PADE install + local broker binding
PADE Consumer / broker        capability authorization + fulfillment
```

Coder is not treated as the identity provider.

## Reusable module

The reusable module under `modules/pade`:

1. installs the official PADE release for Linux amd64/arm64;
2. verifies the downloaded archive against the release `SHA256SUMS`;
3. writes a separate module-managed binding at `~/.config/pade/coder-bindings.yaml`;
4. configures only the capability names explicitly supplied by the Coder template;
5. selects the runtime identity adapter explicitly (the proven Coder path is `gce`);
6. adds PADE and the binding path to normal shell startup configuration.

The binding file contains broker coordinates and capability names, not durable provider credentials.

## Live validation

The earlier 005C run proves the GCE identity/broker substrate. This experiment's module-specific live dogfood also succeeded; see the [recorded live result](#live-result-2026-10-06). To repeat the validation, use a GCE-backed Coder workspace whose attached Google service-account subject is authorized by the target PADE broker.

The template should include the module approximately as follows:

```hcl
module "pade" {
  source = "git::https://github.com/After-Certainty/pade-coder.git//modules/pade"

  agent_id            = coder_agent.main.id
  pade_version        = "v0.3.0"
  broker_endpoint     = var.pade_broker_endpoint
  broker_identity     = "gce"
  broker_capabilities = ["github.repo.read"]
}
```

After the workspace starts, open a fresh shell and run:

```bash
bash experiments/001-gce-broker/run.sh
```

The script never prints the raw GCE ID token or returned GitHub token. It prints the attached service-account email because that is a non-secret operational identifier.

## Expected success

```text
PADE v0.3.0
GCE metadata service-account identity present
github.repo.read -> provider: broker
broker authenticates Google/GCE subject
broker returns scoped GitHub material
ordinary GitHub read succeeds
```

The child process receives broker-returned material only for the duration of `pade exec`.

## Failure behavior

### Missing workload identity

A Docker/local Coder workspace without a suitable workload identity should fail before capability fulfillment. The module does **not** reinterpret `CODER_AGENT_TOKEN`, Coder PATs, or external-auth tokens as PADE workload identity.

### Unavailable broker

PADE should fail the broker request. There is no fallback to ambient GitHub credentials or a direct provider configured by this module.

### Denied capability

If the authenticated subject is not authorized for `github.repo.read`, the broker should deny resolution and the child process must not receive capability material.

### Missing capability mapping

A capability not listed in `broker_capabilities` is absent from the module-managed bindings and therefore cannot silently resolve through the configured broker.

## State and portability

The PADE binary and module-managed binding live under the workspace user's home directory. If that home is persistent, they survive workspace restarts; if it is ephemeral, the Coder startup script recreates them. No persistence is required for workload tokens or provider credentials.

The integration is agent-neutral. Cursor, Claude Code, Codex, or a human shell can use the same `pade` executable and binding when they run in the same workspace. Agent-specific installation and permission models remain outside this module.

## Status

- [x] Existing live evidence establishes GCE-backed Coder → PADE broker identity and fulfillment.
- [x] Reusable module installs a released PADE CLI and writes broker bindings.
- [x] Failure boundaries are explicit and fail closed.
- [x] The module itself ran successfully in the GCE-backed Coder workspace; safe output from `run.sh` is recorded below.

Live validation is manual because CI does not have the production broker authorization or GCE workload identity.

## Live result (2026-10-06)

Run from the `gcp-pade` Coder template (Debian 12, `e2-medium`, `us-central1-a`) with this module added and `broker_endpoint` set to the deployed broker:

```text
=== PADE installation ===
pade version v0.3.0 (0467ed2, built 2026-09-13T02:26:11Z)
=== GCE workload identity substrate ===
metadata service account: pade-coder-workspace@after-certainty.iam.gserviceaccount.com
note: Coder is not the identity provider; PADE uses GCE metadata to mint the broker-audience ID token
=== PADE configuration ===
✓ pade.yaml DevelopmentSession/pade-coder-experiment-001 is valid
✓ capability "github.repo.read" is well formed

Manifest OK.
Bindings: /home/ksteffe/.config/pade/coder-bindings.yaml

github.repo.read
  access: use
  required: true
  bound: true
  provider: broker
  status: configured
  message: bound; availability unknown until runtime (plan/capabilities do not probe providers)
  endpoint: https://pade-broker-754719312452.us-central1.run.app
=== broker-authenticated capability ===
repo_full_name=After-Certainty/after-certainty
pade-coder experiment 001: success
```

The first dogfood run surfaced one defect: the installer and `run.sh` called `pade version`, but PADE v0.3.0 exposes only the `--version` flag. The install itself completed (checksum verified, binary and bindings written) but the Coder startup script exited non-zero. Both now call `pade --version`.
