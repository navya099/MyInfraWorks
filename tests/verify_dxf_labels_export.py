"""Independent ezdxf audit and geometry checks for plan STA annotations."""
from pathlib import Path
import math
import sys
import ezdxf
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")
def read(name):
    doc=ezdxf.readfile(root/name)
    audit=doc.audit()
    assert not audit.errors and not audit.fixes,(audit.errors,audit.fixes)
    assert doc.dxfversion=="AC1009"
    ticks=[e for e in doc.modelspace().query("POLYLINE") if e.dxf.layer=="KROAD_STA_TICK"]
    texts=[e for e in doc.modelspace().query("TEXT") if e.dxf.layer=="KROAD_STA_TEXT"]
    assert len(ticks)==len(texts)
    low,high=doc.header["$EXTMIN"],doc.header["$EXTMAX"]
    for tick,text in zip(ticks,texts):
        assert len(tick.vertices)==2 and tick.is_3d_polyline and not tick.is_closed
        points=[tuple(v.dxf.location) for v in tick.vertices]
        assert abs(math.dist(*points)-30)<1e-7
        centre=tuple((a+b)/2 for a,b in zip(*points))
        assert abs(text.dxf.insert.z-centre[2])<1e-7
        assert abs(math.hypot(text.dxf.insert.x-centre[0],text.dxf.insert.y-centre[1])-(15+text.dxf.height))<1e-7
        assert -90<=text.dxf.rotation<=90
        r=math.radians(text.dxf.rotation)
        assert abs((points[1][0]-points[0][0])*math.cos(r)+(points[1][1]-points[0][1])*math.sin(r))<1e-7
        for p in points+[tuple(text.dxf.insert)]:
            assert all(math.isfinite(v) for v in p)
            assert all(low[i]-1e-7<=p[i]<=high[i]+1e-7 for i in range(3))
    return doc,ticks,texts

def centre(tick):
    a,b=[v.dxf.location for v in tick.vertices]
    return tuple((a[i]+b[i])/2 for i in range(3))

doc,ticks,texts=read("dxf-labels-east.dxf")
assert [t.dxf.text for t in texts]==["STA 0.000","STA 40.000","STA 80.000","STA 100.000"]
for tick,text,station in zip(ticks,texts,[0,40,80,100]):
    assert max(abs(a-b) for a,b in zip(centre(tick),(100+station,-200,103)))<1e-7
    assert text.dxf.rotation==0
projected,pticks,ptexts=read("dxf-labels-projected.dxf")
for a,b in zip(texts,ptexts):
    assert max(abs((b.dxf.insert[i]-a.dxf.insert[i])-d) for i,d in enumerate([1000000,2000000,0]))<1e-7
for a,b in zip(ticks,pticks):
    assert max(abs((centre(b)[i]-centre(a)[i])-d) for i,d in enumerate([1000000,2000000,0]))<1e-7

_,_,large=read("dxf-labels-large.dxf")
assert all(t.dxf.height==10 for t in large)

for name,rotation in [("west",0),("north",90),("south",-90)]:
    _,ticks,texts=read("dxf-labels-"+name+".dxf")
    assert all(abs(t.dxf.rotation-rotation)<1e-8 for t in texts)

_,ticks,texts=read("dxf-labels-curve.dxf")
i=next(i for i,t in enumerate(texts) if t.dxf.text=="STA 600.000")
x,y,z=centre(ticks[i])
assert abs(x-(600+300*math.sin(1/3)))<1e-7
assert abs(y+(600+300*math.cos(1/3)))<1e-7
assert abs(texts[i].dxf.rotation-math.degrees(1/3))<1e-7

_,ticks,texts=read("dxf-labels-parabola.dxf")
i=next(i for i,t in enumerate(texts) if t.dxf.text=="STA 500.000")
assert abs(centre(ticks[i])[2]-148)<1e-8 and abs(texts[i].dxf.insert.z-148)<1e-8
near,ticks,texts=read("dxf-labels-near-end.dxf")
assert len(ticks)==3
end=next(e for e in near.modelspace() if e.dxf.layer=="KROAD_CENTER").vertices[-1].dxf.location
assert max(abs(a-b) for a,b in zip(centre(ticks[-1]),end))<1e-7

off,_,_=read("dxf-labels-disabled.dxf")
assert {e.dxf.layer for e in off.modelspace()}=={"KROAD_CENTER","KROAD_LEFT","KROAD_RIGHT"}
for layer in ["KROAD_CENTER","KROAD_LEFT","KROAD_RIGHT"]:
    a=next(e for e in off.modelspace() if e.dxf.layer==layer)
    b=next(e for e in doc.modelspace() if e.dxf.layer==layer)
    assert [tuple(v.dxf.location) for v in a.vertices]==[tuple(v.dxf.location) for v in b.vertices]
read("dxf-labels-ui.dxf")
print("PASS STA LABEL EZDXF: zero audit errors/fixes, exact local/projected ticks, readable headings, curve tangents, actual parabola Z, extents, near-end dedup and unchanged road layers")
