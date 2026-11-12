extends Control
signal point_added(point)
signal elevation_changed(index, elevation)
signal point_selected(index)
signal point_moved(index, point)
signal gesture_started
signal gesture_finished
var drag_index=-1
var drag_start=Vector2.ZERO
var drag_target=Vector2.ZERO
var drag_rejected=false
var model
var mode = "plan"
var edit_index = -1
var selected_index=-1
var frozen_bounds = Vector2.ZERO
const GREEN = Color("78c7a6")
const ORANGE = Color("ffbd69")
const MUTED = Color("8097a9")

func _ready():
 mouse_filter = Control.MOUSE_FILTER_STOP
 focus_mode=Control.FOCUS_ALL
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
  for i in range(1,model.route.size()):
   var a=model.route[i-1]
   var b=model.route[i]
   draw_line(r.position+Vector2(a.x,a.z)/ext*r.size,r.position+Vector2(b.x,b.z)/ext*r.size,Color(0.65,0.74,0.80,0.35),1,true)
  for i in range(model.route.size()):
   var v = model.route[i]
   var q = r.position+Vector2(v.x,v.z)/ext*r.size
   draw_circle(q,4,ORANGE)
   if i==selected_index:
    draw_circle(q,8,Color("a8d4ef"),false,1.5)
   label(str(i+1),q+Vector2(6,-6),ORANGE)
  for point in model.centerline:
   points.append(r.position+Vector2(point.x,point.z)/ext*r.size)
  if points.size()>1:
   draw_polyline(points,ORANGE,2.5,true)
  for element in model.alignment_data.elements:
   var marker=""
   var s=element.station
   if element.type=="spiral_in":
    marker="TS"
   elif element.type=="arc":
    marker="SC" if model.spirals[element.pi]>0 else "BC"
   elif element.type=="spiral_out":
    marker="CS"
   if marker!="":
    var point=model.sample(s).point
    var q=r.position+Vector2(point.x,point.z)/ext*r.size
    draw_circle(q,3,Color("a8d4ef"))
    label(marker,q+(Vector2(-18,-8) if element.type=="spiral_in" else Vector2(4,20) if element.type=="arc" else Vector2(8,-8)),Color("a8d4ef"))
   if element.type=="spiral_out" or (element.type=="arc" and model.spirals[element.pi]==0):
    var point=model.sample(element.station+element.length).point
    var q=r.position+Vector2(point.x,point.z)/ext*r.size
    draw_circle(q,3,Color("a8d4ef"))
    label("ST" if element.type=="spiral_out" else "EC",q+Vector2(8,20),Color("a8d4ef"))
  label("N ↑  |  %.1f × %.1f km" % [ext.x/1000,ext.y/1000],Vector2(14,18))
  if drag_index>=0 and drag_rejected:
   draw_circle(drag_target,9,Color("ff7777"),false,2)
  label("클릭: 추가 / 점 드래그: 이동 / Shift+클릭: 강제 추가 / Esc: 취소",Vector2(14,size.y-10))
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
    station=model.pi_station(i)
   var q = Vector2(r.position.x+station/length*r.size.x,r.end.y-(model.route[i].y+model.offset-bounds.x)/span*r.size.y)
   draw_circle(q,5,ORANGE)
   if i==selected_index:
    draw_circle(q,8,Color("a8d4ef"),false,1.5)
  for i in range(1,model.route.size()-1):
   var length_v=model.vertical_lengths[i]
   if length_v<=0:
    continue
   for station_v in [model.pi_station(i)-length_v/2,model.pi_station(i)+length_v/2]:
    var p=model.sample(station_v).point
    var marker=Vector2(r.position.x+station_v/length*r.size.x,r.end.y-(p.y+model.offset-bounds.x)/span*r.size.y)
    draw_circle(marker,3,Color("a8d4ef"))
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
 if mode == "plan" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
  var r=map_rect()
  var best=INF
  var selected=-1
  for i in range(model.route.size()):
   var point=model.route[i]
   var screen=r.position+Vector2(point.x,point.z)/model.extent()*r.size
   var distance=screen.distance_to(event.position)
   if distance<best:
    best=distance
    selected=i
  if selected>=0:
   point_selected.emit(selected)
 elif mode=="plan" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   grab_focus()
   var r=map_rect()
   var best=12.0
   drag_index=-1
   for i in range(0 if event.shift_pressed else model.route.size()):
    var p=model.route[i]
    var q=r.position+Vector2(p.x,p.z)/model.extent()*r.size
    var distance=q.distance_to(event.position)
    if distance<best:
     best=distance
     drag_index=i
   if drag_index>=0:
    drag_start=event.position
    drag_target=event.position
    drag_rejected=false
    point_selected.emit(drag_index)
    gesture_started.emit()
   elif r.has_point(event.position):
    point_added.emit((event.position-r.position)/r.size*model.extent())
  elif drag_index>=0:
   drag_index=-1
   drag_rejected=false
   gesture_finished.emit()
   queue_redraw()
 elif mode=="plan" and event is InputEventMouseMotion and drag_index>=0:
  if event.position.distance_to(drag_start)>=3:
   var r=map_rect()
   drag_target=event.position
   point_moved.emit(drag_index,(event.position-r.position)/r.size*model.extent())
 elif mode == "profile" and model.route.size()>1:
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    grab_focus()
    gesture_started.emit()
    frozen_bounds=chart_bounds()
    var r=plot_rect()
    var target=clamp((event.position.x-r.position.x)/r.size.x,0.0,1.0)*model.length()
    var best=INF
    var station=0.0
    for i in range(model.route.size()):
     if i>0:
      station=model.pi_station(i)
     if abs(station-target)<best:
      best=abs(station-target)
      edit_index=i
    point_selected.emit(edit_index)
    change_height(event.position.y)
   else:
    edit_index=-1
    gesture_finished.emit()
    queue_redraw()
  elif event is InputEventMouseMotion and edit_index>=0:
   change_height(event.position.y)

func change_height(y):
 var r=plot_rect()
 var z=frozen_bounds.y-(y-r.position.y)/r.size.y*(frozen_bounds.y-frozen_bounds.x)-model.offset
 elevation_changed.emit(edit_index,z)
