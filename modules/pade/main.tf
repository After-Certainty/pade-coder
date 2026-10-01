terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of the Coder agent for the workspace that will consume PADE."
}

variable "broker_endpoint" {
  type        = string
  description = "The HTTPS endpoint of an existing PADE broker."

  validation {
    condition     = can(regex("^https://", var.broker_endpoint))
    error_message = "broker_endpoint must be an HTTPS URL."
  }
}

variable "pade_version" {
  type        = string
  description = "PADE release version to install. The install mechanism is intentionally not implemented until the first integration experiment proves it."
  default     = null
  nullable    = true
}

# Intentionally no Coder resources yet.
# The first integration experiment will determine the smallest correct bootstrap contract
# (installation, broker configuration, and workspace identity) before this module begins
# creating coder_script/coder_env resources.
