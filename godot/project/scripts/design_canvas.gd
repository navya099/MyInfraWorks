extends Control
signal point_added(point)
signal point_inserted(after_index,point)
signal insertion_cancelled
var insert_after=-1
var append_mode=false
signal addition_cancelled
signal elevation_changed(index, elevation)
signal point_selected(index)
signal point_moved(index, point)
signal pvi_moved(index, station, height)
signal pvi_added(station, height)
signal station_selected(fraction)
signal gesture_started
signal gesture_finished
var plan_zoom=1.0
var plan_shift=Vector2.ZERO
var profile_manual=false
var profile_view=Rect2(0,0,1,1)
var navigation_panning=false
var section_mode="full"
var section_view=Rect2(-100,-60,200,120) # offset and elevation relative to road centre
var section_panning=false
var section_mpp=0.0 # Shared horizontal/vertical metres per physical screen pixel.
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
 get_window().focus_exited.connect(stop_navigation)

func plot_rect():
 return Rect2(Vector2(48,20),Vector2(max(1,size.x-68),max(1,size.y-56)))

func map_rect():
 var available = size-Vector2(32,32)
 var ext = model.extent()
 var scale_factor = min(available.x/ext.x,available.y/ext.y)
 var dimensions = ext*max(0.000001,scale_factor)*plan_zoom
 return Rect2((size-dimensions)/2.0+plan_shift*size,dimensions)

func chart_bounds():
 if edit_index >= 0:
  return frozen_bounds
 if profile_manual:
  return Vector2(profile_view.position.y,profile_view.end.y)
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
  if model.length()>0:
   var at=model.sample(model.length()*model.station)
   var q=r.position+Vector2(at.x,at.y)/ext*r.size
   if plan_area().has_point(q):
    var cross=Vector2(-sin(at.heading),cos(at.heading))*model.road_width/2.0/ext*r.size
    if cross.length()<10:cross=cross.normalized()*10
    draw_line(q-cross,q+cross,Color("7eeaff"),2,true)
    draw_circle(q,4,Color("7eeaff"))
    label("STA %.3f" % at.station,q+Vector2(10,-12),Color("7eeaff"))
  draw_rect(Rect2(0,0,size.x,26),Color("13212c"))
  draw_rect(Rect2(0,size.y-26,size.x,26),Color("13212c"))
  label("N ↑  |  %.1f × %.1f km" % [ext.x/1000,ext.y/1000],Vector2(14,18))
  if drag_index>=0 and drag_rejected:
   draw_circle(drag_target,9,Color("ff7777"),false,2)
  var hint="PI %d 뒤 삽입: 클릭 지정 / Esc·우클릭 취소" % (insert_after+1) if insert_after>=0 else "PI 추가 중: 클릭으로 노선 끝에 추가 / Esc·우클릭: 종료" if append_mode else "선택 모드: PI 클릭·드래그 / 새 점은 아래 PI 추가 버튼 선택"
  label(hint,Vector2(14,size.y-10),ORANGE if append_mode else MUTED)
  return
 if model.route.size()<2:
  label("평면에 노선 점을 두 개 이상 추가하세요.",Vector2(24,38))
  return
 var r = plot_rect()
 for i in range(5):
  var y = r.position.y+r.size.y*i/4
  draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("263946"))
 var length = model.length()
 if mode == "profile":
  draw_profile(r,length)

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

func section_pixels(r):
 var transform=get_viewport().get_screen_transform()*get_global_transform_with_canvas()
 return Vector2(r.size.x*max(0.000001,transform.x.length()),r.size.y*max(0.000001,transform.y.length()))

func fit_equal_section(bounds,r):
 var pixels=section_pixels(r)
 section_mpp=clamp(max(bounds.size.x/pixels.x,bounds.size.y/pixels.y),0.0001,1000.0)
 section_view=Rect2(bounds.get_center()-pixels*section_mpp/2.0,pixels*section_mpp)

