# pade-coder

Coder integration for [PADE](https://github.com/After-Certainty/pade).

This repository explores a narrow integration boundary:

> How should a Coder workspace acquire the PADE consumer, connect to a PADE broker, and establish the workload/session identity needed to request capabilities without making Coder-specific behavior part of PADE core?

## Status

Early integration work. No stable module contract is published yet.

The first goal is deliberately small: make an existing Coder workspace able to use an existing PADE broker. Broker deployment, Runtime Conditions projection, and agent-specific behavior remain separate concerns.

## Intended boundary

```text
Coder template / workspace
        |
        | provisions workspace + identity
        v
pade-coder
        |
        | installs/configures PADE consumer
        v
PADE consumer ---------------> PADE broker
        |                          |
        | scoped material          | authorization + fulfillment
        v                          v
agent / developer tools       provider systems
```

### This repository should own

- reusable Terraform for adding PADE to Coder workspaces;
- Coder-specific bootstrap and workspace integration;
- configuration of the PADE broker endpoint;
- integration tests and examples that prove the Coder/PADE contract;
- eventually, a Coder Registry-compatible module.

### This repository should not own

- PADE protocol or portable intent changes;
- PADE broker implementation;
- broker deployment infrastructure;
- Runtime Conditions semantics or RC → PADE projection;
- agent-specific permission models for Cursor, Claude Code, Codex, or other agents;
- durable credentials inside the workspace.

Those concerns belong in their respective projects:

- [PADE](https://github.com/After-Certainty/pade) — portable development-session capability intent and Consumer/Broker contracts.
- [pade-broker-deployment](https://github.com/After-Certainty/pade-broker-deployment) — concrete broker deployment and operator policy.
- [rc-pade](https://github.com/After-Certainty/rc-pade) — experimental Runtime Conditions → PADE projection.

## Planned shape

The intended end state is a reusable Coder module:

```hcl
module "pade" {
  source = "registry.coder.com/after-certainty/pade/coder"

  agent_id        = coder_agent.main.id
  broker_endpoint = var.pade_broker_endpoint
}
```

The exact inputs are not yet a contract. They should be derived from working integration evidence rather than designed speculatively.

A small reference template may also live here to prove the module against a real Coder workspace, but the reusable module is the primary artifact.

## First experiment

The first implementation should answer only the minimum questions needed for a useful integration:

1. How is the released PADE CLI installed into a Coder workspace?
2. How is the broker endpoint supplied without coupling it to a particular broker deployment?
3. Which identity is available to the workspace, and how does PADE obtain or forward it?
4. What state, if any, must survive workspace restarts?
5. Can the same PADE-enabled workspace be used by different agents without changing the PADE integration?

Once those answers are demonstrated, the module surface can be made explicit and tested.

## Design rule

Keep the dependency direction simple:

```text
Coder integration --> PADE contracts
PADE core          -X-> Coder integration
```

Integration evidence may reveal missing generic seams in PADE, but Coder-specific concepts should not leak into PADE core unless independent evidence shows they are generally required.

## License

Apache License 2.0.
