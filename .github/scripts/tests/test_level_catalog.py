from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "level_catalog.py"
SPEC = importlib.util.spec_from_file_location("level_catalog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
level_catalog = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = level_catalog
SPEC.loader.exec_module(level_catalog)


def valid_level(level_id: str = "prototype-001") -> dict:
    return {
        "id": level_id,
        "title": "Fixture Level",
        "columns": 3,
        "rows": 4,
        "bricks": [
            {"id": "mission", "row": 1, "column": 1, "kind": "mission", "hitPoints": 10}
        ],
        "availablePowerups": ["extraBalls"],
        "maxPowerupLoadoutSize": 1,
        "objective": {"kind": "clearMissionBricks", "orderedBrickIDs": ["mission"]},
        "starRules": {
            "twoStarShotLimit": 2,
            "threeStarRequiresNoPowerups": True,
            "threeStarShotLimit": 1,
        },
        "metadata": {
            "intendedSolution": "Hit the mission brick.",
            "minimumKnownShotCount": 1,
            "requiredMechanics": ["aiming", "missionObjective"],
            "difficulty": "tutorial",
            "validationStatus": "replayValidated",
        },
    }


def valid_replay(level_id: str = "prototype-001") -> dict:
    return {
        "levelID": level_id,
        "selectedPowerups": [],
        "shots": [
            {
                "aimAngleDegrees": 90,
                "usedPowerups": [],
                "destroyedBrickIDs": ["mission"],
            }
        ],
        "expectedOutcome": {"completed": True, "stars": 3},
    }


class CatalogFixture:
    def __enter__(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.levels = self.root / "Levels"
        self.replays = self.root / "Replays"
        self.levels.mkdir()
        self.replays.mkdir()
        return self

    def __exit__(self, exception_type, exception, traceback):
        self.temporary_directory.cleanup()

    def write_level(self, payload: dict, filename: str | None = None) -> None:
        path = self.levels / (filename or f"{payload['id']}.json")
        path.write_text(json.dumps(payload), encoding="utf-8")

    def write_replay(self, payload: dict, filename: str | None = None) -> None:
        path = self.replays / (filename or f"{payload['levelID']}-clean.json")
        path.write_text(json.dumps(payload), encoding="utf-8")


class LevelCatalogTests(unittest.TestCase):
    def test_valid_catalog_produces_deterministic_summary_and_report(self) -> None:
        with CatalogFixture() as fixture:
            fixture.write_level(valid_level())
            fixture.write_replay(valid_replay())

            summary = level_catalog.validate_catalog(fixture.levels, fixture.replays)

        self.assertEqual(len(summary.levels), 1)
        self.assertEqual(summary.difficulty_counts["tutorial"], 1)
        self.assertEqual(summary.mechanic_counts, {"aiming": 1, "missionObjective": 1})
        self.assertIn("| `prototype-001` | Fixture Level | Tutorial |", summary.as_markdown())
        self.assertEqual(json.loads(summary.as_json())["levelCount"], 1)

    def test_metadata_and_board_errors_are_actionable(self) -> None:
        level = valid_level()
        level["metadata"]["difficulty"] = "impossible"
        level["metadata"]["requiredMechanics"] = []
        level["bricks"][0]["row"] = 9
        with CatalogFixture() as fixture:
            fixture.write_level(level)
            fixture.write_replay(valid_replay())

            with self.assertRaises(level_catalog.CatalogValidationError) as context:
                level_catalog.validate_catalog(fixture.levels, fixture.replays)

        message = str(context.exception)
        self.assertIn("difficulty must be one of", message)
        self.assertIn("requiredMechanics must be a non-empty array", message)
        self.assertIn("row 9 is outside", message)

    def test_missing_and_orphan_replays_are_reported(self) -> None:
        with CatalogFixture() as fixture:
            fixture.write_level(valid_level())
            fixture.write_replay(valid_replay("prototype-002"))

            with self.assertRaises(level_catalog.CatalogValidationError) as context:
                level_catalog.validate_catalog(fixture.levels, fixture.replays)

        message = str(context.exception)
        self.assertIn("missing clean replays for prototype-001", message)
        self.assertIn("orphan clean replays for prototype-002", message)

    def test_clean_replay_contract_is_enforced(self) -> None:
        replay = valid_replay()
        replay["selectedPowerups"] = ["extraBalls"]
        replay["shots"][0]["usedPowerups"] = ["extraBalls"]
        replay["shots"][0]["destroyedBrickIDs"] = ["unknown"]
        replay["expectedOutcome"]["stars"] = 2
        with CatalogFixture() as fixture:
            fixture.write_level(valid_level())
            fixture.write_replay(replay)

            with self.assertRaises(level_catalog.CatalogValidationError) as context:
                level_catalog.validate_catalog(fixture.levels, fixture.replays)

        message = str(context.exception)
        self.assertIn("must expect three stars", message)
        self.assertIn("must not select powerups", message)
        self.assertIn("must not use powerups", message)
        self.assertIn("destroys unknown ids unknown", message)

    def test_replay_powerups_must_be_available_and_selected(self) -> None:
        level = valid_level()
        level["starRules"]["threeStarRequiresNoPowerups"] = False
        level["maxPowerupLoadoutSize"] = 2
        replay = valid_replay()
        replay["selectedPowerups"] = ["unknown"]
        replay["shots"][0]["usedPowerups"] = ["extraBalls"]
        with CatalogFixture() as fixture:
            fixture.write_level(level)
            fixture.write_replay(replay)

            with self.assertRaises(level_catalog.CatalogValidationError) as context:
                level_catalog.validate_catalog(fixture.levels, fixture.replays)

        message = str(context.exception)
        self.assertIn("selects unavailable powerups unknown", message)
        self.assertIn("uses unselected powerups extraBalls", message)

    def test_level_ids_must_be_contiguous(self) -> None:
        with CatalogFixture() as fixture:
            fixture.write_level(valid_level("prototype-002"))
            fixture.write_replay(valid_replay("prototype-002"))

            with self.assertRaises(level_catalog.CatalogValidationError) as context:
                level_catalog.validate_catalog(fixture.levels, fixture.replays)

        self.assertIn("contiguous sequence", str(context.exception))


if __name__ == "__main__":
    unittest.main()