func sync_section_scale(r):
 if section_mpp<=0:
  fit_equal_section(section_view,r)
 else:
  var centre=section_view.get_center()
  var span=section_pixels(r)*section_mpp
  section_view=Rect2(centre-span/2.0,span)

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
  fit_equal_section(Rect2(-half*1.3,middle-span/2.0,half*2.6,span),r)
 elif section_mode=="full":
  var reach=max(100.0,model.road_width*4)
  section_view=Rect2(-reach,-60,reach*2,120)
 else:
  sync_section_scale(r)
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
  var old_width=section_view.size.x
  fit_equal_section(section_view,r)
  # Equal scales can reveal extra horizontal context beyond the fitted span.
  if not is_equal_approx(old_width,section_view.size.x):samples=section_samples(section_view,at)
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
   if d==0 or section_view.size.x<=model.road_width*3:
    label(("중심" if d==0 else "좌" if d<0 else "우")+" %.2f" % h,q+Vector2(4,-8),Color("a8d4ef"))
 label("%.2f" % (centre+section_view.end.y),Vector2(1,r.position.y+5))
 label("%.2f" % (centre+section_view.position.y),Vector2(1,r.end.y))
 label("%.2fm" % section_view.position.x,Vector2(r.position.x,r.end.y+16))
 label("%.2fm" % section_view.end.x,Vector2(r.end.x-65,r.end.y+16))
 label("STA %.3fm | H:V 1:1 | 좌 %.1f%% / 우 %.1f%%" % [length*model.station,model.left_fall,model.right_fall],Vector2(r.position.x,size.y-4))

func section_line(a,b,rect,color,width):
 if rect.has_point(a) and rect.has_point(b):
  draw_line(a,b,color,width,true)
  return
 if max(a.x,b.x)<rect.position.x or min(a.x,b.x)>rect.end.x or max(a.y,b.y)<rect.position.y or min(a.y,b.y)>rect.end.y:return
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
   sync_section_scale(r)
   var anchor=Vector2((event.position.x-r.position.x)/r.size.x,(r.end.y-event.position.y)/r.size.y)
   var world=section_view.position+anchor*section_view.size
   var factor=0.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.25
   section_mpp=clamp(section_mpp*factor,0.0001,1000.0)
   section_view.size=section_pixels(r)*section_mpp
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
  sync_section_scale(r)
  section_view.position+=Vector2(-event.relative.x/r.size.x,event.relative.y/r.size.y)*section_view.size
  section_mode="manual"
  queue_redraw()
  accept_event()

func _gui_input(event):
 if model == null or model.terrain.is_empty():
  return
 if mode in ["plan","profile"] and navigation_input(event):return
 if mode=="section" and model.route.size()>1:
  section_input(event)
  return
 if mode=="plan" and append_mode:
  if event is InputEventMouseButton and event.pressed:
   if event.button_index==MOUSE_BUTTON_RIGHT:addition_cancelled.emit()
   elif event.button_index==MOUSE_BUTTON_LEFT:
    var r=map_rect()
    if r.has_point(event.position) and plan_area().has_point(event.position):
     point_added.emit((event.position-r.position)/r.size*model.extent())
  return
 if mode=="plan" and insert_after>=0:
  if event is InputEventMouseButton and event.pressed:
   if event.button_index==MOUSE_BUTTON_RIGHT:
    insertion_cancelled.emit()
   elif event.button_index==MOUSE_BUTTON_LEFT:
    var r=map_rect()
    if r.has_point(event.position) and plan_area().has_point(event.position):
     point_inserted.emit(insert_after,(event.position-r.position)/r.size*model.extent())
  return
 if mode == "plan" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
  var r=map_rect()
  if not plan_area().has_point(event.position):return
  var best=14.0
  var selected=-1
  for i in range(model.route.size()):
   var point=model.route[i]
   var screen=r.position+Vector2(point.x,point.z)/model.extent()*r.size
   var distance=screen.distance_to(event.position)
   if plan_area().has_point(screen) and distance<best:
    best=distance
    selected=i
  if selected>=0:
   point_selected.emit(selected)
 elif mode=="plan" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   grab_focus()
   var r=map_rect()
   if not plan_area().has_point(event.position):return
   var best=12.0
   drag_index=-1
   for i in range(model.route.size()):
    var p=model.route[i]
    var q=r.position+Vector2(p.x,p.z)/model.extent()*r.size
    var distance=q.distance_to(event.position)
    if plan_area().has_point(q) and distance<best:
     best=distance
     drag_index=i
   if drag_index>=0:
    drag_start=event.position
    drag_target=event.position
    drag_rejected=false
    point_selected.emit(drag_index)
    gesture_started.emit()

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
    if not rect.grow(0.01).has_point(event.position):return
    if event.shift_pressed and rect.has_point(event.position):
     var station=clamp(profile_world(event.position).x,0.0,model.length())
     var height=profile_world(event.position).y-model.offset
     pvi_added.emit(station,height)
     return
    var nearest=nearest_pvi(event.position)
    if nearest<0:
     station_selected.emit(clamp(profile_world(event.position).x/model.length(),0.0,1.0))
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
   var station=profile_world(event.position).x
   var height=profile_world(event.position).y-model.offset
   pvi_moved.emit(edit_index,station,height)

