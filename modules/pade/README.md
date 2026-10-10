---
display_name: PADE
description: Install the PADE CLI and bind a workspace to an existing PADE broker using runtime workload identity
icon: ../../../../.icons/pade.svg
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

Coder script lifecycle, synchronization, and logs are handled by `coder-utils`. It materializes the installer at `~/.coder-modules/after-certainty/pade/scripts/install.sh` and writes its output to `~/.coder-modules/after-certainty/pade/logs/install.log`. PADE's binary and bindings retain their tool-specific locations.

Unlike the previous direct startup script, `coder-utils` does not block login while installation runs. Wait for the PADE install script to finish before using `pade`. Dependent Coder scripts can use `coder exp sync want <self> ${join(" ", module.pade.scripts)}` to wait for the install pipeline.

Persistent home storage keeps the binary and bindings between starts; ephemeral home storage simply causes them to be recreated.

It does not deploy a PADE broker, define broker-side authorization, or place provider credentials in the workspace or in Terraform state. The bindings file contains only the broker endpoint, audience, identity adapter, and capability names.

`coder-utils` also reads Coder workspace-owner metadata. Its Terraform data-source state can include existing Coder control-plane credentials supplied by the runtime; these are not passed to PADE or used as workload identity. Keep Terraform state protected as for the parent Coder template.

The module-managed bindings file is separate from PADE's default `~/.config/pade/bindings.yaml`, so user-managed bindings are not overwritten.

## Prerequisites

- A Linux workspace with `curl`, `tar`, `sha256sum`, `base64`, `awk`, and `find`.
- An existing PADE broker reachable over HTTPS that authorizes the workspace's workload identity.
- A workspace runtime that provides the selected workload identity (for `gce`, the GCE metadata server with an attached service account).

## Proven vs. accepted

The module accepts every value the current PADE Consumer supports, but only one path has been validated end to end through this module:

| Dimension           | Proven through this module | Accepted, not yet validated here |
| ------------------- | -------------------------- | -------------------------------- |
| Workload identity   | `gce` (GCE metadata)       | `cursor`                         |
| Workspace OS / arch | Linux `amd64`              | Linux `arm64`                    |
| PADE version        | `v0.4.0`                   | other released versions          |
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
  pade_version        = "v0.4.0"
  broker_endpoint     = "https://pade-broker.example.com"
  broker_audience     = "pade-broker"
  broker_identity     = "gce"
  broker_capabilities = ["github.repo.read"]
}
```

### Using the bindings

New shells pick up `PADE_BINDINGS` automatically. Processes that do not source shell startup files can set `PADE_BINDINGS` to the `bindings_path` output or pass that path to `pade` with `--bindings`.

## Workload identity and credential exposure

`broker_capabilities` creates local resolution configuration, not an authorization
grant. The broker verifies the runtime assertion and applies server-owned policy
on every request. Selecting `gce` or `cursor` chooses how the Consumer obtains
identity; it does not translate Coder user identity into a PADE subject.

GCE workspaces using the same attached service account share the same broker
subject and its allowed capabilities. Coder workspace-owner metadata and RC
provenance do not create per-user isolation. Use distinct runtime identities and
explicit broker policy when that separation is required. The module does not
restrict access to the GCE metadata server or another runtime's identity socket.

A child receiving credential material can read it and pass it to descendants.
A copied credential can remain usable after `pade exec` or a workspace ends,
subject to downstream expiry/revocation. Output redaction is best effort, not a
sandbox. Reusing a valid workload assertion can obtain fresh material while
server policy allows it. Keep bootstrap authority off the workspace and scope
issued authority in downstream IAM.

These boundaries were reviewed at pade-coder
`3805842e6d8b65a9c8993def2ec45349fe8a0639` (2026-10-09), alongside the PADE
`docs/security/2026-10-boundary-investigation.md` report. This documentation change
adds no new identity adapter, grant semantics, or runtime behavior. Existing
module tests cover supported/unsupported identity selection and broker-only
bindings; live Coder/GCE validation was not repeated for this review.
