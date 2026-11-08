# Experiment 002 — verified RC → rc-pade bind → module-managed PADE bindings

## Status

**Complete as a consumer-side mirror of the same live run as
[`rc-pade` Experiment 015](https://github.com/After-Certainty/rc-pade/tree/main/experiments/015-pade-coder-rc-pade-bind-dogfood).**

Do **not** treat this directory as a second independent live provenance trail.
Canonical public evidence (checkpoints, digests, template snapshot) lives in
rc-pade Experiment 015. This experiment records the pade-coder ownership claim:
the optional `modules/rc-pade-bindings` helper participated in that live path.

Live result (from rc-pade 015 on `gcp-pade` / `exp015_rc_pade_bind_v2`):

- signed Experiment 014 handoff verified before bind;
- `modules/rc-pade-bindings` @ `c40ba8c` invoked `rc-pade bind --verified-profile`;
- no Experiment 011 adapter and no `validation-report.yaml` on the active path;
- restart + fresh-home regeneration;
- fail-closed untrusted-handoff startup (empty `capabilities: {}`);
- live `github.repo.read` authorized / `github.repo.write` broker-denied (HTTP 403).

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

## Canonical provenance

| Item | Location |
|---|---|
| Live runbook + checkpoints | https://github.com/After-Certainty/rc-pade/tree/main/experiments/015-pade-coder-rc-pade-bind-dogfood |
| Retained Coder template | `rc-pade` `experiments/015-pade-coder-rc-pade-bind-dogfood/template-exp015_rc_pade_bind_v2/` |
| Helper module under test | [`modules/rc-pade-bindings`](../../modules/rc-pade-bindings/) @ `c40ba8c49c987f7b2ea9c1e42eb40fd6c36630a5` |
| rc-pade bind pin | `43226ef96ae09419b6253a6eb364fd44a0ac1305` |

Do not copy rc-pade provenance YAML into this repository.

## Historical context

- Experiment 001 proved the original static PADE v0.3.0 GCE/Coder broker path.
- `rc-pade` Experiments 013–014 proved fresh-workspace dynamic bindings, signed
  Runtime Conditions handoff verification, PADE v0.4.1, live
  `github.repo.read`, and broker denial of `github.repo.write`, while still
  using the historical Experiment 011 adapter on the active path.
- `rc-pade` PR #26 introduced the reusable validator-independent
  `rc-pade bind --verified-profile ...` boundary.
- This repository’s PR #17 added `modules/rc-pade-bindings`.
- `rc-pade` Experiment 015 dogfoods those two changes together on the live
  GCE Coder path.

## Boundary reminder

`modules/rc-pade-bindings` does not validate Runtime Conditions, define a
signing format, install `rc-pade`, or authorize the workspace subject. The
caller owns verification and rc-pade installation sync points; the broker
remains the authorization boundary.

## Success

Experiment 002 is satisfied when the actual GCE-backed Coder workspace no longer
depends on the Experiment 011 validation-report adapter and the full live path
works through:

```text
verified Profile
  → rc-pade bind
  → module-managed PADE bindings
  → PADE v0.4.1
  → broker authorization
```

with the fail-closed restart/fresh-home property preserved. That live proof is
recorded as rc-pade Experiment 015.