func nearest_pvi(position):
 var rect=plot_rect()
 var bounds=chart_bounds()
 var nearest=-1
 var distance=14.0
 for i in range(model.pvi_stations.size()):
  var q=profile_screen(model.pvi_stations[i],model.pvi_heights[i]+model.offset)
  if rect.grow(0.01).has_point(q) and q.distance_to(position)<distance:
   distance=q.distance_to(position)
   nearest=i
 return nearest


func plan_area():
 return Rect2(Vector2(12,26),Vector2(max(1,size.x-24),max(1,size.y-52)))

func station_range():
 return Vector2(profile_view.position.x,profile_view.end.x) if profile_manual else Vector2(0,max(1.0,model.length()))

func profile_screen(station,height):
 var r=plot_rect()
 var stations=station_range()
 var heights=chart_bounds()
 return Vector2(r.position.x+(station-stations.x)/(stations.y-stations.x)*r.size.x,r.end.y-(height-heights.x)/(heights.y-heights.x)*r.size.y)

func profile_world(position):
 var r=plot_rect()
 var stations=station_range()
 var heights=chart_bounds()
 return Vector2(lerp(stations.x,stations.y,(position.x-r.position.x)/r.size.x),lerp(heights.x,heights.y,(r.end.y-position.y)/r.size.y))

func fit_navigation():
 plan_zoom=1.0
 plan_shift=Vector2.ZERO
 profile_manual=false
 stop_navigation()
 queue_redraw()

func stop_navigation():
 navigation_panning=false
 section_panning=false

func zoom_navigation(position,factor,horizontal_only=false,vertical_only=false):
 if drag_index>=0 or edit_index>=0:return
 if mode=="plan":
  var old=map_rect()
  var anchor=(position-old.position)/old.size
  plan_zoom=clamp(plan_zoom/factor,0.25,1024.0)
  var current=map_rect()
  plan_shift+=(position-current.position-anchor*current.size)/size
 elif mode=="profile" and model.length()>0:
  var r=plot_rect()
  var world=profile_world(position)
  var anchor=Vector2((position.x-r.position.x)/r.size.x,(r.end.y-position.y)/r.size.y)
  var stations=station_range()
  var heights=chart_bounds()
  var span=profile_view.size if profile_manual else Vector2(stations.y-stations.x,heights.y-heights.x)
  span.x=clamp(span.x*(1.0 if vertical_only else factor),1.0,max(100.0,model.length()*8))
  span.y=clamp(span.y*(1.0 if horizontal_only else factor),0.02,1000000.0)
  profile_view=Rect2(world-anchor*span,span)
  profile_manual=true
 queue_redraw()

func navigation_input(event):
 var area=plan_area() if mode=="plan" else plot_rect()
 if event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   if event.pressed and area.has_point(event.position):
    zoom_navigation(event.position,0.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.25,event.shift_pressed,event.ctrl_pressed)
    accept_event()
   return true
  if event.button_index==MOUSE_BUTTON_MIDDLE:
   navigation_panning=event.pressed and area.has_point(event.position) and drag_index<0 and edit_index<0
   accept_event()
   return true
 elif event is InputEventMouseMotion and navigation_panning:
  if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
   navigation_panning=false
   return true
  if mode=="plan":plan_shift+=event.relative/size
  elif model.length()>0:
   var stations=station_range()
   var heights=chart_bounds()
   var span=profile_view.size if profile_manual else Vector2(stations.y-stations.x,heights.y-heights.x)
   var origin=Vector2(stations.x,heights.x)+Vector2(-event.relative.x/area.size.x,event.relative.y/area.size.y)*span
   profile_view=Rect2(origin,span)
   profile_manual=true
  queue_redraw()
  accept_event()
  return true
 return navigation_panning

