# RC → PADE bindings

Optional Coder integration for turning an **already verified** Runtime Conditions
Profile into PADE Consumer bindings through the reusable
[`rc-pade bind`](https://github.com/After-Certainty/rc-pade) boundary.

This module is intentionally separate from `modules/pade`. Workspaces that use
static PADE capabilities do not need Runtime Conditions or rc-pade.

## Boundary

```text
Runtime Conditions producer / validator
        ↓
trusted handoff verification
        ↓
verified Profile bytes
        ↓
Coder prerequisite sync completes
        ↓
rc-pade bind
  + operator ProjectionPolicy
  + operator capability allowlist
  + module.pade.broker_binding
        ↓
module.pade.bindings_path
        ↓
PADE Consumer → broker
```

The module does **not**:

- validate Runtime Conditions;
- define or verify a signed-handoff format;
- install `rc-pade`;
- accept a validator-specific `validation-report.yaml`;
- grant any PADE capability;
- change broker authorization or provider authority.

The caller owns verification and rc-pade installation and exposes those steps
through Coder synchronization names.

## Example

Use `module.pade` in dynamic mode:

```tf
module "pade" {
  source          = "git::https://github.com/After-Certainty/pade-coder.git//modules/pade"
  agent_id        = coder_agent.main.id
  broker_endpoint = var.pade_broker_endpoint

  # Dynamic mode: PADE starts each workspace lifecycle with no capabilities.
  broker_capabilities = []
}
```

Then bind only after the trusted verifier and rc-pade installer have completed:

```tf
module "rc_pade_bindings" {
  source   = "git::https://github.com/After-Certainty/pade-coder.git//modules/rc-pade-bindings"
  agent_id = coder_agent.main.id

  verified_profile_path = "~/.config/pade/rc-downstream/verified-profile.yaml"
  policy_path           = "~/.config/pade/rc-downstream/policy.yaml"
  allow_capabilities    = ["github.repo.read", "github.repo.write"]

  broker_binding = module.pade.broker_binding
  bindings_path  = module.pade.bindings_path
  pade_scripts   = module.pade.scripts

  # These names are examples. The template must supply real scripts that only
  # complete after successful verification / installation.
  prerequisite_scripts = [
    "rc-handoff-verify",
    "rc-pade-install",
  ]

  rc_pade_command = "~/.local/bin/rc-pade"
}
```

A workload that requires the generated bindings should wait on this module:

```tf
resource "coder_script" "workload" {
  agent_id = coder_agent.main.id
  script   = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    coder exp sync want workload-ready ${join(" ", module.rc_pade_bindings.scripts)}
    coder exp sync start workload-ready

    # PADE-dependent work goes here.

    coder exp sync complete workload-ready
  EOT
}
```

## Fail-closed lifecycle

The binding script waits for `module.pade.scripts` and all additional
prerequisites before starting its own sync point.

After those prerequisites complete, it immediately replaces the target PADE
bindings with:

```yaml
version: "0.1"
capabilities: {}
```

It then verifies that the caller-provided Profile and policy files exist,
locates the caller-provided rc-pade executable, writes the non-secret broker
binding locally, and invokes:

```text
rc-pade bind
  --verified-profile ...
  --policy ...
  --broker-binding ...
  --allow-capabilities ...
  --output ...
```

The module publishes its Coder sync completion **only after** `rc-pade bind`
returns successfully. A missing Profile, missing policy, missing rc-pade
executable, unsupported RC demand, allowlist rejection, malformed broker
configuration, or write failure leaves the bindings empty and the module sync
incomplete.

`modules/pade` independently clears dynamic bindings at workspace startup, so
an upstream verifier failure that prevents this module from running also leaves
the workspace without usable stale bindings.

## Trust boundary

`verified_profile_path` is a precondition, not a claim made by this module.
The script never decides that arbitrary Profile bytes are trusted. The template
must ensure the file is written only by a successful trust/validation step and
must include that step in `prerequisite_scripts`.

This keeps the Runtime Conditions trust format replaceable. The Coder binding
module does not know whether trust came from the Experiment 014 signed handoff,
a CI-produced attestation, a future Runtime Conditions standard, or another
operator-approved mechanism.

The broker remains the authorization boundary. A local binding says where to
request a capability; it does not authorize the workspace subject.

## Current evidence

The module contract is covered by Terraform and container tests, including:

- PADE + verifier/install synchronization ordering;
- exact `rc-pade bind` argument handoff without a validation report;
- broker-binding transfer from Terraform to rc-pade;
- stale-binding revocation;
- no sync completion after rc-pade failure;
- no sync completion after missing verified Profile input;
- optional DevelopmentSession output.

The underlying pieces have separate live evidence from
[`rc-pade` Experiments 013–014](https://github.com/After-Certainty/rc-pade/tree/main/experiments),
including GCE-backed Coder, module-managed bindings, PADE v0.4.1, signed
handoff verification, broker-authorized `github.repo.read`, and broker-denied
`github.repo.write`.

This exact helper module still needs its own live GCE Coder checkpoint. See
[Experiment 002](../../experiments/002-rc-pade-bindings/README.md).
