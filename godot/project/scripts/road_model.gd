extends RefCounted

var core = ClassDB.instantiate("KRoadCore")
var terrain = {}
var source = {}
var route = PackedVector3Array()
var radii = PackedFloat64Array()
var spirals = PackedFloat64Array()
var vertical_lengths = PackedFloat64Array()
var alignment = ClassDB.instantiate("KRoadAlignment")
var alignment_data = {"length":0.0,"pi_stations":PackedFloat64Array(),"elements":[]}
var centerline = PackedVector3Array()
var road_width = 20.0
var offset = 0.0
var slope = 1.5
var station = 0.5
var texture: ImageTexture

func demo():
 var values = PackedFloat64Array()
 for y in range(161):
  for x in range(161):
   values.append(170.0 + 75.0 * sin(x * 0.035) * cos(y * 0.0275) + y * 0.3)
 set_terrain({"Nx":161,"Ny":161,"Dx":30.0,"Dy":30.0,"Heights":values,"Name":"합성 데모 지형 · 실측 아님"})

func set_terrain(t, detail={}):
 if not t is Dictionary:
  return "지형 데이터는 Dictionary여야 합니다."
 if not t.get("Heights",[]) is Array and not t.get("Heights",[]) is PackedFloat64Array:
  return "높이 배열 형식이 올바르지 않습니다."
 var nx = int(t.get("Nx", 0))
 var ny = int(t.get("Ny", 0))
 if nx < 2 or ny < 2 or nx > 2049 or ny > 2049 or float(t.get("Dx", 0)) <= 0 or float(t.get("Dy", 0)) <= 0:
  return "유효하지 않은 지형 크기/간격"
 if t.get("Heights", []).size() != nx * ny:
  return "높이 배열 크기가 일치하지 않습니다."
 var heights = PackedFloat64Array()
 var low = INF
 var high = -INF
 for value in t.Heights:
  if value!=null and typeof(value)!=TYPE_FLOAT and typeof(value)!=TYPE_INT:
   return "높이 값은 숫자 또는 NoData여야 합니다."
  var h = NAN if value == null else float(value)
  heights.append(h)
  if is_finite(h):
   low = min(low, h)
   high = max(high, h)
 if not is_finite(low):
  return "유효한 지형 높이가 없습니다."
 if not detail is Dictionary:
  return "계산용 지형 형식이 올바르지 않습니다."
 if detail.is_empty():
  detail=t.get("Source",{})
 if not detail is Dictionary:
  return "계산용 지형 형식이 올바르지 않습니다."
 if not detail.is_empty():
  var stats=core.grid_stats(detail)
  if stats.is_empty():
   return "계산용 높이 배열이 유효하지 않습니다."
  var source_extent=Vector2((int(detail.Nx)-1)*float(detail.Dx),(int(detail.Ny)-1)*float(detail.Dy))
  var preview_extent=Vector2((nx-1)*float(t.Dx),(ny-1)*float(t.Dy))
  if t.has("OriginX") and detail.has("OriginX") and (abs(float(t.OriginX)-float(detail.OriginX))>0.001 or abs(float(t.get("OriginY",0))-float(detail.get("OriginY",0)))>0.001):
   return "계산용 지형과 화면용 지형의 원점이 다릅니다."
  if source_extent.distance_to(preview_extent)>0.01:
   return "계산용 지형과 화면용 지형의 범위가 다릅니다."
  detail=detail.duplicate()
  detail.Min=stats.Min
  detail.Max=stats.Max
  low=stats.Min
  high=stats.Max
 terrain = t.duplicate()
 terrain.erase("Source")
 terrain.erase("SourceFile")
 terrain.erase("SourceEncoding")
 terrain.Nx = nx
 terrain.Ny = ny
 terrain.Dx = float(t.Dx)
 terrain.Dy = float(t.Dy)
 terrain.Heights = heights
 terrain.Min = low
 terrain.Max = high
 source=detail if not detail.is_empty() else terrain.duplicate()
 route = PackedVector3Array()
 radii=PackedFloat64Array()
 spirals=PackedFloat64Array()
 vertical_lengths=PackedFloat64Array()
 rebuild_alignment()
 var image = Image.create(nx, ny, false, Image.FORMAT_RGBA8)
 var span = max(1.0, high - low)
 for y in range(ny):
  for x in range(nx):
   var h = heights[y * nx + x]
   var f = (h - low) / span
   image.set_pixel(x, y, Color(0.18+f*0.23,0.34+f*0.25,0.27+f*0.15) if is_finite(h) else Color(0.08,0.12,0.17))
 texture = ImageTexture.create_from_image(image)
 return ""

