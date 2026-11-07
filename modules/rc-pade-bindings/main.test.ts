import {
  afterEach,
  beforeAll,
  describe,
  expect,
  it,
  setDefaultTimeout,
} from "bun:test";
import {
  execContainer,
  findResourceInstance,
  readFileContainer,
  removeContainer,
  runContainer,
  runTerraformApply,
  runTerraformInit,
} from "~test";

setDefaultTimeout(120_000);

const IMAGE = "debian:bookworm-slim";
const STUB_PATH =
  "/stubs:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
const SYNC_NAME = "after-certainty-rc-pade-bindings";
const BINDINGS_PATH = "/root/.config/pade/coder-bindings.yaml";

const defaultVars = {
  agent_id: "test-agent-id",
  verified_profile_path: "/work/verified-profile.yaml",
  policy_path: "/work/policy.yaml",
  allow_capabilities: '["github.repo.read","github.repo.write"]',
  broker_binding: JSON.stringify({
    provider: "broker",
    broker: {
      endpoint: "https://broker.example.com",
      audience: "https://broker.example.com",
      identity: "gce",
    },
  }),
  bindings_path: BINDINGS_PATH,
  pade_scripts: '["after-certainty-pade-install_script"]',
  prerequisite_scripts: '["rc-handoff-verify","rc-pade-install"]',
};

const CODER_STUB = `#!/bin/sh
[ "$1 $2" = "exp sync" ] || exit 1
case "$3" in want|start|complete) ;; *) exit 1 ;; esac
echo "$@" >> /tmp/coder.log
`;

const RC_PADE_STUB = `#!/bin/sh
set -eu
printf '%s\\n' "$@" > /tmp/rc-pade.args
[ "$1" = "bind" ] || exit 2
shift

output=""
broker=""
session=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --broker-binding) broker="$2"; shift 2 ;;
    --session-out) session="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$output" ] || exit 3
[ -n "$broker" ] || exit 4
cp "$broker" /tmp/broker-captured.json

if [ "${RC_PADE_FAIL:-0}" = "1" ]; then
  exit 42
fi

cat > "$output" <<'EOF'
version: "0.1"
capabilities:
  github.repo.read:
    provider: broker
    broker:
      endpoint: https://broker.example.com
      audience: https://broker.example.com
      identity: gce
  github.repo.write:
    provider: broker
    broker:
      endpoint: https://broker.example.com
      audience: https://broker.example.com
      identity: gce
EOF
chmod 0600 "$output"

if [ -n "$session" ]; then
  printf 'kind: DevelopmentSession\\n' > "$session"
  chmod 0600 "$session"
fi
`;

let cleanupFunctions: (() => Promise<void>)[] = [];
afterEach(async () => {
  const cleanups = cleanupFunctions.reverse();
  cleanupFunctions = [];
  for (const cleanup of cleanups) {
    await cleanup();
  }
});

const setup = async (vars: Record<string, string> = {}) => {
  const state = await runTerraformApply(import.meta.dir, {
    ...defaultVars,
    ...vars,
  });
  const instance = findResourceInstance(state, "coder_script", "bind");
  const id = await runContainer(IMAGE);
  cleanupFunctions.push(() => removeContainer(id));

  const writeFile = (path: string, content: string, mode: string) =>
    `echo '${Buffer.from(content).toString("base64")}' | base64 -d > ${path} && chmod ${mode} ${path}`;

  const bootstrap = await execContainer(id, [
    "sh",
    "-c",
    [
      "set -eu",
      "mkdir -p /stubs /work /root/.config/pade",
      writeFile("/stubs/coder", CODER_STUB, "0755"),
      writeFile("/stubs/rc-pade", RC_PADE_STUB, "0755"),
      writeFile("/work/verified-profile.yaml", "kind: RuntimeConditionsProfile\\n", "0600"),
      writeFile("/work/policy.yaml", "kind: ProjectionPolicy\\n", "0600"),
      writeFile("/tmp/run.sh", instance.script, "0755"),
      `cat > ${BINDINGS_PATH} <<'EOF'`,
      'version: "0.1"',
      "capabilities:",
      "  stale.capability: {}",
      "EOF",
      `chmod 0600 ${BINDINGS_PATH}`,
    ].join("\n"),
  ]);
  expect(bootstrap.exitCode).toBe(0);
  expect(bootstrap.stderr).toBe("");

  const run = (env: Record<string, string> = {}) =>
    execContainer(
      id,
      ["bash", "/tmp/run.sh"],
      [
        "-e",
        `PATH=${STUB_PATH}`,
        ...Object.entries(env).flatMap(([k, v]) => ["-e", `${k}=${v}`]),
      ],
    );
  const sh = (command: string) => execContainer(id, ["sh", "-c", command]);

  return { state, instance, id, run, sh };
};

