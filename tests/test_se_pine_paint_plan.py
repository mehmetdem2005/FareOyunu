"""Plan-only contract tests. No terrain generation or texture downloads."""
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "docs/production/PINE_SE_PAINT_PLAN.json"
SCHEMA = ROOT / "docs/production/PINE_SE_PAINT_PLAN.schema.json"
SOURCE = ROOT / "data/terrain/sources.json"

class PineSEPlanContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = json.loads(PLAN.read_text(encoding="utf-8"))
        cls.s = json.loads(SCHEMA.read_text(encoding="utf-8"))
        cls.source = json.loads(SOURCE.read_text(encoding="utf-8"))
    def test_required_top_level_keys_and_schema_version(self):
        self.assertEqual(self.s["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(self.p["schema_version"], "1.0.0")
        self.assertTrue(set(self.s["required"]) <= set(self.p))
        self.assertEqual(set(self.p), set(self.s["properties"]))
    def test_se_is_only_target_and_original_source_is_immutable(self):
        t = self.p["target"]
        self.assertEqual(t["island_id"], "island_se_01")
        self.assertEqual(t["allowed_island_ids"], ["island_se_01"])
        self.assertEqual(set(t["unchanged_island_ids"]), {"island_nw_01","island_sw_01","island_north_01"})
        se = next(a for a in self.source["assets"] if a["id"] == "island_se_01")
        self.assertEqual(t["source"]["path"], se["source"])
        self.assertEqual(t["source"]["original_sha256"], se["sha256"])
        self.assertEqual(t["source"]["original_codec"], se["upload_format"])
        self.assertEqual(t["source"]["dimensions"], se["dimensions"])
        self.assertIn("NEVER", t["source"]["rule"])
    def test_18_materials_unique_polyhaven_1k_and_six_core(self):
        mats = self.p["maps"]["materials"]
        self.assertEqual(len(mats), 18)
        self.assertEqual(len({m["id"] for m in mats}), 18)
        self.assertEqual(sum(m["tier"]=="core" for m in mats), 6)
        self.assertEqual(self.p["restrictions"]["material_resolution_px"], 1024)
        self.assertTrue(self.p["restrictions"]["forbid_2k"])
        for m in mats:
            self.assertEqual(m["resolution"], "1k_only")
            self.assertTrue(m["source_url"].startswith("https://polyhaven.com/a/"))
            self.assertEqual(m["metallic"], 0)
            self.assertIn("nor_gl",m["mandatory_maps"])
            self.assertFalse(m["downloaded"])
    def test_zones_cover_all_materials_and_masks_preserve_source(self):
        zones = self.p["zones"]
        self.assertEqual({z["id"] for z in zones}, {f"Z{i}" for i in range(1,8)})
        matids = {m["id"] for m in self.p["maps"]["materials"]}
        used = {id for z in zones for id in z["materials"]}
        self.assertEqual(matids,used)
        self.assertTrue(self.p["masks"]["source_immutable"])
        self.assertEqual(self.p["masks"]["derived_max_size_px"],1024)
        self.assertGreaterEqual(len(self.p["masks"]["sequence"]), 10)
    def test_part0_steps_rounds_and_review_png(self):
        tasks = self.p["part0_tasks"]
        self.assertEqual({t["id"] for t in tasks}, {f"P0-{i:02}" for i in range(1,13)})
        self.assertTrue(all(t["status"]=="not_started" for t in tasks))
        phases = self.p["phases"]
        self.assertEqual([p["id"] for p in phases], [f"part_0{i}" for i in range(6)])
        self.assertTrue(all(p["user_approval_gate"] and p["do_not_auto_advance"] for p in phases))
        self.assertTrue(self.p["render"]["engine_output_only"])
        self.assertEqual(self.p["render"]["format"], "PNG")
        self.assertEqual(self.p["render"]["island_id"],"island_se_01")
        self.assertEqual(self.p["render"]["resolution_px"],[1536,1536])
        self.assertTrue(self.p["restrictions"]["plan_only_no_download_or_paint"])
    def test_gates_and_blockers_not_silently_marked_done(self):
        self.assertEqual(self.p["status"], "planning_only")
        self.assertGreaterEqual(len(self.p["quality_gates"]),11)
        self.assertGreaterEqual(len(self.p["blockers"]),5)
        self.assertIn("Godot", self.p["render"]["prohibited"])
if __name__ == "__main__":
    unittest.main()
