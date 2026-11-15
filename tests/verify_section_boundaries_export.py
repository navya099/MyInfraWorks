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


doc,meta=read("section-boundaries-parabola.dxf")
assert [m["station"] for m in meta]==[0,12.25,40,50,60,100]
for m in meta:
    sta=m["station"]
    if sta<40:expected=2+.04*sta
    elif sta<=60:expected=3.6+.04*(sta-40)-.002*(sta-40)**2
    else:expected=4-.04*(sta-50)
    design=curves(doc,m,"KROAD_SEC_DESIGN")
    assert len(design)==1
    assert abs(height_at(design[0],m,0)-expected)<1e-7
    assert abs(height_at(design[0],m,-10)-(expected-.2))<1e-7
    assert abs(height_at(design[0],m,10)-(expected-.4))<1e-7
_,subset=read("section-boundaries-range.dxf")
assert [m["station"] for m in subset]==[42.25,50,57.75]
_,merged=read("section-boundaries-merged.dxf")
assert [m["station"] for m in merged]==list(range(0,101,10))
_,off=read("section-boundaries-off.dxf")
assert [m["station"] for m in off]==[0,12.25,100]
_,circle=read("section-boundaries-circle.dxf")
expected=[0,500,500+300*math.pi/4,500+300*math.pi/2,1000+300*math.pi/2]
assert len(circle)==5
for m,s in zip(circle,expected):assert abs(m["station"]-s)<1e-7,(m,s)
_,spiral=read("section-boundaries-spiral.dxf")
assert len(spiral)==7 and all(a["station"]<b["station"] for a,b in zip(spiral,spiral[1:]))
assert abs((spiral[2]["station"]-spiral[1]["station"])-50)<1e-7
assert abs((spiral[-2]["station"]-spiral[-3]["station"])-50)<1e-7
_,ui=read("section-boundaries-ui.dxf")
assert [m["station"] for m in ui]==[0,123.456,1000,1200]
print("PASS SECTION BOUNDARIES EZDXF: zero audit errors/fixes, exact BVC/PVI/EVC/PI/circle/spiral stations, clipping/priority, actual parabola/crossfall and UI output")
