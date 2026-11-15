"""Independent ezdxf checks for Godot profile-layout fixtures."""
from pathlib import Path
import json
import math
import sys
import ezdxf
root = Path(sys.argv[1]) if len(sys.argv)>1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")
def read(name):
    path=root/name
    raw=path.read_text(encoding="ascii").splitlines()
    meta=next(json.loads(raw[i+1][13:]) for i in range(0,len(raw),2) if raw[i].strip()=="999" and raw[i+1].startswith("PROFILE_META "))
    doc=ezdxf.readfile(path)
    audit=doc.audit()
    assert not audit.errors and not audit.fixes,(audit.errors,audit.fixes)
    assert doc.dxfversion=="AC1009"
    layers={layer.dxf.name for layer in doc.layers}
    assert {"KROAD_PROF_GROUND","KROAD_PROF_DESIGN","KROAD_PROF_AXIS","KROAD_PROF_TEXT"} <= layers
    for entity in doc.modelspace():
        if entity.dxftype()=="POLYLINE":
            assert entity.is_3d_polyline and not entity.is_closed and len(entity.vertices)>=2
            assert all(all(math.isfinite(v) for v in p.dxf.location) and p.dxf.location.z==0 for p in entity.vertices)
        elif entity.dxftype() in {"TEXT","POINT"}:
            p=entity.dxf.insert if entity.dxftype()=="TEXT" else entity.dxf.location
            assert all(math.isfinite(v) for v in p) and p.z==0
        else:raise AssertionError(entity.dxftype())
    return doc,meta

def lines(doc,layer):
    return [[tuple(v.dxf.location) for v in entity.vertices] for entity in doc.modelspace().query("POLYLINE") if entity.dxf.layer==layer]

def elevation(points,meta,station):
    y=next(p[1] for p in points if abs(p[0]+meta["start"]-station)<1e-7)
    return y/meta["vertical_factor"]+meta["datum"]

doc,meta=read("profile-dxf-parabola.dxf")
planned=lines(doc,"KROAD_PROF_DESIGN")[0]
assert meta["start"]==200 and meta["end"]==1000 and meta["vertical_factor"]==10
assert planned[0][0]==0 and planned[-1][0]==800
assert abs(elevation(planned,meta,400)-47)<1e-8
assert abs(elevation(planned,meta,600)-57)<1e-8 # curve crown, not control height 67
assert abs(elevation(planned,meta,800)-47)<1e-8
assert all(p[1]==0 for p in lines(doc,"KROAD_PROF_GROUND")[0])
assert any("VERTICAL FACTOR 10.000" in e.dxf.text for e in doc.modelspace().query("TEXT"))

doc,meta=read("profile-dxf-equal.dxf")
planned=lines(doc,"KROAD_PROF_DESIGN")[0]
assert meta["vertical_factor"]==1 and planned[0][0]==0 and planned[-1][0]==1000
assert abs(elevation(planned,meta,600)-57)<1e-8
assert all(b[0]-a[0]<=300.000001 for a,b in zip(planned,planned[1:]))

doc,meta=read("profile-dxf-gap.dxf")
assert len(lines(doc,"KROAD_PROF_GROUND"))==2
assert len(lines(doc,"KROAD_PROF_DESIGN"))==1
for run in lines(doc,"KROAD_PROF_GROUND"):
    stations=[p[0]+meta["start"] for p in run]
    assert max(stations)<600 or min(stations)>600
assert abs(elevation(lines(doc,"KROAD_PROF_DESIGN")[0],meta,600)-57)<1e-8

doc,meta=read("profile-dxf-no-ground.dxf")
assert not lines(doc,"KROAD_PROF_GROUND") and len(lines(doc,"KROAD_PROF_DESIGN"))==1
assert abs(elevation(lines(doc,"KROAD_PROF_DESIGN")[0],meta,600)-57)<1e-8

doc,meta=read("profile-dxf-asymmetric.dxf")
planned=lines(doc,"KROAD_PROF_DESIGN")[0]
assert abs(elevation(planned,meta,400+400/3)-30.3333333333333)<1e-8

doc,meta=read("profile-dxf-negative.dxf")
assert meta["datum"]==-20 and meta["vertical_factor"]==5
planned=lines(doc,"KROAD_PROF_DESIGN")[0]
assert abs(elevation(planned,meta,0)+20)<1e-8
assert abs(elevation(planned,meta,600)+11.6666666666667)<1e-8
assert all(abs(p[1]-100)<1e-8 for p in lines(doc,"KROAD_PROF_GROUND")[0])
read("profile-dxf-ui.dxf")
print("PASS PROFILE EZDXF: zero audit errors/fixes, range-origin coordinates, native parabola/offset, x1/x10 factors, captions, negative datum and ground-only gaps")
