extends Control
signal point_added(point)
signal point_inserted(after_index,point)
signal insertion_cancelled
var insert_after=-1
signal elevation_changed(index, elevation)
signal point_selected(index)
signal point_moved(index, point)
signal pvi_moved(index, station, height)
signal pvi_added(station, height)
signal station_selected(fraction)
signal gesture_started
signal gesture_finished
var section_mode="full"
var section_view=Rect2(-100,-60,200,120) # offset and elevation relative to road centre
var section_panning=false
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
 for height in model.pvi_heights:
  low = min(low,height+model.offset)
  high = max(high,height+model.offset)
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
  if insert_after>=0 and insert_after+1<model.route.size():
   var a=model.route[insert_after]
   var b=model.route[insert_after+1]
   draw_line(r.position+Vector2(a.x,a.z)/ext*r.size,r.position+Vector2(b.x,b.z)/ext*r.size,Color("a8d4ef"),3,true)
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
  label("PI %d 뒤 삽입: 클릭 지정 / Esc·우클릭 취소" % (insert_after+1) if insert_after>=0 else "클릭: 끝에 추가 / 점 드래그: 이동 / 우클릭: 선택 / Shift+클릭: 끝에 추가",Vector2(14,size.y-10))
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
  for i in range(model.pvi_stations.size()):
   station=model.pvi_stations[i]
   var q = Vector2(r.position.x+station/length*r.size.x,r.end.y-(model.pvi_heights[i]+model.offset-bounds.x)/span*r.size.y)
   draw_circle(q,5,ORANGE)
   if i==selected_index:
    draw_circle(q,8,Color("a8d4ef"),false,1.5)
  for i in range(1,model.pvi_stations.size()-1):
   var length_v=model.pvi_lengths[i]
   if length_v<=0:
    continue
   for station_v in [model.pvi_stations[i]-length_v/2,model.pvi_stations[i]+length_v/2]:
    var p=model.sample(station_v).point
    var marker=Vector2(r.position.x+station_v/length*r.size.x,r.end.y-(p.y+model.offset-bounds.x)/span*r.size.y)
    draw_circle(marker,3,Color("a8d4ef"))
  if edit_index>=0 and drag_rejected:
   draw_circle(drag_target,9,Color("ff7777"),false,2)
  var sx = r.position.x+r.size.x*model.station
  draw_line(Vector2(sx,r.position.y),Vector2(sx,r.end.y),Color("d1e6ef"),1)
  label("%.0fm" % bounds.y,Vector2(2,r.position.y+5))
  label("%.0fm" % bounds.x,Vector2(2,r.end.y))
  label("0 → %.0fm | 녹색: 원지반 / 주황: 계획 · PVI 드래그: 측점·표고 / Shift+클릭: 추가" % length,Vector2(r.position.x,size.y-10))
 else:
  draw_section(r,length)

func fit_section(road_only=false):
 section_mode="road" if road_only else "full"
 section_panning=false
 queue_redraw()

func section_samples(view,at):
 var distances=[]
 for i in range(241):distances.append(view.position.x+view.size.x*i/240.0)
 for d in [-model.road_width/2.0,0.0,model.road_width/2.0]:
  if d>=view.position.x and d<=view.end.x:distances.append(d)
 distances.sort()
 var samples=[]
 for d in distances:
  var x=at.point.x+at.normal.x*d
  var y=at.point.z+at.normal.y*d
  samples.append(Vector3(d,model.ground(x,y),model.design(x,y)))
 return samples

func section_screen(d,height,centre,r):
 return Vector2(r.position.x+(d-section_view.position.x)/section_view.size.x*r.size.x,r.end.y-(height-centre-section_view.position.y)/section_view.size.y*r.size.y)

func draw_section(r,length):
 var at=model.sample(length*model.station)
 var centre=at.elevation+model.offset
 if section_mode=="road":
  var half=model.road_width/2.0
  var left=-half*model.left_fall/100.0
  var right=-half*model.right_fall/100.0
  var span=max(1.0,(max(0.0,max(left,right))-min(0.0,min(left,right)))*1.6)
  var middle=(max(0.0,max(left,right))+min(0.0,min(left,right)))/2.0
  section_view=Rect2(-half*1.3,middle-span/2.0,half*2.6,span)
 elif section_mode=="full":
  var reach=max(100.0,model.road_width*4)
  section_view=Rect2(-reach,-60,reach*2,120)
 var samples=section_samples(section_view,at)
 if section_mode=="full":
  var low=centre
  var high=centre
  for p in samples:
   for h in [p.y,p.z]:
    if is_finite(h):
     low=min(low,h)
     high=max(high,h)
  var pad=max(1.0,(high-low)*0.12)
  section_view.position.y=low-centre-pad
  section_view.size.y=max(2.0,high-low+pad*2)
 var previous_valid=false
 var previous_g=Vector2.ZERO
 var previous_d=Vector2.ZERO
 # Clip line segments to the chart so panning cannot draw across labels.
 for p in samples:
  if is_finite(p.y) and is_finite(p.z):
   var pg=section_screen(p.x,p.y,centre,r)
   var pd=section_screen(p.x,p.z,centre,r)
   if previous_valid:
    section_line(previous_g,pg,r,GREEN,1.5)
    section_line(previous_d,pd,r,ORANGE,2)
   previous_g=pg
   previous_d=pd
   previous_valid=true
  else:previous_valid=false
 for d in [-model.road_width/2.0,0.0,model.road_width/2.0]:
  var h=centre-abs(d)*(model.left_fall if d<0 else model.right_fall)/100.0
  var q=section_screen(d,h,centre,r)
  if r.has_point(q):
   draw_circle(q,3,Color("a8d4ef"))
   label(("중심" if d==0 else "좌" if d<0 else "우")+" %.2f" % h,q+Vector2(4,-8),Color("a8d4ef"))
 label("%.2f" % (centre+section_view.end.y),Vector2(1,r.position.y+5))
 label("%.2f" % (centre+section_view.position.y),Vector2(1,r.end.y))
 label("%.2fm" % section_view.position.x,Vector2(r.position.x,r.end.y+16))
 label("%.2fm" % section_view.end.x,Vector2(r.end.x-65,r.end.y+16))
 label("STA %.3fm | 좌 %.1f%% / 우 %.1f%% | 진행 방향 기준 좌/우" % [length*model.station,model.left_fall,model.right_fall],Vector2(r.position.x,size.y-4))

