# pade-coder

Coder integration for [PADE](https://github.com/After-Certainty/pade).

The repository explores a narrow integration boundary:

> How should a Coder workspace acquire the PADE Consumer, connect to a PADE broker, and use runtime-native workload identity without making Coder-specific behavior part of PADE core?

## Status

Early integration work. The reusable PADE module lives under
[`modules/pade`](modules/pade). An optional
[`modules/rc-pade-bindings`](modules/rc-pade-bindings) helper serializes
already-verified Runtime Conditions demand behind PADE installation and invokes
the validator-independent `rc-pade bind` boundary.

The original module dogfood remains the historical Experiment 001 result:
GCE identity, Linux amd64, PADE v0.3.0, and broker-authorized
`github.repo.read`. Later cross-repository
[`rc-pade` Experiments 013–014](https://github.com/After-Certainty/rc-pade/tree/main/experiments)
exercised the same pade-coder dynamic bindings contract with PADE v0.4.1,
module-managed bindings, GCE identity, signed RC handoff verification,
authorized `github.repo.read`, and broker-denied `github.repo.write`.

The PADE module is also under review for publication in the public Coder
Registry.

## Architecture

```text
Coder template / workspace
        |
        | workspace lifecycle
        v
pade-coder
        |
        | install + trusted local broker binding
        v
PADE Consumer ---------------> PADE broker
        ^                          |
        |                          | authorization + fulfillment
runtime workload identity          v
(GCE in Experiment 001)       provider systems
```

For dynamic Runtime Conditions demand, the optional path is:

```text
trusted RC handoff
      ↓
verification
      ↓
verified Profile bytes
      ↓
modules/rc-pade-bindings
      ↓
rc-pade bind
      ↓
module.pade.bindings_path
      ↓
PADE Consumer → broker
```

Coder owns workspace lifecycle. Runtime Conditions validation/trust remains
upstream. `rc-pade` owns platform support/mapping. The underlying runtime owns
workload identity. PADE consumes that identity and mediates authorized
capabilities.

## Modules

### PADE

A Coder template can add PADE with:

```tf
module "pade" {
  source = "git::https://github.com/After-Certainty/pade-coder.git//modules/pade"

  agent_id            = coder_agent.main.id
  pade_version        = "v0.4.1"
  broker_endpoint     = var.pade_broker_endpoint
  broker_identity     = "gce"
  broker_capabilities = ["github.repo.read"]
}
```

The module installs the released PADE CLI, verifies its release checksum, and
writes a separate module-managed binding at
`~/.config/pade/coder-bindings.yaml`.

See [modules/pade/README.md](modules/pade/README.md) for the current contract.

### Optional verified RC → PADE bindings

Templates using dynamic bindings can keep `broker_capabilities = []` and add
the optional helper after an upstream verifier has produced exact verified
Profile bytes:

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

  prerequisite_scripts = [
    "rc-handoff-verify",
    "rc-pade-install",
  ]

  rc_pade_command = "~/.local/bin/rc-pade"
}
```

The prerequisite names above are illustrative. The template owns the verifier
and rc-pade installer. The helper does not validate Runtime Conditions or adopt
a signing format.

See
[modules/rc-pade-bindings/README.md](modules/rc-pade-bindings/README.md).

## Experiments

### Experiment 001 — GCE-backed Coder → PADE broker

[Experiment 001](experiments/001-gce-broker/README.md) builds on the earlier
`rc-pade` identity work:

- Docker-backed Coder did not expose a suitable PADE workload identity.
- GCE-backed Coder exposed Google/GCE metadata identity.
- PADE v0.3.0 used that identity against the deployed multi-issuer broker to
  obtain scoped `github.repo.read` material without durable provider
  credentials in the workspace.

The live run with the module succeeded; see the
[recorded result](experiments/001-gce-broker/README.md#live-result-2026-10-06).

### Experiment 002 — verified RC → rc-pade bind

[Experiment 002](experiments/002-rc-pade-bindings/README.md) is the live
follow-up for the optional helper. It replaces the historical Experiment 011
adapter/report dependency from the Coder startup path with the current
`rc-pade bind --verified-profile` interface while preserving the signed
handoff, dynamic empty bindings, and broker authorization boundaries.

The helper itself has Terraform/container coverage in this repository. Its
specific GCE live checkpoint remains to be recorded separately rather than
inferred from CI.

## Responsibility boundary

This repository owns:

- reusable Terraform for adding PADE to Coder workspaces;
- Coder-specific PADE installation and bootstrap;
- trusted local broker binding configuration;
- optional Coder lifecycle orchestration from **already verified** RC demand to
  `rc-pade bind`;
- integration tests and examples that prove the Coder/PADE contract;
- eventually, a Coder Registry contribution.

It does not own:

- Runtime Conditions semantics, validation, or signed-handoff standards;
- RC → PADE projection semantics;
- PADE protocol or portable intent changes;
- PADE broker implementation;
- broker deployment infrastructure or authorization policy;
- Cursor-, Claude-, Codex-, or other agent-specific permission models;
- durable provider authority inside the workspace.

Related projects:

- [PADE](https://github.com/After-Certainty/pade) — portable development-session capability intent and Consumer/Broker contracts.
- [pade-broker-deployment](https://github.com/After-Certainty/pade-broker-deployment) — concrete broker deployment and operator policy.
- [rc-pade](https://github.com/After-Certainty/rc-pade) — Runtime Conditions → PADE support/mapping and signed-handoff integration evidence.

## Design rule

Keep the dependency direction simple:

```text
Coder integration --> PADE contracts
Coder integration --> optional rc-pade CLI boundary
PADE core          -X-> Coder integration
RC core            -X-> PADE/Coder integration
```

Integration evidence may reveal missing generic seams, but Coder-specific
concepts should not leak into PADE core and PADE-specific concepts should not
leak into Runtime Conditions.

## License

Apache License 2.0.
