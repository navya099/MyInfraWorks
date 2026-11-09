extends Control
signal point_added(point)
signal elevation_changed(index, elevation)
var model
var mode = "plan"
var edit_index = -1
var frozen_bounds = Vector2.ZERO
const GREEN = Color("78c7a6")
const ORANGE = Color("ffbd69")
const MUTED = Color("8097a9")

func _ready():
 mouse_filter = Control.MOUSE_FILTER_STOP
 clip_contents = true
 resized.connect(queue_redraw)

func plot_rect():
 return Rect2(Vector2(48,20),Vector2(max(1,size.x-68),max(1,size.y-56)))

func map_rect():
 var available = size-Vector2(32,32)
 var ext = model.extent()
 var scale_factor = min(available.x/ext.x,available.y/ext.y)
 var dimensions = ext*max(0.000001,scale_factor)
 return Rect2((size-dimensions)/2.0,dimensions)

func chart_bounds():
 if edit_index >= 0:
  return frozen_bounds
 var low = model.terrain.Min
 var high = model.terrain.Max
 for v in model.route:
  low = min(low,v.y+model.offset)
  high = max(high,v.y+model.offset)
 var pad = max(10.0,(high-low)*0.15)
 return Vector2(low-pad,high+pad)

func label(text,position,color=MUTED):
 draw_string(ThemeDB.fallback_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)

func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color("13212c"))
 if model == null or model.terrain.is_empty():
  return
 if mode == "plan":
  var r = map_rect()
  draw_texture_rect(model.texture,r,false)
  var ext = model.extent()
  var points = PackedVector2Array()
  for i in range(model.route.size()):
   var v = model.route[i]
   var q = r.position+Vector2(v.x,v.z)/ext*r.size
   points.append(q)
   draw_circle(q,4,ORANGE)
   label(str(i+1),q+Vector2(6,-6),ORANGE)
  if points.size()>1:
   draw_polyline(points,ORANGE,2.5,true)
  label("N ↑  |  %.1f × %.1f km" % [ext.x/1000,ext.y/1000],Vector2(14,18))
  label("클릭: 노선 점 추가",Vector2(14,size.y-10))
  return
 if model.route.size()<2:
  label("평면에 노선 점을 두 개 이상 추가하세요.",Vector2(24,38))
  return
 var r = plot_rect()
 for i in range(5):
  var y = r.position.y+r.size.y*i/4
  draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("263946"))
 var length = model.length()
 var raw = PackedVector2Array()
 var planned = PackedVector2Array()
 if mode == "profile":
  var bounds = chart_bounds()
  var span = bounds.y-bounds.x
  var previous_valid = false
  var previous = Vector2.ZERO
  for i in range(241):
   var sample = model.sample(length*i/240.0).point
   var ground = model.ground(sample.x,sample.z)
   var x = r.position.x+r.size.x*i/240.0
   if is_finite(ground):
    var q = Vector2(x,r.end.y-(ground-bounds.x)/span*r.size.y)
    if previous_valid:
     draw_line(previous,q,GREEN,1.5,true)
    previous=q
    previous_valid=true
   else:
    previous_valid=false
   planned.append(Vector2(x,r.end.y-(sample.y+model.offset-bounds.x)/span*r.size.y))
  draw_polyline(planned,ORANGE,2,true)
  var station = 0.0
  for i in range(model.route.size()):
   if i>0:
    station+=Vector2(model.route[i].x-model.route[i-1].x,model.route[i].z-model.route[i-1].z).length()
   var q = Vector2(r.position.x+station/length*r.size.x,r.end.y-(model.route[i].y+model.offset-bounds.x)/span*r.size.y)
   draw_circle(q,5,ORANGE)
  var sx = r.position.x+r.size.x*model.station
  draw_line(Vector2(sx,r.position.y),Vector2(sx,r.end.y),Color("d1e6ef"),1)
  label("%.0fm" % bounds.y,Vector2(2,r.position.y+5))
  label("%.0fm" % bounds.x,Vector2(2,r.end.y))
  label("0 → %.0fm | 녹색: 원지반 / 주황: 계획 · 드래그: 계획고" % length,Vector2(r.position.x,size.y-10))
 else:
  var at = model.sample(length*model.station)
  var reach = max(100.0,model.road_width*4)
  var low = at.point.y+model.offset-60
  var previous_valid = false
  var previous_g = Vector2.ZERO
  var previous_d = Vector2.ZERO
  for i in range(201):
   var d = -reach+2*reach*i/200.0
   var x = at.point.x+at.normal.x*d
   var y = at.point.z+at.normal.y*d
   var g = model.ground(x,y)
   var z = model.design(x,y)
   var px = r.position.x+r.size.x*i/200.0
   if is_finite(g) and is_finite(z):
    var pg = Vector2(px,r.end.y-(g-low)/120*r.size.y)
    var pd = Vector2(px,r.end.y-(z-low)/120*r.size.y)
    if previous_valid:
     draw_line(previous_g,pg,GREEN,1.5,true)
     draw_line(previous_d,pd,ORANGE,2,true)
    previous_g=pg
    previous_d=pd
    previous_valid=true
   else:
    previous_valid=false
  label("STA %.0fm | 계획고 %.1fm | ±%.0fm" % [length*model.station,at.point.y+model.offset,reach],Vector2(r.position.x,size.y-10))

func _gui_input(event):
 if model == null or model.terrain.is_empty():
  return
 if mode == "plan" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  var r=map_rect()
  if r.has_point(event.position):
   point_added.emit((event.position-r.position)/r.size*model.extent())
 elif mode == "profile" and model.route.size()>1:
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    frozen_bounds=chart_bounds()
    var r=plot_rect()
    var target=clamp((event.position.x-r.position.x)/r.size.x,0.0,1.0)*model.length()
    var best=INF
    var station=0.0
    for i in range(model.route.size()):
     if i>0:
      station+=Vector2(model.route[i].x-model.route[i-1].x,model.route[i].z-model.route[i-1].z).length()
     if abs(station-target)<best:
      best=abs(station-target)
      edit_index=i
    change_height(event.position.y)
   else:
    edit_index=-1
    queue_redraw()
  elif event is InputEventMouseMotion and edit_index>=0:
   change_height(event.position.y)

func change_height(y):
 var r=plot_rect()
 var z=frozen_bounds.y-(y-r.position.y)/r.size.y*(frozen_bounds.y-frozen_bounds.x)-model.offset
 elevation_changed.emit(edit_index,z)
