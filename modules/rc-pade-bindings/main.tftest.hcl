mock_provider "coder" {}

variables {
  agent_id              = "test-agent-id"
  verified_profile_path = "~/.config/pade/rc-downstream/verified-profile.yaml"
  policy_path           = "~/.config/pade/rc-downstream/policy.yaml"
  allow_capabilities    = ["github.repo.read", "github.repo.write"]
  broker_binding = {
    provider = "broker"
    broker = {
      endpoint = "https://broker.example.com"
      audience = "https://broker.example.com"
      identity = "gce"
    }
  }
  bindings_path = "~/.config/pade/coder-bindings.yaml"
  pade_scripts  = ["after-certainty-pade-install_script"]
}

run "defaults" {
  command = plan

  assert {
    condition     = output.scripts == ["after-certainty-rc-pade-bindings"]
    error_message = "the module should expose one completion sync point"
  }

  assert {
    condition     = output.bindings_path == "~/.config/pade/coder-bindings.yaml"
    error_message = "bindings_path should pass through unchanged"
  }

  assert {
    condition     = local.dependency_scripts == ["after-certainty-pade-install_script"]
    error_message = "the binding script must always depend on the PADE install pipeline"
  }

  assert {
    condition     = strcontains(local.bind_script, "rc-pade") && strcontains(local.bind_script, "--verified-profile")
    error_message = "the integration must invoke the reusable rc-pade bind interface"
  }

  assert {
    condition     = !strcontains(local.bind_script, "validation-report") && !strcontains(local.bind_script, "rc-extension-resolver")
    error_message = "validator-specific report contracts must not leak into the Coder binding integration"
  }

  assert {
    condition     = strcontains(local.bind_script, "coder exp sync want") && strcontains(local.bind_script, "after-certainty-pade-install_script")
    error_message = "the integration must wait for PADE before binding"
  }

  assert {
    condition     = strcontains(local.bind_script, "capabilities: {}")
    error_message = "the integration must revoke stale bindings before later failures"
  }

  assert {
    condition     = coder_script.bind.run_on_start == true && coder_script.bind.start_blocks_login == false
    error_message = "the Coder binding script should run on start without blocking login"
  }
}

run "additional_prerequisites" {
  command = plan

  variables {
    prerequisite_scripts = [
      "rc-handoff-verify",
      "rc-pade-install",
    ]
  }

  assert {
    condition = local.dependency_scripts == [
      "after-certainty-pade-install_script",
      "rc-handoff-verify",
      "rc-pade-install",
    ]
    error_message = "verification and rc-pade installation sync points should serialize before binding"
  }
}

run "session_output" {
  command = plan

  variables {
    session_out = "~/.config/pade/rc-downstream/development-session.yaml"
  }

  assert {
    condition     = strcontains(local.bind_script, "--session-out")
    error_message = "session_out should be forwarded to rc-pade bind"
  }
}

run "empty_allowlist" {
  command = plan

  variables {
    allow_capabilities = []
  }

  expect_failures = [var.allow_capabilities]
}

run "comma_in_capability" {
  command = plan

  variables {
    allow_capabilities = ["github.repo.read,github.repo.write"]
  }

  expect_failures = [var.allow_capabilities]
}

run "unverified_relative_profile_path" {
  command = plan

  variables {
    verified_profile_path = "verified-profile.yaml"
  }

  expect_failures = [var.verified_profile_path]
}

run "relative_bindings_path" {
  command = plan

  variables {
    bindings_path = "coder-bindings.yaml"
  }

  expect_failures = [var.bindings_path]
}

run "missing_pade_scripts" {
  command = plan

  variables {
    pade_scripts = []
  }

  expect_failures = [var.pade_scripts]
}

run "unsafe_sync_name" {
  command = plan

  variables {
    prerequisite_scripts = ["verify;echo-bad"]
  }

  expect_failures = [var.prerequisite_scripts]
}

run "non_broker_binding" {
  command = plan

  variables {
    broker_binding = {
      provider = "exec"
      broker = {
        endpoint = "https://broker.example.com"
        audience = "aud"
        identity = "gce"
      }
    }
  }

  expect_failures = [var.broker_binding]
}

run "non_https_broker" {
  command = plan

  variables {
    broker_binding = {
      provider = "broker"
      broker = {
        endpoint = "http://broker.example.com"
        audience = "aud"
        identity = "gce"
      }
    }
  }

  expect_failures = [var.broker_binding]
}

run "unsupported_identity" {
  command = plan

  variables {
    broker_binding = {
      provider = "broker"
      broker = {
        endpoint = "https://broker.example.com"
        audience = "aud"
        identity = "unknown"
      }
    }
  }

  expect_failures = [var.broker_binding]
}
