extends RefCounted

var core = ClassDB.instantiate("KRoadCore")
var terrain = {}
var route = PackedVector3Array()
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

func set_terrain(t):
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
 terrain = t.duplicate()
 terrain.Nx = nx
 terrain.Ny = ny
 terrain.Dx = float(t.Dx)
 terrain.Dy = float(t.Dy)
 terrain.Heights = heights
 terrain.Min = low
 terrain.Max = high
 route = PackedVector3Array()
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
 return core.sample_height(terrain, x, y)

func design(x, y):
 return core.design_height(terrain, route, x, y, road_width, offset, slope)

func length():
 var total = 0.0
 for i in range(1, route.size()):
  total += Vector2(route[i].x-route[i-1].x, route[i].z-route[i-1].z).length()
 return total

func sample(distance):
 for i in range(1, route.size()):
  var a = route[i-1]
  var b = route[i]
  var direction = Vector2(b.x-a.x,b.z-a.z)
  var segment = direction.length()
  if segment < 0.001:
   continue
  if distance <= segment or i == route.size()-1:
   var f = clamp(distance/segment,0.0,1.0)
   return {"point":a.lerp(b,f), "normal":Vector2(-direction.y,direction.x)/segment}
  distance -= segment
 return {"point":Vector3.ZERO,"normal":Vector2.UP}

func world(point):
 var size = extent()
 return Vector3(point.x-size.x/2.0,point.y-terrain.Min,point.z-size.y/2.0)

func snapshot():
 # Packed arrays use copy-on-write. Main thread replaces route, never mutates worker data.
 return {"terrain":terrain.duplicate(),"route":route.duplicate(),"width":road_width,"offset":offset,"slope":slope}

static func affected(snapshot_data, tile_size):
 var t = snapshot_data.terrain
 var r = snapshot_data.route
 var result = {}
 var nx = ceili(float(t.Nx-1)/tile_size)
 var ny = ceili(float(t.Ny-1)/tile_size)
 for i in range(1,r.size()):
  var a = r[i-1]
  var b = r[i]
  var low = min(a.y,b.y)+snapshot_data.offset
  var high = max(a.y,b.y)+snapshot_data.offset
  var delta = max(abs(low-t.Max),abs(high-t.Min))
  var margin = snapshot_data.width/2.0 + delta*snapshot_data.slope + max(t.Dx,t.Dy)*2
  var x0 = clampi(floori((min(a.x,b.x)-margin)/(t.Dx*tile_size)),0,nx-1)
  var x1 = clampi(floori((max(a.x,b.x)+margin)/(t.Dx*tile_size)),0,nx-1)
  var y0 = clampi(floori((min(a.z,b.z)-margin)/(t.Dy*tile_size)),0,ny-1)
  var y1 = clampi(floori((max(a.z,b.z)+margin)/(t.Dy*tile_size)),0,ny-1)
  for y in range(y0,y1+1):
   for x in range(x0,x1+1):
    result[Vector2i(x,y)] = true
 return result
