from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "ios_ci.py"
SPEC = importlib.util.spec_from_file_location("ios_ci", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
ios_ci = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ios_ci)


class IOSCITests(unittest.TestCase):
    def test_xcode_arguments_use_selected_simulator_and_runner_temp(self) -> None:
        with mock.patch.dict(os.environ, {"RUNNER_TEMP": "/tmp/brick-puzzle-ci"}):
            arguments = ios_ci.xcode_arguments("SIMULATOR-ID")

        self.assertIn("platform=iOS Simulator,id=SIMULATOR-ID", arguments)
        self.assertEqual(arguments[-2:], ["-derivedDataPath", "/tmp/brick-puzzle-ci/BrickPuzzleDerivedData"])

    def test_select_simulator_boots_first_available_iphone_and_exports_id(self) -> None:
        devices = {
            "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                    {"name": "iPad", "udid": "IPAD-ID"},
                    {"name": "iPhone 17", "udid": "IPHONE-ID"},
                ]
            }
        }
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_path = Path(temporary_directory) / "github-output"
            with (
                mock.patch.object(ios_ci, "capture", return_value=json.dumps(devices)),
                mock.patch.object(ios_ci, "run") as run,
                mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(output_path)}),
            ):
                ios_ci.select_simulator()

            self.assertEqual(output_path.read_text(encoding="utf-8"), "id=IPHONE-ID\n")
            run.assert_has_calls([
                mock.call("xcrun", "simctl", "boot", "IPHONE-ID", check=False),
                mock.call("xcrun", "simctl", "bootstatus", "IPHONE-ID", "-b"),
            ])

    def test_unit_tests_use_unit_target_and_result_bundle(self) -> None:
        with mock.patch.object(ios_ci, "run_tests") as run_tests:
            ios_ci.run_unit_tests("SIMULATOR-ID")

        run_tests.assert_called_once_with(
            "SIMULATOR-ID",
            "BrickPuzzleTests",
            "BrickPuzzleTests.xcresult",
        )

    def test_test_command_uses_target_and_runner_temp_result_bundle(self) -> None:
        with (
            mock.patch.object(ios_ci, "run") as run,
            mock.patch.dict(os.environ, {"RUNNER_TEMP": "/tmp/brick-puzzle-ci"}),
        ):
            ios_ci.run_tests("SIMULATOR-ID", "ExampleTests", "ExampleTests.xcresult")

        run.assert_called_once_with(
            "xcodebuild",
            "test-without-building",
            "-project",
            "BrickPuzzle.xcodeproj",
            "-scheme",
            "BrickPuzzle",
            "-destination",
            "platform=iOS Simulator,id=SIMULATOR-ID",
            "-derivedDataPath",
            "/tmp/brick-puzzle-ci/BrickPuzzleDerivedData",
            "-only-testing:ExampleTests",
            "-resultBundlePath",
            "/tmp/brick-puzzle-ci/ExampleTests.xcresult",
        )

    def test_ui_tests_use_ui_target_and_separate_result_bundle(self) -> None:
        with mock.patch.object(ios_ci, "run_tests") as run_tests:
            ios_ci.run_ui_tests("SIMULATOR-ID")

        run_tests.assert_called_once_with(
            "SIMULATOR-ID",
            "BrickPuzzleUITests",
            "BrickPuzzleUITests.xcresult",
        )


if __name__ == "__main__":
    unittest.main()
