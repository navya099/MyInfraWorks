"""Read independent Godot section DXF fixtures with ezdxf."""
from pathlib import Path
import json
import math
import sys
import ezdxf

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")

def read(name):
    path = root / name
    raw = path.read_text(encoding="ascii").splitlines()
    assert len(raw) % 2 == 0
    metadata = [json.loads(raw[i+1][13:]) for i in range(0, len(raw), 2) if raw[i].strip() == "999" and raw[i+1].startswith("SECTION_META ")]
    doc = ezdxf.readfile(path)
    audit = doc.audit()
    assert not audit.errors, audit.errors
    assert not audit.fixes, audit.fixes
    assert doc.dxfversion == "AC1009"
    assert {"KROAD_SEC_GROUND", "KROAD_SEC_DESIGN", "KROAD_SEC_AXIS", "KROAD_SEC_TEXT"}.issubset({layer.dxf.name for layer in doc.layers})
    for entity in doc.modelspace():
        if entity.dxftype() == "POLYLINE":
            assert entity.is_3d_polyline and not entity.is_closed and len(entity.vertices) >= 2
            for vertex in entity.vertices:
                assert vertex.dxf.flags & 32
                assert all(math.isfinite(v) for v in vertex.dxf.location)
                assert vertex.dxf.location.z == 0
        elif entity.dxftype() in {"TEXT", "POINT"}:
            point = entity.dxf.insert if entity.dxftype() == "TEXT" else entity.dxf.location
            assert all(math.isfinite(v) for v in point) and point.z == 0
        else:
            raise AssertionError(entity.dxftype())
    return doc, metadata

def curves(doc, meta, layer):
    found = []
    for entity in doc.modelspace().query("POLYLINE"):
        if entity.dxf.layer != layer:
            continue
        points = [tuple(v.dxf.location) for v in entity.vertices]
        if all(meta["origin_x"]-30-1e-7 <= x <= meta["origin_x"]+30+1e-7 and meta["origin_y"]-1e-7 <= y <= meta["origin_y"]+10+1e-7 for x,y,z in points):
            found.append(points)
    return found

def height_at(points, meta, offset):
    return next(y-meta["origin_y"]+meta["datum"] for x,y,z in points if abs(x-meta["origin_x"]-offset) < 1e-7)

doc, meta = read("section-dxf-analytic.dxf")
assert [m["station"] for m in meta] == [0,25,50,75,100]
assert [m["origin_x"] for m in meta] == [40,120,200,40,120]
assert meta[3]["origin_y"] < meta[0]["origin_y"]
for m in meta:
    ground = curves(doc,m,"KROAD_SEC_GROUND")
    design = curves(doc,m,"KROAD_SEC_DESIGN")
    assert len(ground) == len(design) == 1
    assert abs(height_at(ground[0],m,0)) < 1e-8
    assert abs(height_at(design[0],m,0)-2) < 1e-8
    assert abs(height_at(design[0],m,-10)-1.8) < 1e-8
    assert abs(height_at(design[0],m,10)-1.6) < 1e-8
    assert abs((height_at(design[0],m,0)-height_at(design[0],m,-10))/10-0.02) < 1e-9
    assert abs((height_at(design[0],m,0)-height_at(design[0],m,10))/10-0.04) < 1e-9
assert len(doc.modelspace().query("TEXT")) == 7 * len(meta)

doc, meta = read("section-dxf-gap.dxf")
for m in meta:
    for layer in ["KROAD_SEC_GROUND", "KROAD_SEC_DESIGN"]:
        runs = curves(doc,m,layer)
        assert len(runs) == 2
        for points in runs:
            offsets = [p[0]-m["origin_x"] for p in points]
            assert max(offsets) <= -2+1e-7 or min(offsets) >= 1-1e-7

doc, meta = read("section-dxf-empty.dxf")
assert all(e.dxf.layer not in {"KROAD_SEC_GROUND", "KROAD_SEC_DESIGN"} for e in doc.modelspace())
assert len(meta) == 5

doc, meta = read("section-dxf-point.dxf")
points = list(doc.modelspace().query("POINT"))
assert len(points) == 2 and {p.dxf.layer for p in points} == {"KROAD_SEC_GROUND", "KROAD_SEC_DESIGN"}
assert all(abs(p.dxf.location.x-meta[2]["origin_x"]-5) < 1e-8 for p in points)

doc, meta = read("section-dxf-cut.dxf")
assert [m["station"] for m in meta] == [0,40,80,100]
for m in meta:
    assert m["datum"] == -10
    design = curves(doc,m,"KROAD_SEC_DESIGN")[0]
    assert abs(height_at(design,m,0)+2) < 1e-8
    assert abs(height_at(design,m,11)+0.4) < 1e-8
read("section-dxf-ui.dxf")
print("PASS SECTION EZDXF: zero audit errors/fixes, separate layers, planar metre layout/1:1 slopes, labels/datums, remainder, NaN gaps, empty traces and isolated POINT preservation")