func section_line(a,b,rect,color,width):
 # Liang-Barsky segment clipping, including lines whose ends are both off-screen.
 var delta=b-a
 var lo=0.0
 var hi=1.0
 var ps=[-delta.x,delta.x,-delta.y,delta.y]
 var qs=[a.x-rect.position.x,rect.end.x-a.x,a.y-rect.position.y,rect.end.y-a.y]
 for i in range(4):
  if abs(ps[i])<1e-12:
   if qs[i]<0:return
  else:
   var t=qs[i]/ps[i]
   if ps[i]<0:lo=max(lo,t)
   else:hi=min(hi,t)
   if lo>hi:return
 draw_line(a+delta*lo,a+delta*hi,color,width,true)

func section_input(event):
 if event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
   var r=plot_rect()
   if not r.has_point(event.position):return
   var anchor=Vector2((event.position.x-r.position.x)/r.size.x,(r.end.y-event.position.y)/r.size.y)
   var world=section_view.position+anchor*section_view.size
   var factor=0.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.25
   var zoom=Vector2(1 if event.ctrl_pressed else factor,1 if event.shift_pressed else factor)
   section_view.size=Vector2(clamp(section_view.size.x*zoom.x,0.2,20000),clamp(section_view.size.y*zoom.y,0.02,20000))
   section_view.position=world-anchor*section_view.size
   section_mode="manual"
   queue_redraw()
   accept_event()
  elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
   section_panning=event.pressed and plot_rect().has_point(event.position)
   if event.pressed and event.double_click:fit_section(true)
 elif event is InputEventMouseMotion and section_panning:
  if not (event.button_mask & (MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_MIDDLE|MOUSE_BUTTON_MASK_RIGHT)):
   section_panning=false
   return
  var r=plot_rect()
  section_view.position+=Vector2(-event.relative.x/r.size.x,event.relative.y/r.size.y)*section_view.size
  section_mode="manual"
  queue_redraw()
  accept_event()

func _gui_input(event):
 if model == null or model.terrain.is_empty():
  return
 if mode=="section" and model.route.size()>1:
  section_input(event)
  return
 if mode=="plan" and insert_after>=0:
  if event is InputEventMouseButton and event.pressed:
   if event.button_index==MOUSE_BUTTON_RIGHT:
    insertion_cancelled.emit()
   elif event.button_index==MOUSE_BUTTON_LEFT:
    var r=map_rect()
    if r.has_point(event.position):
     point_inserted.emit(insert_after,(event.position-r.position)/r.size*model.extent())
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
 elif mode=="profile" and model.route.size()>1:
  if event is InputEventMouseButton:
   if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
    grab_focus()
    var rect=plot_rect()
    var bounds=chart_bounds()
    if event.shift_pressed and rect.has_point(event.position):
     var station=clamp((event.position.x-rect.position.x)/rect.size.x,0.0,1.0)*model.length()
     var height=bounds.y-(event.position.y-rect.position.y)/rect.size.y*(bounds.y-bounds.x)-model.offset
     pvi_added.emit(station,height)
     return
    var nearest=nearest_pvi(event.position)
    if nearest<0:
     station_selected.emit(clamp((event.position.x-rect.position.x)/rect.size.x,0.0,1.0))
     return
    frozen_bounds=bounds
    edit_index=nearest
    drag_rejected=false
    point_selected.emit(edit_index)
    gesture_started.emit()
   elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and edit_index>=0:
    edit_index=-1
    drag_rejected=false
    gesture_finished.emit()
    queue_redraw()
   elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
    var nearest=nearest_pvi(event.position)
    if nearest>=0:
     point_selected.emit(nearest)
  elif event is InputEventMouseMotion and edit_index>=0:
   drag_target=event.position
   var rect=plot_rect()
   var station=(event.position.x-rect.position.x)/rect.size.x*model.length()
   var height=frozen_bounds.y-(event.position.y-rect.position.y)/rect.size.y*(frozen_bounds.y-frozen_bounds.x)-model.offset
   pvi_moved.emit(edit_index,station,height)

func nearest_pvi(position):
 var rect=plot_rect()
 var bounds=chart_bounds()
 var nearest=-1
 var distance=14.0
 for i in range(model.pvi_stations.size()):
  var q=Vector2(rect.position.x+model.pvi_stations[i]/model.length()*rect.size.x,rect.end.y-(model.pvi_heights[i]+model.offset-bounds.x)/(bounds.y-bounds.x)*rect.size.y)
  if q.distance_to(position)<distance:
   distance=q.distance_to(position)
   nearest=i
 return nearest