func extent():
 return Vector2((terrain.Nx-1)*terrain.Dx, (terrain.Ny-1)*terrain.Dy)

func ground(x, y):
 return core.sample_height(source, x, y)

func design(x, y):
 return core.design_height(source, centerline, x, y, road_width, offset, slope)

func rebuild_alignment():
 var count=route.size()
 var old_size=radii.size()
 radii.resize(count)
 spirals.resize(count)
 vertical_lengths.resize(count)
 for i in range(old_size,count):
  radii[i]=0
  spirals[i]=0
  vertical_lengths[i]=0
 if count>0:
  radii[0]=0
  spirals[0]=0
  vertical_lengths[0]=0
  radii[count-1]=0
  spirals[count-1]=0
  vertical_lengths[count-1]=0
 for radius in radii:
  if radius>0 and radius<=road_width/2:
   return "R must exceed half the road width to avoid an inverted inner edge"
 var result=alignment.configure(route,radii,spirals,vertical_lengths)
 if not result.ok:
  return result.error
 alignment_data=result
 centerline=alignment.polyline()
 core.prepare_corridor(centerline,road_width,offset,slope,terrain.get("Min",0),terrain.get("Max",0),max(terrain.get("Dx",1),terrain.get("Dy",1))*2)
 return ""

func restore(snapshot_data):
 route=snapshot_data.pi_route.duplicate()
 radii=snapshot_data.radii.duplicate()
 spirals=snapshot_data.spirals.duplicate()
 vertical_lengths=snapshot_data.vertical_lengths.duplicate()
 road_width=snapshot_data.width
 offset=snapshot_data.offset
 slope=snapshot_data.slope
 rebuild_alignment()

func length():
 return float(alignment_data.length)

func pi_station(index):
 return alignment_data.pi_stations[index] if index>=0 and index<alignment_data.pi_stations.size() else 0.0

func sample(distance):
 return alignment.sample(distance)

func world(point):
 var size = extent()
 return Vector3(point.x-size.x/2.0,point.y-terrain.Min,point.z-size.y/2.0)

func snapshot():
 # Packed arrays use copy-on-write. Main thread replaces route, never mutates worker data.
 return {"source":source.duplicate(),"terrain":terrain.duplicate(),"pi_route":route.duplicate(),"radii":radii.duplicate(),"spirals":spirals.duplicate(),"vertical_lengths":vertical_lengths.duplicate(),"route":centerline.duplicate(),"width":road_width,"offset":offset,"slope":slope,"refinement":refinement()}

func refinement():
 var desired=max(5.0,max(min(source.Dx,source.Dy)/2.0,road_width/3.0))
 return clampi(ceili(max(terrain.Dx,terrain.Dy)/desired),2,16)

static func affected(snapshot_data, tile_size):
 var result={}
 var engine=ClassDB.instantiate("KRoadCore")
 for point in engine.affected_tiles(snapshot_data.terrain,snapshot_data.route,snapshot_data.width,snapshot_data.offset,snapshot_data.slope,tile_size):
  result[Vector2i(point)]=true
 return result

func edit_state():
 # History stores design parameters only, never DEM arrays or derived meshes.
 return {"pi_route":route.duplicate(),"radii":radii.duplicate(),"spirals":spirals.duplicate(),"vertical_lengths":vertical_lengths.duplicate(),"width":road_width,"offset":offset,"slope":slope}
