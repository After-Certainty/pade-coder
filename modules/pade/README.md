---
display_name: PADE
description: Install the PADE CLI and bind a workspace to an existing PADE broker using runtime workload identity
icon: ../../../../.icons/electric-plug-emoji.svg
verified: false
tags: [helper, integration, identity, security]
---

# PADE

Installs the [PADE](https://github.com/After-Certainty/pade) CLI in a Coder workspace and writes broker-only capability bindings, so tools in the workspace can resolve explicitly configured capabilities through an existing PADE broker without durable provider credentials.

```tf
module "pade" {
  source              = "registry.coder.com/after-certainty/pade/coder"
  version             = "1.0.0"
  agent_id            = coder_agent.main.id
  broker_endpoint     = "https://pade-broker.example.com"
  broker_capabilities = ["github.repo.read"]
}
```

Before publication to the Registry, the module can be consumed directly from Git:

```tf
module "pade" {
  source              = "git::https://github.com/After-Certainty/pade-coder.git//modules/pade"
  agent_id            = coder_agent.main.id
  broker_endpoint     = "https://pade-broker.example.com"
  broker_capabilities = ["github.repo.read"]
}
```

## What it does

On workspace start, the module:

1. downloads the released PADE CLI for the workspace architecture;
2. verifies the archive against the release `SHA256SUMS`;
3. installs `pade` to `~/.local/bin`;
4. writes `~/.config/pade/coder-bindings.yaml` (mode `0600`) containing only the capabilities listed in `broker_capabilities`;
5. adds `~/.local/bin` to `PATH` and sets `PADE_BINDINGS` in normal shell startup files;
6. runs `pade --version` to confirm the install.

The script blocks login until it completes. Persistent home storage keeps the binary and bindings between starts; ephemeral home storage simply causes them to be recreated.

It does not deploy a PADE broker, define broker-side authorization, or place provider credentials in the workspace or in Terraform state. The bindings file contains only the broker endpoint, audience, identity adapter, and capability names.

The module-managed bindings file is separate from PADE's default `~/.config/pade/bindings.yaml`, so user-managed bindings are not overwritten.

## Prerequisites

- A Linux workspace with `curl`, `tar`, `sha256sum`, `base64`, `awk`, and `find`.
- An existing PADE broker reachable over HTTPS that authorizes the workspace's workload identity.
- A workspace runtime that provides the selected workload identity (for `gce`, the GCE metadata server with an attached service account).

## Inputs

| Name                  | Required | Default         | Purpose                                                    |
| --------------------- | -------- | --------------- | ---------------------------------------------------------- |
| `agent_id`            | yes      | —               | Coder agent whose workspace receives PADE                  |
| `broker_endpoint`     | yes      | —               | HTTPS PADE broker endpoint                                 |
| `broker_capabilities` | yes      | —               | Explicit, non-empty set of capability names for the broker |
| `pade_version`        | no       | `v0.3.0`        | Released PADE CLI version (`0.3.0` and `v0.3.0` both work) |
| `broker_audience`     | no       | broker endpoint | Audience requested for workload identity                   |
| `broker_identity`     | no       | `gce`           | PADE identity adapter (`gce` or `cursor`)                  |

## Outputs

| Name            | Value                                                                  |
| --------------- | ---------------------------------------------------------------------- |
| `bindings_path` | `~/.config/pade/coder-bindings.yaml`                                   |
| `pade_version`  | Normalized PADE version installed by the module (for example `v0.3.0`) |

## Proven vs. accepted

The module accepts every value the current PADE Consumer supports, but only one path has been validated end to end through this module:

| Dimension           | Proven through this module | Accepted, not yet validated here |
| ------------------- | -------------------------- | -------------------------------- |
| Workload identity   | `gce` (GCE metadata)       | `cursor`                         |
| Workspace OS / arch | Linux `amd64`              | Linux `arm64`                    |
| PADE version        | `v0.3.0`                   | other released versions          |
| Capability          | `github.repo.read`         | other broker-authorized names    |

Accepting `broker_identity = "cursor"` reflects what PADE supports; it does not mean a Cursor-on-Coder path has been validated.

## Identity boundary

```text
Coder workspace (e.g. on GCE)
       |
       | runtime workload identity (GCE metadata)
       v
PADE Consumer  ------------->  PADE broker
```

Coder owns the workspace lifecycle. The underlying runtime supplies workload identity. The module does not treat Coder control-plane authentication as PADE identity.

## Examples

### Explicit broker audience

```tf
module "pade" {
  source              = "registry.coder.com/after-certainty/pade/coder"
  version             = "1.0.0"
  agent_id            = coder_agent.main.id
  pade_version        = "v0.3.0"
  broker_endpoint     = "https://pade-broker.example.com"
  broker_audience     = "pade-broker"
  broker_identity     = "gce"
  broker_capabilities = ["github.repo.read"]
}
```

### Using the bindings

New shells pick up `PADE_BINDINGS` automatically. Processes that do not source shell startup files can set `PADE_BINDINGS` to the `bindings_path` output or pass that path to `pade` with `--bindings`.
