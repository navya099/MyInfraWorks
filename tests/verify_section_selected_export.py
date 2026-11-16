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

doc, meta = read("section-selected-single.dxf")
assert len(meta)==1 and meta[0]["station"]==37.25
assert "SECTION_STATION_MODE=EXPLICIT_ONLY" in (root/"section-selected-single.dxf").read_text()
for layer, expected in [("KROAD_SEC_GROUND", 0), ("KROAD_SEC_DESIGN", 2)]:
    traces=curves(doc,meta[0],layer)
    assert len(traces)==1
    assert abs(height_at(traces[0],meta[0],0)-expected)<1e-7
assert len([e for e in doc.modelspace() if e.dxf.layer=="KROAD_SEC_GRID"])==12
_, many=read("section-selected-many.dxf")
assert [m["station"] for m in many]==[12.25,50,87.75]
_, ends=read("section-selected-ends.dxf")
assert [m["station"] for m in ends]==[0,100]
_, ui=read("section-selected-ui.dxf")
assert len(ui)==1
print("PASS SECTION SELECTED EZDXF: audited R12 single/multiple/endpoints/UI files, explicit stations, analytic ground/design heights and grid")

sized, _ = read("section-text-height.dxf")
assert all(abs(e.dxf.height-1.5)<1e-9 for e in sized.modelspace().query("TEXT"))
print("PASS TEXT HEIGHT: all title, offset and elevation labels use requested height")

numbered, nm = read("section-numbered.dxf")
titles = [e.dxf.text for e in numbered.modelspace().query("TEXT") if e.dxf.text.startswith("SEC ")]
assert titles == ["SEC 001 | STA 12.250 | H:V 1:1", "SEC 002 | STA 50.000 | H:V 1:1", "SEC 003 | STA 87.750 | H:V 1:1"]
assert [m["station"] for m in nm] == [12.25,50,87.75]
print("PASS SECTION NUMBERS: sorted consecutive titles and original stations")

common, cm = read("section-common-datum.dxf")
assert len(cm)==2 and all(m["datum"]==-10 for m in cm)
for m in cm:
    ground = [e for e in common.modelspace().query("POLYLINE") if e.dxf.layer=="KROAD_SEC_GROUND" and abs(e.vertices[0].dxf.location.x-(m["origin_x"]-30))<1e-7 and abs(e.vertices[0].dxf.location.y-(m["origin_y"]+10))<1e-7]
    assert len(ground)==1
print("PASS COMMON DATUM: shared datum and correct ground elevation after layout translation")

for name, present, absent in [("section-ground-only.dxf","KROAD_SEC_GROUND","KROAD_SEC_DESIGN"),("section-design-only.dxf","KROAD_SEC_DESIGN","KROAD_SEC_GROUND")]:
    filtered, _ = read(name)
    assert any(e.dxf.layer==present for e in filtered.modelspace())
    assert not any(e.dxf.layer==absent for e in filtered.modelspace())
print("PASS TRACE SELECTION: only requested ground/design entities exported")

no_axes, _ = read("section-no-axes.dxf")
assert not any(e.dxf.layer=="KROAD_SEC_AXIS" for e in no_axes.modelspace())
for layer in ["KROAD_SEC_GROUND","KROAD_SEC_DESIGN","KROAD_SEC_GRID","KROAD_SEC_TEXT"]:
    assert any(e.dxf.layer==layer for e in no_axes.modelspace())
print("PASS AXIS SELECTION: axes omitted with traces, grid and annotations preserved")
