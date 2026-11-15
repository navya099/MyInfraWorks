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


doc,meta=read("section-extra-analytic.dxf")
assert [m["station"] for m in meta]==[0,12.25,25,50,75,87.75,100]
for m in meta:
    ground=curves(doc,m,"KROAD_SEC_GROUND")
    design=curves(doc,m,"KROAD_SEC_DESIGN")
    assert len(ground)==len(design)==1
    assert abs(height_at(ground[0],m,0))<1e-8
    assert abs(height_at(design[0],m,0)-2)<1e-8
    assert abs(height_at(design[0],m,-10)-1.8)<1e-8
    assert abs(height_at(design[0],m,10)-1.6)<1e-8
labels=[e.dxf.text for e in doc.modelspace().query("TEXT") if e.dxf.text.startswith("STA ")]
assert labels==["STA %.3f | H:V 1:1" % m["station"] for m in meta]
_,subset=read("section-extra-range.dxf")
assert [m["station"] for m in subset]==[10,12.25,25,50,75,87.75,90]
_,near=read("section-extra-near.dxf")
assert len(near)==5 and near[0]["station"]==0 and near[-1]["station"]==100
assert near[1]["station"]==25.00000001
_,empty=read("section-extra-empty.dxf")
assert [m["station"] for m in empty]==[0,25,50,75,100]
_,ui=read("section-extra-ui.dxf")
assert len(ui)==5
assert abs(ui[1]["station"]-123.456)<1e-5 and ui[2]["station"]==500
print("PASS EXTRA SECTION EZDXF: zero audit errors/fixes, exact sorted STA/range, duplicate priorities, labels, metre 1:1 geometry, crossfall and UI-added current station")
