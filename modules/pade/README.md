# PADE Coder module

This directory is the development home for the reusable PADE Coder module.

It is intentionally a scaffold rather than a working installer today. The first integration experiment will establish the minimum contract for:

- installing a released PADE consumer in the workspace;
- configuring an existing PADE broker endpoint;
- using an appropriate Coder workspace identity without introducing durable credentials;
- preserving the same integration across different agents running in the workspace.

The target usage is expected to look roughly like:

```hcl
module "pade" {
  source = "registry.coder.com/after-certainty/pade/coder"

  agent_id        = coder_agent.main.id
  broker_endpoint = var.pade_broker_endpoint
}
```

That example is directional, not a published compatibility contract yet.
