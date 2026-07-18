#!/usr/bin/env python3
"""GitHub Actions orchestration for the Brick Puzzle iOS build and tests."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


PROJECT = "BrickPuzzle.xcodeproj"
SCHEME = "BrickPuzzle"


def run(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, check=check, text=True)


def capture(*arguments: str) -> str:
    return subprocess.check_output(arguments, text=True)


def select_simulator() -> None:
    payload = json.loads(capture("xcrun", "simctl", "list", "devices", "available", "-j"))
    devices = [
        device
        for runtime_devices in payload["devices"].values()
        for device in runtime_devices
    ]
    iphone = next(
        (device for device in devices if device["name"].startswith("iPhone")),
        None,
    )
    if iphone is None:
        raise SystemExit("No available iPhone simulator was found")

    simulator_id = iphone["udid"]
    run("xcrun", "simctl", "boot", simulator_id, check=False)
    run("xcrun", "simctl", "bootstatus", simulator_id, "-b")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with Path(output_path).open("a", encoding="utf-8") as output:
            output.write(f"id={simulator_id}\n")
    else:
        print(simulator_id)


def xcode_arguments(simulator_id: str) -> list[str]:
    runner_temp = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
    return [
        "-project",
        PROJECT,
        "-scheme",
        SCHEME,
        "-destination",
        f"platform=iOS Simulator,id={simulator_id}",
        "-derivedDataPath",
        str(runner_temp / "BrickPuzzleDerivedData"),
    ]


def build_for_testing(simulator_id: str) -> None:
    run("xcodebuild", "build-for-testing", *xcode_arguments(simulator_id))


def run_unit_tests(simulator_id: str) -> None:
    runner_temp = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
    run(
        "xcodebuild",
        "test-without-building",
        *xcode_arguments(simulator_id),
        "-only-testing:BrickPuzzleTests",
        "-resultBundlePath",
        str(runner_temp / "BrickPuzzleTests.xcresult"),
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("select-simulator")
    for command in ("build-for-testing", "run-unit-tests"):
        command_parser = subparsers.add_parser(command)
        command_parser.add_argument("--simulator-id", required=True)
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    if arguments.command == "select-simulator":
        select_simulator()
    elif arguments.command == "build-for-testing":
        build_for_testing(arguments.simulator_id)
    elif arguments.command == "run-unit-tests":
        run_unit_tests(arguments.simulator_id)
    else:
        raise AssertionError(f"Unhandled command: {arguments.command}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
