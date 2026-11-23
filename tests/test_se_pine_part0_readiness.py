"""Part0 readiness report invariants, entirely static; no materials or heightmaps created."""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def J(p): return json.loads((ROOT/p).read_text(encoding="utf-8"))
class TestPinePart0Readiness(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=J("docs/production/PINE_SE_PAINT_PLAN.json")
        cls.report=J("docs/production/PINE_SE_PART0_EXECUTION_REPORT.json")
        cls.catalog=J("data/biomes/pine_se/asset_inventory_part0.json")
        cls.cam=J("data/biomes/pine_se/render_profile_part0.json")
        cls.imp=J("data/biomes/pine_se/import_profile_part0.json")
        cls.sources=J("data/terrain/sources.json")
    def test_se_scope_and_source_hash(self):
        a=next(x for x in self.sources["assets"] if x["id"]=="island_se_01")
        self.assertEqual(self.report["source"]["se_original_jpeg_sha256"],a["sha256"])
        self.assertEqual(self.report["source"]["se_original_jpeg_sha256"],self.plan["target"]["source"]["original_sha256"])
        self.assertEqual(self.cam["scope"],"island_se_01_only")
        self.assertFalse(self.report["source"]["source_altered"])
        self.assertFalse(self.report["source"]["other_three_island_assets_altered"])
    def test_1k_only_vendor_and_no_false_download_claim(self):
        self.assertEqual(len(self.catalog["assets"]),18)
        self.assertEqual({a["id"] for a in self.catalog["assets"]},{a["id"] for a in self.plan["maps"]["materials"]})
        self.assertTrue(all(a["vendor_page_1k_option_visible"] for a in self.catalog["assets"]))
        self.assertTrue(all(not a["actual_1k_file_hash_verified"] for a in self.catalog["assets"]))
        self.assertTrue(all(not a["maps_downloaded"] for a in self.catalog["assets"]))
        self.assertEqual(self.report["materials"]["actual_file_hashes_verified"],0)
        self.assertEqual(self.imp["texture_source_resolution_px"],[1024,1024])
        self.assertTrue(self.imp["no_2k"])
    def test_correct_near_mouse_texel_warning(self):
        issues=[a["id"] for a in self.catalog["assets"] if a["mouse_closeup_risk"]=="critical_low_physical_texel_density"]
        self.assertEqual(set(issues),{"coast_sand_01","coast_sand_05"})
        self.assertEqual(self.plan["target"]["mouse_body_length_m"],0.10)
        self.assertEqual(self.report["physical_scale"]["world_units_to_metre"],"not_approved")
    def test_part0_status_counts_and_no_unverified_png(self):
        tasks=self.report["tasks"]
        self.assertEqual(len(tasks),12)
        self.assertEqual({x["id"] for x in tasks},{f"P0-{i:02}" for i in range(1,13)})
        tally={k:sum(x["status"]==k for x in tasks) for k in ["verified","partial","blocked"]}
        self.assertEqual(tally,self.report["tally"])
        self.assertFalse(self.report["engine"]["real_godot_capture_created"])
        self.assertEqual(self.report["renderer"]["capture_status"],"blocked_real_engine_unavailable")
        self.assertEqual(self.report["overall_status"],"blocked_not_ready_for_part1")
        self.assertIn("STOP",self.report["decision"])
    def test_no_imported_scene_mutations(self):
        self.assertEqual(self.imp["status"],"settings_proposal_not_import_tested")
        self.assertEqual(self.cam["status"],"specification_only_no_engine_capture")
        self.assertTrue(self.plan["restrictions"]["plan_only_no_download_or_paint"])
if __name__=="__main__": unittest.main()