func project_profile(station,height,r,stations,heights):
 return Vector2(r.position.x+(station-stations.x)/(stations.y-stations.x)*r.size.x,r.end.y-(height-heights.x)/(heights.y-heights.x)*r.size.y)

func draw_profile(r,length):
 var stations=station_range()
 var bounds=chart_bounds()
 var start=max(0.0,stations.x)
 var end=min(length,stations.y)
 var samples=[]
 if end>=start:
  for i in range(241):samples.append(lerp(start,end,i/240.0))
  for i in range(model.pvi_stations.size()):
   for station in [model.pvi_stations[i],model.pvi_stations[i]-model.pvi_lengths[i]/2,model.pvi_stations[i]+model.pvi_lengths[i]/2]:
    if station>=start and station<=end:samples.append(station)
 samples.sort()
 var previous_g=Vector2.ZERO
 var previous_d=Vector2.ZERO
 var valid_g=false
 var valid_d=false
 for station in samples:
  var point=model.sample(station).point
  var g=model.ground(point.x,point.z)
  var pd=project_profile(station,point.y+model.offset,r,stations,bounds)
  if valid_d:section_line(previous_d,pd,r,ORANGE,2)
  previous_d=pd
  valid_d=true
  if is_finite(g):
   var pg=project_profile(station,g,r,stations,bounds)
   if valid_g:section_line(previous_g,pg,r,GREEN,1.5)
   previous_g=pg
   valid_g=true
  else:valid_g=false
 for i in range(model.pvi_stations.size()):
  var q=project_profile(model.pvi_stations[i],model.pvi_heights[i]+model.offset,r,stations,bounds)
  if r.grow(0.01).has_point(q):
   draw_circle(q,5,ORANGE)
   if i==selected_index:draw_circle(q,8,Color("a8d4ef"),false,1.5)
  if i>0 and i<model.pvi_stations.size()-1 and model.pvi_lengths[i]>0:
   for station in [model.pvi_stations[i]-model.pvi_lengths[i]/2,model.pvi_stations[i]+model.pvi_lengths[i]/2]:
    var point=model.sample(station).point
    var marker=project_profile(station,point.y+model.offset,r,stations,bounds)
    if r.grow(0.01).has_point(marker):draw_circle(marker,3,Color("a8d4ef"))
 if edit_index>=0 and drag_rejected and r.has_point(drag_target):draw_circle(drag_target,9,Color("ff7777"),false,2)
 var sx=project_profile(length*model.station,bounds.x,r,stations,bounds).x
 if sx>=r.position.x and sx<=r.end.x:draw_line(Vector2(sx,r.position.y),Vector2(sx,r.end.y),Color("d1e6ef"),1)
 label("%.2f" % bounds.y,Vector2(1,r.position.y+5))
 label("%.2f" % bounds.x,Vector2(1,r.end.y))
 label("STA %.2f → %.2f | 녹색: 원지반 / 주황: 계획" % [stations.x,stations.y],Vector2(r.position.x,size.y-10))


func focus_navigation():
 if model.length()<=0:return
 var at=model.sample(model.length()*model.station)
 if mode=="plan":
  var r=map_rect()
  var screen=r.position+Vector2(at.x,at.y)/model.extent()*r.size
  plan_shift+=(size/2.0-screen)/size
 elif mode=="profile":
  var bounds=chart_bounds()
  var span=profile_view.size if profile_manual else Vector2(max(20.0,model.length()*0.2),max(10.0,(bounds.y-bounds.x)*0.3))
  profile_view=Rect2(Vector2(at.station,at.elevation+model.offset)-span/2.0,span)
  profile_manual=true
 stop_navigation()
 queue_redraw()
