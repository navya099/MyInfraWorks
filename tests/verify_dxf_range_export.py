"""Independent CAD reader checks for clipped plan output."""
from pathlib import Path
import math
import sys
import ezdxf
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")
def read(name):
    doc=ezdxf.readfile(root/name)
    audit=doc.audit()
    assert not audit.errors and not audit.fixes,(name,audit.errors,audit.fixes)
    roads={e.dxf.layer:[tuple(v.dxf.location) for v in e.vertices] for e in doc.modelspace().query("POLYLINE") if e.dxf.layer in ["KROAD_CENTER","KROAD_LEFT","KROAD_RIGHT"]}
    texts=list(doc.modelspace().query("TEXT"))
    return doc,roads,texts

doc,roads,texts=read("dxf-range-local.dxf")
assert [e.dxf.text for e in texts]==["STA 125.250","STA 200.000","STA 400.000","STA 600.000","STA 800.000","STA 875.750"]
center=roads["KROAD_CENTER"]
assert abs(center[0][0]-225.25)<1e-8 and abs(center[-1][0]-975.75)<1e-8
assert all(225.25<=x<=975.75 and y==-200 for x,y,z in center)
for layer,dy,fall in [("KROAD_CENTER",0,0),("KROAD_LEFT",10,.2),("KROAD_RIGHT",-10,.4)]:
    for x,y,z in roads[layer]:
        assert abs(y-(-200+dy))<1e-8
        assert abs(z-(103+(x-100)*.1-fall))<1e-7
_,projected,pt=read("dxf-range-projected.dxf")
for layer in roads:
    for a,b in zip(roads[layer],projected[layer]):
        assert max(abs(v-w-d) for v,w,d in zip(b,a,[1e6,2e6,0]))<1e-7
_,full,_=read("dxf-range-full.dxf")
_,explicit,_=read("dxf-range-explicit-full.dxf")
assert full==explicit
_,curve,ct=read("dxf-range-curve.dxf")
points=curve["KROAD_CENTER"]
assert points[0]==(550,-900,103)
assert any(abs(x-600)<1e-8 and abs(y+900)<1e-8 for x,y,z in points) # exact tangent boundary STA 500
assert abs(points[-1][0]-(600+300*math.sin(.5)))<1e-7
assert abs(points[-1][1]+600+300*math.cos(.5))<1e-7
assert [e.dxf.text for e in ct]==["STA 450.000","STA 500.000","STA 600.000","STA 650.000"]
_,parabola,pt=read("dxf-range-parabola.dxf")
for x,y,z in parabola["KROAD_CENTER"]:
    sta=x-100
    assert 425<=sta<=575
    expected=143+.1*(sta-400)-.0005*(sta-400)**2
    assert abs(z-expected)<1e-7
_,subset,st=read("dxf-range-long-subset.dxf")
assert len(subset["KROAD_CENTER"])==101
assert subset["KROAD_CENTER"][0][0]==50000 and subset["KROAD_CENTER"][-1][0]==50100
assert st[0].dxf.text=="STA 50000.000"
read("dxf-range-ui.dxf")
print("PASS PLAN RANGE EZDXF: zero audit errors/fixes, exact range, original coordinates/stations, asymmetric crossfall, curve boundary, parabola and full-range compatibility")
