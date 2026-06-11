#!/usr/bin/env python3
"""Cross-platform verification entrypoint for the framework template."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import shlex
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PYTHON = sys.executable
YAMLLINT_CONFIG = (
    "{ extends: relaxed, rules: { line-length: disable, document-start: disable, "
    "comments: disable, truthy: {check-keys: false} } }"
)


Step = Callable[[], None]


def run(args: list[str], *, input_text: str | None = None) -> None:
    print("+ " + " ".join(args), flush=True)
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            input=input_text,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"missing executable: {args[0]}") from exc
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


class ProcessMemoryCountersEx(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_ulong),
        ("PageFaultCount", ctypes.c_ulong),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
        ("PrivateUsage", ctypes.c_size_t),
    ]


def process_private_bytes(process: subprocess.Popen[str]) -> int | None:
    if os.name != "nt":
        return None
    counters = ProcessMemoryCountersEx()
    counters.cb = ctypes.sizeof(counters)
    handle = getattr(process, "_handle", None)
    if handle is None:
        return None
    ok = ctypes.windll.psapi.GetProcessMemoryInfo(
        ctypes.c_void_p(handle), ctypes.byref(counters), counters.cb
    )
    if not ok:
        return None
    return int(counters.PrivateUsage)


def run_opa(args: list[str], *, input_text: str | None = None) -> None:
    """Run OPA under a wall-clock timeout and (on Windows) a private-memory cap.

    A pathological Rego policy can drive ``opa eval`` to tens of GB of committed
    memory and hang the host. This bounds it so OPA aborts with a clear error
    instead of wedging the machine. Tunable via OPA_TIMEOUT_SECONDS and
    OPA_MAX_PRIVATE_MB environment variables.
    """
    timeout_seconds = int(os.environ.get("OPA_TIMEOUT_SECONDS", "30"))
    max_private_mb = int(os.environ.get("OPA_MAX_PRIVATE_MB", "1024"))
    max_private_bytes = max_private_mb * 1024 * 1024

    print("+ " + " ".join(args), flush=True)
    try:
        process = subprocess.Popen(
            args,
            cwd=ROOT,
            stdin=subprocess.PIPE if input_text is not None else None,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"missing executable: {args[0]}") from exc

    if input_text is not None and process.stdin is not None:
        process.stdin.write(input_text)
        process.stdin.close()

    deadline = time.monotonic() + timeout_seconds
    peak_private = 0
    killed_reason: str | None = None
    while process.poll() is None:
        private_bytes = process_private_bytes(process)
        if private_bytes is not None:
            peak_private = max(peak_private, private_bytes)
            if private_bytes > max_private_bytes:
                killed_reason = (
                    f"private memory exceeded {max_private_mb} MiB "
                    f"(observed {private_bytes // (1024 * 1024)} MiB)"
                )
                process.kill()
                break
        if time.monotonic() > deadline:
            killed_reason = f"timeout exceeded {timeout_seconds} seconds"
            process.kill()
            break
        time.sleep(0.1)

    returncode = process.wait()
    if killed_reason is not None:
        if peak_private:
            print(f"opa peak private memory: {peak_private // (1024 * 1024)} MiB")
        raise SystemExit(f"opa aborted: {killed_reason}")
    if returncode != 0:
        raise SystemExit(returncode)


def capture(args: list[str], *, input_text: str | None = None) -> str:
    print("+ " + " ".join(args), flush=True)
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            capture_output=True,
            input=input_text,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"missing executable: {args[0]}") from exc
    if completed.returncode != 0:
        sys.stdout.write(completed.stdout)
        sys.stderr.write(completed.stderr)
        raise SystemExit(completed.returncode)
    return completed.stdout


def install(package: str) -> None:
    if os.environ.get("CI", "").lower() != "true":
        print(f"local run: not installing {package}; expecting it to be available", flush=True)
        return
    run([PYTHON, "-m", "pip", "install", "--no-cache-dir", package])


def command_from_env(name: str, default: str) -> list[str]:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return [default]

    raw = raw.strip()
    if raw.startswith("["):
        parsed = json.loads(raw)
        if not isinstance(parsed, list) or not all(
            isinstance(item, str) and item for item in parsed
        ):
            raise SystemExit(f"{name} must be a JSON array of command strings.")
        return parsed

    if Path(raw).exists():
        return [raw]

    return shlex.split(raw, posix=os.name != "nt")


def opa_policy() -> None:
    install("pyyaml==6.0.3")
    opa_input = capture([PYTHON, "tools/build_opa_input.py"])
    run_opa(
        [
            "opa",
            "eval",
            "--fail-defined",
            "--format",
            "pretty",
            "--stdin-input",
            "--data",
            "policies/opa",
            "data.repo_hygiene.deny[_]",
        ],
        input_text=opa_input,
    )


def opa_plan() -> None:
    plan_dir = ROOT / ".tmp" / "opa-plan"
    plan_dir.mkdir(parents=True, exist_ok=True)
    plan_path = "../.tmp/opa-plan/framework-plan.tfplan"

    run(
        [
            "terraform",
            "-chdir=terraform",
            "init",
            "-backend=false",
            "-input=false",
        ]
    )
    run(
        [
            "terraform",
            "-chdir=terraform",
            "plan",
            "-input=false",
            "-out",
            plan_path,
            "-var-file=../examples/multi-environment/terraform.tfvars.example",
        ]
    )
    plan_json = capture(["terraform", "-chdir=terraform", "show", "-json", plan_path])
    opa_input = capture([PYTHON, "tools/build_plan_input.py"], input_text=plan_json)
    run_opa(
        [
            "opa",
            "eval",
            "--fail-defined",
            "--format",
            "pretty",
            "--stdin-input",
            "--data",
            "policies/opa",
            "data.terraform_plan.deny[_]",
        ],
        input_text=opa_input,
    )


def terraform_test() -> None:
    (ROOT / "artifacts").mkdir(exist_ok=True)
    run(
        [
            "terraform",
            "-chdir=terraform",
            "test",
            "-junit-xml=../artifacts/terraform-test.xml",
        ]
    )


def lockfile_check() -> None:
    lockfile = ROOT / "terraform" / ".terraform.lock.hcl"
    if not lockfile.is_file():
        raise SystemExit(
            "missing terraform/.terraform.lock.hcl; "
            "run 'terraform -chdir=terraform init' and commit the result"
        )
    print(f"lockfile present: {lockfile.relative_to(ROOT).as_posix()}")


def workflow_bom_check() -> None:
    offenders = []
    workflow_dir = ROOT / ".github" / "workflows"
    for path in sorted(workflow_dir.glob("*.y*ml")):
        if path.read_bytes().startswith(b"\xef\xbb\xbf"):
            offenders.append(path.relative_to(ROOT).as_posix())

    if offenders:
        formatted = ", ".join(offenders)
        raise SystemExit(f"workflow YAML files must not start with a UTF-8 BOM: {formatted}")

    print("workflow BOM check passed")


def build_steps(case: str) -> dict[str, Step]:
    shell_helpers = sorted(
        path.relative_to(ROOT).as_posix() for path in (ROOT / "tools" / "ci").glob("*.sh")
    )
    install_helper = ROOT / "tools" / "install_ci_tools.sh"
    if install_helper.is_file():
        shell_helpers.append(install_helper.relative_to(ROOT).as_posix())
    bats_tests = sorted(
        path.relative_to(ROOT).as_posix() for path in (ROOT / "tests" / "ci").glob("*.bats")
    )

    def tflint() -> None:
        run(["tflint", "--init", "--config", str(ROOT / ".tflint.hcl")])
        run(["tflint", "--config", str(ROOT / ".tflint.hcl"), "--chdir", "terraform"])

    def ruff() -> None:
        install("ruff==0.13.0")
        run([PYTHON, "-m", "ruff", "check", "tools/"])

    def yamllint() -> None:
        install("yamllint==1.35.1")
        run([PYTHON, "-m", "yamllint", "-d", YAMLLINT_CONFIG, ".github/workflows/"])

    def workflow_helper_tests() -> None:
        run([*command_from_env("SHELLCHECK", "shellcheck"), *shell_helpers])
        run([PYTHON, "tools/ci/check_workflow_run_inputs.py", ".github/workflows"])
        run([*command_from_env("BATS", "bats"), *bats_tests])

    def privileged_workflows() -> None:
        install("pyyaml==6.0.3")
        run([PYTHON, "tools/check_privileged_workflows.py", "--repo-root", "."])
        run([PYTHON, "tools/run_privileged_workflow_tests.py"])

    return {
        "fmt": lambda: run(["terraform", "-chdir=terraform", "fmt", "-recursive"]),
        "fmt-check": lambda: run(
            ["terraform", "-chdir=terraform", "fmt", "-check", "-recursive"]
        ),
        "init": lambda: run(
            [
                "terraform",
                "-chdir=terraform",
                "init",
                "-backend=false",
                "-input=false",
            ]
        ),
        "validate": lambda: run(["terraform", "-chdir=terraform", "validate"]),
        "tflint": tflint,
        "ruff": ruff,
        "yamllint": yamllint,
        "actionlint": lambda: run([*command_from_env("ACTIONLINT", "actionlint")]),
        "markdownlint": lambda: run(
            [*command_from_env("MARKDOWNLINT", "markdownlint-cli2"), "**/*.md"]
        ),
        "test": terraform_test,
        "workflow-helper-tests": workflow_helper_tests,
        "workflow-bom-check": workflow_bom_check,
        "privileged-workflows": privileged_workflows,
        "opa-test": lambda: run_opa(["opa", "test", "policies/opa"]),
        "opa-policy": opa_policy,
        "opa-plan": opa_plan,
        "manifest-check": lambda: run(
            [PYTHON, "tools/check_baseline_manifest.py"]
        ),
        "lockfile-check": lockfile_check,
        "docs": lambda: run(["terraform-docs", "--config", ".terraform-docs.yml", "terraform"]),
        "docs-diff": lambda: run(
            [
                "terraform-docs",
                "--config",
                ".terraform-docs.yml",
                "--output-check",
                "terraform",
            ]
        ),
        "docs-layout": lambda: run([PYTHON, "tools/check_docs_layout.py"]),
        "adr-schema": lambda: run([PYTHON, "tools/check_adr_schema.py"]),
        "integration": lambda: run(
            [PYTHON, "tools/ci/run_integration.py", "--case", case]
        ),
    }


TARGETS: dict[str, tuple[str, ...]] = {
    "lint": ("fmt-check", "init", "validate", "tflint", "ruff", "yamllint"),
    "policy": ("opa-test", "opa-policy", "opa-plan"),
    "docs-check": ("docs-diff", "docs-layout", "adr-schema"),
    "ci": (
        "lint",
        "actionlint",
        "workflow-bom-check",
        "test",
        "workflow-helper-tests",
        "privileged-workflows",
        "policy",
        "markdownlint",
        "docs-check",
        "manifest-check",
        "lockfile-check",
    ),
    "verify": ("ci", "integration"),
}


def execute(name: str, steps: dict[str, Step]) -> None:
    if name in TARGETS:
        for child in TARGETS[name]:
            execute(child, steps)
        return
    steps[name]()


def main() -> int:
    choices = sorted(set(TARGETS) | set(build_steps("basic")))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", nargs="?", default="verify", choices=choices)
    parser.add_argument("--case", default="basic", help="Integration case to run.")
    args = parser.parse_args()

    execute(args.target, build_steps(args.case))
    return 0


if __name__ == "__main__":
    sys.exit(main())
