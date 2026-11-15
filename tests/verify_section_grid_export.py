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


def entities(doc,layer):return [e for e in doc.modelspace() if e.dxf.layer==layer]
def shapes(doc,layer):return [[tuple(v.dxf.location) for v in e.vertices] for e in entities(doc,layer)]
doc,meta=read("section-grid-analytic.dxf")
off,om=read("section-grid-off.dxf")
assert meta==om
assert len(entities(doc,"KROAD_SEC_GRID"))==60
assert not entities(off,"KROAD_SEC_GRID")
for layer in ["KROAD_SEC_GROUND","KROAD_SEC_DESIGN","KROAD_SEC_AXIS"]:assert shapes(doc,layer)==shapes(off,layer)
for m in meta:
    ox,oy=m["origin_x"],m["origin_y"]
    lines=[e for e in entities(doc,"KROAD_SEC_GRID") if all(ox-30-1e-8<=v.dxf.location.x<=ox+30+1e-8 and oy-1e-8<=v.dxf.location.y<=oy+10+1e-8 for v in e.vertices)]
    assert len(lines)==12
    vertical=[];horizontal=[]
    for e in lines:
        a,b=[v.dxf.location for v in e.vertices]
        assert a.z==b.z==0
        if a.x==b.x:
            vertical.append(round(a.x-ox,8));assert abs(b.y-a.y-10)<1e-8
        else:
            horizontal.append(round(a.y-oy,8));assert abs(b.x-a.x-60)<1e-8
    assert vertical==[-25,-20,-15,-10,-5,5,10,15,20,25] and horizontal==[5,10]
    labels=[e for e in entities(doc,"KROAD_SEC_GRID_TEXT") if abs(e.dxf.insert.x-(ox-40+.75))<1e-7 and oy-1e-8<=e.dxf.insert.y<=oy+10+1e-8]
    assert [e.dxf.text for e in labels]==["0.00","5.00","10.00"]
    for e in labels:assert abs(float(e.dxf.text)-(m["datum"]+e.dxf.insert.y-oy))<1e-8
negative,nm=read("section-grid-negative.dxf")
assert all(m["datum"]==-10 for m in nm)
assert {e.dxf.text for e in entities(negative,"KROAD_SEC_GRID_TEXT")}=={"-10.00","-5.00","0.00"}
dense,dm=read("section-grid-dense.dxf")
for m in dm:
    texts=[e for e in entities(dense,"KROAD_SEC_GRID_TEXT") if abs(e.dxf.insert.x-(m["origin_x"]-40+.75))<1e-7 and m["origin_y"]<=e.dxf.insert.y<=m["origin_y"]+10]
    ys=[e.dxf.insert.y for e in texts]
    assert all(b-a>=2.25 for a,b in zip(ys,ys[1:]))
coarse,cm=read("section-grid-coarse.dxf")
assert not entities(coarse,"KROAD_SEC_GRID") and len(entities(coarse,"KROAD_SEC_GRID_TEXT"))==5
_,combined=read("section-grid-combined.dxf")
assert [m["station"] for m in combined]==[10,12.25,90]
read("section-grid-ui.dxf")
print("PASS SECTION GRID EZDXF: zero audit errors/fixes, exact 1:1 grid coordinates/spacing, actual positive/negative elevation labels, dense label stride and unchanged original traces")