describe("rc-pade-bindings", () => {
  beforeAll(async () => {
    await runTerraformInit(import.meta.dir);
  });

  it("waits for PADE and verifier prerequisites before calling rc-pade bind", async () => {
    const { id, run, sh } = await setup();
    const result = await run();
    expect(result.exitCode).toBe(0);

    expect((await sh("cat /tmp/coder.log")).stdout.trim().split("\n")).toEqual([
      `exp sync want ${SYNC_NAME} after-certainty-pade-install_script rc-handoff-verify rc-pade-install`,
      `exp sync start ${SYNC_NAME}`,
      `exp sync complete ${SYNC_NAME}`,
    ]);

    const args = (await sh("cat /tmp/rc-pade.args")).stdout.trim().split("\n");
    expect(args[0]).toBe("bind");
    expect(args).toContain("--verified-profile");
    expect(args).toContain("/work/verified-profile.yaml");
    expect(args).toContain("--policy");
    expect(args).toContain("/work/policy.yaml");
    expect(args).toContain("--allow-capabilities");
    expect(args).toContain("github.repo.read,github.repo.write");
    expect(args).toContain("--output");
    expect(args).toContain(BINDINGS_PATH);
    expect(args).not.toContain("--validation-report");

    expect(
      JSON.parse(await readFileContainer(id, "/tmp/broker-captured.json")),
    ).toEqual({
      provider: "broker",
      broker: {
        endpoint: "https://broker.example.com",
        audience: "https://broker.example.com",
        identity: "gce",
      },
    });

    expect(Bun.YAML.parse(await readFileContainer(id, BINDINGS_PATH))).toEqual({
      version: "0.1",
      capabilities: {
        "github.repo.read": {
          provider: "broker",
          broker: {
            endpoint: "https://broker.example.com",
            audience: "https://broker.example.com",
            identity: "gce",
          },
        },
        "github.repo.write": {
          provider: "broker",
          broker: {
            endpoint: "https://broker.example.com",
            audience: "https://broker.example.com",
            identity: "gce",
          },
        },
      },
    });
    expect((await sh(`stat -c %a ${BINDINGS_PATH}`)).stdout.trim()).toBe("600");
  });

  it("leaves bindings empty and does not complete sync when rc-pade fails", async () => {
    const { id, run, sh } = await setup();
    const result = await run({ RC_PADE_FAIL: "1" });
    expect(result.exitCode).toBe(42);

    expect(Bun.YAML.parse(await readFileContainer(id, BINDINGS_PATH))).toEqual({
      version: "0.1",
      capabilities: {},
    });
    expect((await sh("cat /tmp/coder.log")).stdout.trim().split("\n")).toEqual([
      `exp sync want ${SYNC_NAME} after-certainty-pade-install_script rc-handoff-verify rc-pade-install`,
      `exp sync start ${SYNC_NAME}`,
    ]);
  });

  it("revokes stale bindings before failing on a missing verified Profile", async () => {
    const { id, run, sh } = await setup();
    await sh("rm /work/verified-profile.yaml");
    const result = await run();
    expect(result.exitCode).not.toBe(0);
    expect(result.stderr).toContain("verified Profile is missing");

    expect(Bun.YAML.parse(await readFileContainer(id, BINDINGS_PATH))).toEqual({
      version: "0.1",
      capabilities: {},
    });
    expect((await sh("test -e /tmp/rc-pade.args")).exitCode).not.toBe(0);
    expect((await sh("cat /tmp/coder.log")).stdout.trim().split("\n")).toEqual([
      `exp sync want ${SYNC_NAME} after-certainty-pade-install_script rc-handoff-verify rc-pade-install`,
      `exp sync start ${SYNC_NAME}`,
    ]);
  });

  it("forwards an optional DevelopmentSession output", async () => {
    const sessionPath = "/work/development-session.yaml";
    const { run, sh } = await setup({ session_out: sessionPath });
    expect((await run()).exitCode).toBe(0);

    const args = (await sh("cat /tmp/rc-pade.args")).stdout.trim().split("\n");
    expect(args).toContain("--session-out");
    expect(args).toContain(sessionPath);
    expect((await sh(`test -f ${sessionPath}`)).exitCode).toBe(0);
    expect((await sh(`stat -c %a ${sessionPath}`)).stdout.trim()).toBe("600");
  });
});
