# PADE Coder module

Reusable Coder workspace integration for [PADE](https://github.com/After-Certainty/pade).

## What it does

The module installs a released PADE CLI, verifies the release checksum, writes broker-only capability bindings, and configures normal workspace shells to find PADE and those bindings.

It does not deploy a PADE broker or define broker-side authorization.

## Usage

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

The eventual Registry form is expected to use `registry.coder.com/after-certainty/pade/coder`.

## Inputs

| Name | Required | Default | Purpose |
| --- | --- | --- | --- |
| `agent_id` | yes | — | Coder agent whose workspace receives PADE |
| `pade_version` | no | `v0.3.0` | Released PADE CLI version |
| `broker_endpoint` | yes | — | HTTPS PADE broker endpoint |
| `broker_audience` | no | broker endpoint | Audience requested for workload identity |
| `broker_identity` | no | `gce` | Current PADE identity adapter (`gce` or `cursor`) |
| `broker_capabilities` | yes | — | Explicit capability names routed through this broker |

## Identity boundary

The first proven Coder path is GCE:

```text
Coder workspace on GCE
       |
       | GCE metadata identity
       v
PADE Consumer
       |
       v
PADE broker
```

Coder owns workspace lifecycle. The underlying runtime supplies workload identity. The module does not redefine Coder control-plane authentication as PADE identity.

## Bindings

The module writes `~/.config/pade/coder-bindings.yaml` and configures normal shells with `PADE_BINDINGS` pointing at that file.

This is separate from PADE's normal `~/.config/pade/bindings.yaml`, so user-managed bindings are not overwritten. Only names explicitly listed in `broker_capabilities` are included.

## Workspace lifecycle

The setup script runs on workspace start and blocks login until it completes. Persistent home storage keeps the installed binary and binding between starts; ephemeral home storage simply causes the script to recreate them.

## Current support

The installer supports Linux `amd64` and `arm64`, matching PADE's released Linux CLI artifacts.

See [Experiment 001](../../experiments/001-gce-broker/README.md) for the Coder/GCE broker proof and live validation procedure.
