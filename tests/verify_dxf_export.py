"""Read Godot DXF fixtures with ezdxf; run verify_dxf.gd first."""
from pathlib import Path
import math
import sys
import ezdxf

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")

def read(name):
    doc = ezdxf.readfile(root / name)
    audit = doc.audit()
    assert not audit.errors, audit.errors
    assert not audit.fixes, audit.fixes
    assert doc.dxfversion == "AC1009"
    lines = {entity.dxf.layer: entity for entity in doc.modelspace()}
    assert set(lines) == {"KROAD_CENTER", "KROAD_LEFT", "KROAD_RIGHT"}
    for entity in lines.values():
        assert entity.dxftype() == "POLYLINE" and entity.is_3d_polyline and not entity.is_closed
        assert len(entity.vertices) >= 2
        for vertex in entity.vertices:
            assert vertex.dxf.flags & 32
            assert all(math.isfinite(v) for v in vertex.dxf.location)
    return doc, {key: [tuple(v.dxf.location) for v in entity.vertices] for key, entity in lines.items()}

def close(actual, expected):
    assert len(actual) == len(expected)
    assert max(abs(a - b) for a, b in zip(actual, expected)) < 1e-7, (actual, expected)

_, local = read("dxf-local.dxf")
close(local["KROAD_CENTER"][0], (100, -200, 103))
close(local["KROAD_CENTER"][-1], (200, -200, 103))
close(local["KROAD_LEFT"][0], (100, -190, 102.8))
close(local["KROAD_RIGHT"][0], (100, -210, 102.6))
for a, b in zip(local["KROAD_CENTER"], local["KROAD_CENTER"][1:]):
    assert math.dist(a, b) <= 10.000001
_, projected = read("dxf-projected.dxf")
close(projected["KROAD_CENTER"][0], (1000100, 1999800, 103))
close(projected["KROAD_LEFT"][0], (1000100, 1999810, 102.8))
_, curve = read("dxf-curve.dxf")
indices = [i for i, p in enumerate(curve["KROAD_CENTER"]) if p[0] > 600.000001 and p[0] < 899.999999 and p[1] < -600.000001]
assert len(indices) > 10
for layer, radius in [("KROAD_CENTER", 300), ("KROAD_LEFT", 290), ("KROAD_RIGHT", 310)]:
    for i in indices:
        x, y, z = curve[layer][i]
        assert abs(math.hypot(x-600, y+600)-radius) < 1e-7
_, parabola = read("dxf-parabola.dxf")
mid = next(p for p in parabola["KROAD_CENTER"] if abs(p[0] - 600) < 1e-8)
close(mid, (600, -200, 148))
print("PASS EZDXF: zero audit errors/fixes, 3 open 3D layers, metre coordinates, north signs, design heights, spacing, analytic centre/offset circle radii")
