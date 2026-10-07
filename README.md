# pade-coder

Coder integration for [PADE](https://github.com/After-Certainty/pade).

The repository explores a narrow integration boundary:

> How should a Coder workspace acquire the PADE Consumer, connect to a PADE broker, and use runtime-native workload identity without making Coder-specific behavior part of PADE core?

## Status

Early integration work. The first reusable Terraform module is implemented under [`modules/pade`](modules/pade), with the GCE-backed broker path captured as [Experiment 001](experiments/001-gce-broker/README.md).

The module has been dogfooded in the existing GCE-backed Coder environment: a workspace built from a template using the module resolved `github.repo.read` through the deployed PADE broker end to end. The contract is proven for that one path (GCE identity, Linux amd64, PADE v0.3.0) and is not yet published to the Coder Registry.

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

Coder owns workspace lifecycle. The underlying runtime owns workload identity. PADE consumes that identity and mediates authorized capabilities.

## Module

A Coder template can add PADE with:

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

The module installs the released PADE CLI, verifies its release checksum, and writes a separate module-managed binding at `~/.config/pade/coder-bindings.yaml`.

See [modules/pade/README.md](modules/pade/README.md) for the current contract.

## Experiments

### Experiment 001 — GCE-backed Coder → PADE broker

[Experiment 001](experiments/001-gce-broker/README.md) builds on the earlier `rc-pade` identity work:

- Docker-backed Coder did not expose a suitable PADE workload identity.
- GCE-backed Coder exposed Google/GCE metadata identity.
- PADE v0.3.0 used that identity against the deployed multi-issuer broker to obtain scoped `github.repo.read` material without durable provider credentials in the workspace.

The experiment in this repository turns that evidence into a reusable Coder module and provides a safe live-validation script for the module itself. The live run with the module succeeded; see the [recorded result](experiments/001-gce-broker/README.md#live-result-2026-10-06).

## Responsibility boundary

This repository owns:

- reusable Terraform for adding PADE to Coder workspaces;
- Coder-specific PADE installation and bootstrap;
- trusted local broker binding configuration;
- integration tests and examples that prove the Coder/PADE contract;
- eventually, a Coder Registry contribution.

It does not own:

- PADE protocol or portable intent changes;
- PADE broker implementation;
- broker deployment infrastructure or authorization policy;
- Runtime Conditions semantics or RC → PADE projection;
- Cursor-, Claude-, Codex-, or other agent-specific permission models;
- durable provider authority inside the workspace.

Related projects:

- [PADE](https://github.com/After-Certainty/pade) — portable development-session capability intent and Consumer/Broker contracts.
- [pade-broker-deployment](https://github.com/After-Certainty/pade-broker-deployment) — concrete broker deployment and operator policy.
- [rc-pade](https://github.com/After-Certainty/rc-pade) — experimental Runtime Conditions → PADE projection and the earlier Coder/GCE identity evidence.

## Design rule

Keep the dependency direction simple:

```text
Coder integration --> PADE contracts
PADE core          -X-> Coder integration
```

Integration evidence may reveal missing generic seams in PADE, but Coder-specific concepts should not leak into PADE core unless independent evidence shows they are generally required.

## License

Apache License 2.0.
