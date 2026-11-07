terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of the Coder agent where verified Runtime Conditions demand will be bound to PADE."
}

variable "verified_profile_path" {
  type        = string
  description = "Absolute or home-relative path to Runtime Conditions Profile bytes already accepted by an upstream trust/validation gate."

  validation {
    condition     = can(regex("^(~/|/)", var.verified_profile_path))
    error_message = "verified_profile_path must be absolute or start with ~/."
  }
}

variable "policy_path" {
  type        = string
  description = "Absolute or home-relative path to the operator-owned rc-pade ProjectionPolicy."

  validation {
    condition     = can(regex("^(~/|/)", var.policy_path))
    error_message = "policy_path must be absolute or start with ~/."
  }
}

variable "allow_capabilities" {
  type        = set(string)
  description = "Operator-approved PADE capability names that rc-pade may bind."
  nullable    = false

  validation {
    condition = length(var.allow_capabilities) > 0 && alltrue([
      for capability in var.allow_capabilities :
      capability != "" &&
      trimspace(capability) == capability &&
      !strcontains(capability, ",")
    ])
    error_message = "allow_capabilities must contain non-empty, whitespace-trimmed capability names without commas."
  }
}

variable "broker_binding" {
  type = object({
    provider = string
    broker = object({
      endpoint = string
      audience = string
      identity = string
    })
  })
  description = "Non-secret broker binding from module.pade.broker_binding. This is configuration, not an authorization grant."

  validation {
    condition = (
      var.broker_binding.provider == "broker" &&
      can(regex("^https://", var.broker_binding.broker.endpoint)) &&
      trimspace(var.broker_binding.broker.audience) != "" &&
      contains(["gce", "cursor"], var.broker_binding.broker.identity)
    )
    error_message = "broker_binding must be a complete broker-only PADE binding with HTTPS endpoint and a supported identity adapter."
  }
}

variable "bindings_path" {
  type        = string
  description = "module.pade.bindings_path, or another absolute/home-relative PADE bindings path owned by this integration."

  validation {
    condition     = can(regex("^(~/|/)", var.bindings_path))
    error_message = "bindings_path must be absolute or start with ~/."
  }
}

variable "pade_scripts" {
  type        = list(string)
  description = "module.pade.scripts. The binding step always waits for PADE installation before touching module-managed bindings."
  nullable    = false

  validation {
    condition = length(var.pade_scripts) > 0 && alltrue([
      for script in var.pade_scripts :
      can(regex("^[A-Za-z0-9._-]+$", script))
    ])
    error_message = "pade_scripts must contain at least one safe Coder synchronization name."
  }
}

variable "prerequisite_scripts" {
  type        = list(string)
  description = "Additional Coder synchronization names that must complete first, such as signed-handoff verification or rc-pade installation."
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for script in var.prerequisite_scripts :
      can(regex("^[A-Za-z0-9._-]+$", script))
    ])
    error_message = "prerequisite_scripts may contain only safe Coder synchronization names."
  }
}

variable "rc_pade_command" {
  type        = string
  description = "rc-pade executable name or absolute/home-relative path. Installation is intentionally owned by the caller."
  default     = "rc-pade"

  validation {
    condition     = trimspace(var.rc_pade_command) == var.rc_pade_command && var.rc_pade_command != ""
    error_message = "rc_pade_command must be a non-empty, whitespace-trimmed command or path."
  }
}

variable "session_out" {
  type        = string
  description = "Optional absolute/home-relative path for the projected PADE DevelopmentSession."
  default     = null
  nullable    = true

  validation {
    condition     = var.session_out == null ? true : can(regex("^(~/|/)", var.session_out))
    error_message = "session_out must be null, absolute, or start with ~/."
  }
}

locals {
  sync_name           = "after-certainty-rc-pade-bindings"
  dependency_scripts  = distinct(concat(var.pade_scripts, var.prerequisite_scripts))
  allow_capabilities  = join(",", sort(tolist(var.allow_capabilities)))
  broker_binding_json = jsonencode(var.broker_binding)

  bind_script = templatefile("${path.module}/scripts/bind.sh.tftpl", {
    SYNC_NAME_B64             = base64encode(local.sync_name)
    DEPENDENCY_SCRIPTS        = join(" ", local.dependency_scripts)
    VERIFIED_PROFILE_PATH_B64 = base64encode(var.verified_profile_path)
    POLICY_PATH_B64           = base64encode(var.policy_path)
    ALLOW_CAPABILITIES_B64    = base64encode(local.allow_capabilities)
    BROKER_BINDING_B64        = base64encode(local.broker_binding_json)
    BINDINGS_PATH_B64         = base64encode(var.bindings_path)
    RC_PADE_COMMAND_B64       = base64encode(var.rc_pade_command)
    SESSION_OUT_B64           = var.session_out == null ? "" : base64encode(var.session_out)
  })
}

resource "coder_script" "bind" {
  agent_id           = var.agent_id
  display_name       = "RC → PADE Bindings"
  script             = local.bind_script
  run_on_start       = true
  start_blocks_login = false
}

output "scripts" {
  description = "Coder synchronization name that completes only after verified Runtime Conditions demand has been successfully bound through rc-pade."
  value       = [local.sync_name]
}

output "bindings_path" {
  description = "PADE bindings path managed by this integration."
  value       = var.bindings_path
}
