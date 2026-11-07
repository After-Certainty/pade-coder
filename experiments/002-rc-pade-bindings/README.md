# Experiment 002 — verified RC → rc-pade bind → module-managed PADE bindings

## Status

**Implementation and CI coverage are being added by this PR. Live GCE-backed
Coder validation has not yet been repeated through the new
`modules/rc-pade-bindings` helper.**

Historical evidence remains unchanged:

- Experiment 001 proved the original static PADE v0.3.0 GCE/Coder broker path.
- `rc-pade` Experiments 013–014 later proved fresh-workspace dynamic bindings,
  signed Runtime Conditions handoff verification, PADE v0.4.1, live
  `github.repo.read`, and broker denial of `github.repo.write`.
- `rc-pade` PR #26 then introduced the reusable validator-independent
  `rc-pade bind --verified-profile ...` boundary.

This experiment closes the remaining Coder integration gap: replace the
historical Experiment 011 adapter invocation with the current reusable rc-pade
CLI.

## Question

Can the real GCE-backed Coder lifecycle use:

```text
signed / trusted RC handoff
        ↓
verification
        ↓
verified-profile.yaml
        ↓
modules/rc-pade-bindings
        ↓
rc-pade bind
        ↓
module.pade.bindings_path
        ↓
PADE v0.4.1
        ↓
deployed broker
```

without:

- the Experiment 011 adapter binary;
- `validation-report.yaml`;
- validator-module/version knowledge inside rc-pade or pade-coder;
- manually staged bindings;
- durable GitHub credentials in the workspace?

## Pinned rc-pade baseline

The first live run should use rc-pade at or after the squash merge that added
`rc-pade bind`:

```text
43226ef96ae09419b6253a6eb364fd44a0ac1305
```

Until rc-pade publishes a checksum-pinned release binary, the Coder template may
build that exact public source revision in a separately synchronized installer
step. Do not make source-at-startup compilation part of `modules/pade` or
`modules/rc-pade-bindings`; packaging remains a separate concern.

## Template changes

Start from the current GCE-backed `gcp-pade` template that carried the
Experiment 014 signed-handoff proof.

Preserve:

- the existing trusted handoff verifier and public trust material;
- the existing operator projection policy and capability allowlist;
- `module.pade` in dynamic mode;
- `module.pade.broker_binding`;
- `module.pade.bindings_path`;
- `module.pade.scripts`;
- GCE workload identity and deployed broker configuration.

Remove from the active startup path:

- build/use of `experiments/011-coder-rc-bindings`;
- materialization/use of the adapter-shaped `validation-report.yaml`;
- `--validation-report` arguments.

Add the new helper approximately as:

```tf
module "rc_pade_bindings" {
  source   = "git::https://github.com/After-Certainty/pade-coder.git//modules/rc-pade-bindings?ref=<this-pr-commit>"
  agent_id = coder_agent.main.id

  verified_profile_path = "~/.config/pade/rc-downstream/verified-profile.yaml"
  policy_path           = "~/.config/pade/rc-downstream/policy.yaml"
  allow_capabilities    = ["github.repo.read", "github.repo.write"]

  broker_binding = module.pade.broker_binding
  bindings_path  = module.pade.bindings_path
  pade_scripts   = module.pade.scripts

  prerequisite_scripts = [
    "<signed-handoff-verifier-sync>",
    "<rc-pade-installer-sync>",
  ]

  rc_pade_command = "$HOME/.local/bin/rc-pade"
  session_out     = "~/.config/pade/rc-downstream/development-session.yaml"
}
```

Use the actual synchronization names from the template. Do not invent a
completion signal that can fire after failed verification.

## Checkpoint 1 — template/static inspection

Before applying the template, verify the rendered startup path contains:

- `rc-pade bind`;
- `--verified-profile`;
- the actual `module.pade.bindings_path`;
- broker binding derived from `module.pade.broker_binding`;
- waits for PADE install, signed-handoff verification, and rc-pade installation.

It must **not** contain:

- `experiments/011-coder-rc-bindings`;
- `--validation-report`;
- `rc-extension-resolver` validator identity as a Coder binding precondition.

## Checkpoint 2 — fresh/restart lifecycle

On a restarted and then freshly recreated GCE workspace:

1. PADE dynamic startup clears the module bindings.
2. Signed-handoff verification succeeds and writes the verified Profile.
3. The pinned rc-pade executable becomes available.
4. `modules/rc-pade-bindings` clears bindings again.
5. `rc-pade bind` writes only the approved broker capabilities.
6. The helper sync completes.
7. No manual file copy is needed.

Record only non-sensitive paths, modes, digests, versions, and outcomes.

## Checkpoint 3 — live PADE v0.4.1 fulfillment

Confirm:

```text
pade --version
→ v0.4.1
```

Then, using the normal module-managed bindings:

### github.repo.read

Expected:

- signed handoff trusted;
- rc-pade projection/bind succeeds;
- broker authorizes the GCE subject;
- ordinary GitHub repository read succeeds.

### github.repo.write

Expected for the currently proven subject:

- local binding exists;
- broker returns authorization denial (currently HTTP 403);
- no write Material reaches the child.

This remains an authorization proof, not a claim that RC demand grants access.

## Checkpoint 4 — fail-closed negative path

Run at least one real startup failure after a prior successful workspace, for
example:

- corrupt the signed handoff; or
- make the pinned rc-pade installer unavailable.

Expected:

- PADE startup clears old dynamic bindings;
- the verifier or prerequisite does not complete, or rc-pade bind fails;
- `after-certainty-rc-pade-bindings` does not complete;
- `~/.config/pade/coder-bindings.yaml` remains mode `0600` with
  `capabilities: {}`;
- dependent PADE workloads do not proceed through the helper sync point.

Then restore the valid template and confirm regeneration.

## Evidence hygiene

Do not record:

- GCE/OIDC bearer tokens;
- GitHub Material;
- AWS Material;
- private signing keys;
- Coder session tokens;
- numeric Google subject identifiers.

Safe evidence includes:

- repository/commit pins;
- public verification-key fingerprint;
- Profile/evidence/policy hashes;
- rc-pade and PADE versions;
- bindings path/mode/hash;
- capability names;
- authorized/denied outcomes.

## Success

Experiment 002 is complete when the actual GCE-backed Coder workspace no longer
depends on the Experiment 011 validation-report adapter and the full live path
works through:

```text
verified Profile
  → rc-pade bind
  → module-managed PADE bindings
  → PADE v0.4.1
  → broker authorization
```

with the fail-closed restart/fresh-home property preserved.
