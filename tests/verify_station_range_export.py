"""Read actual UI-exported CSV and independently check analytic sampled rows."""
from pathlib import Path
import csv
import json
import math
import sys
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")
report=json.loads((root/"station-range-analytic.json").read_text(encoding="utf-8"))
assert [r["station"] for r in report["rows"]]==[425.25,500,575.75]
for r in report["rows"]:
    s=r["station"]
    expected=143+.1*(s-400)-.0005*(s-400)**2
    assert abs(r["planned"]-expected)<1e-8
    assert abs(r["grade"]-(10-.1*(s-400)))<1e-8
    assert abs(r["left_edge"]-(expected-.2))<1e-8
    assert abs(r["right_edge"]-(expected-.4))<1e-8
    assert r["x"]==600+s and r["y"]==1000
    assert r["easting"]==1000600+s and r["northing"]==1999000
    assert abs(r["delta"]-(r["planned"]-r["ground"]))<1e-8
path=root/"station-range-ui.csv"
assert path.read_bytes().startswith(b"\xef\xbb\xbf")
with path.open(encoding="utf-8-sig",newline="") as f:
    reader=csv.DictReader(f)
    assert len(reader.fieldnames)==21
    rows=list(reader)
assert [float(r["station_m"]) for r in rows]==[125.25,400,800,975.75]
assert "range_start" in rows[0]["events"] and "range_end" in rows[-1]["events"]
for r in rows:
    sta=float(r["station_m"])
    assert float(r["local_east_m"])==600+sta and float(r["local_south_m"])==1000
    assert r["crs"]=="LOCAL" and r["easting_m"]==r["northing_m"]==r["radius_m"]==""
    assert r["ground_status"]=="ok"
    assert math.isclose(float(r["center_minus_ground_m"]),float(r["center_elevation_m"])-float(r["ground_elevation_m"]),abs_tol=1e-9)
    assert float(r["station_step_m"])==400
print("PASS STATION RANGE EXPORT: real UTF-8 BOM/21-column CSV, exact original stations/coordinates/events, local blanks and independent parabola/crossfall/grade checks")
