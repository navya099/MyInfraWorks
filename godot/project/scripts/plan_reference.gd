extends RefCounted

static func build(design):
 var started=Time.get_ticks_usec()
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(design.pi_route,design.radii,design.spirals,design.pvi_stations,design.pvi_heights,design.pvi_lengths)
 if not info.ok:return info
 var points=PackedVector2Array()
 for point in alignment.polyline():points.append(Vector2(point.x,point.z))
 return {"ok":true,"points":points,"length":info.length,"ms":(Time.get_ticks_usec()-started)/1000.0}
