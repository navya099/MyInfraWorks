extends Control
signal station_selected(station)
var data={}
var view_start=0.0
var view_end=1.0
var selected=-1.0
var dragging=false

static func build_data(sections):
 var segments=[]
 var rows=[]
 var gaps=[]
 var points=[]
 var cut=0.0
 var fill=0.0
 var segment=0
 for i in range(1,sections.size()):
  var row=sections[i]
  var previous=sections[i-1]
  if row.interval_status!="included" or row.cut_volume==null or row.fill_volume==null:
   if not points.is_empty():segments.append(points);points=[]
   rows.append({"interval_start":previous.station,"station":row.station,"segment":null,"kind":"excluded","cut":null,"fill":null,"net":null})
   gaps.append(Vector2(previous.station,row.station))
   continue
  if points.is_empty():
   segment+=1
   cut=0.0
   fill=0.0
   points.append(Vector2(previous.station,0))
   rows.append({"interval_start":previous.station,"station":previous.station,"segment":segment,"kind":"segment_start","cut":0.0,"fill":0.0,"net":0.0})
  cut+=row.cut_volume
  fill+=row.fill_volume
  points.append(Vector2(row.station,cut-fill))
  rows.append({"interval_start":previous.station,"station":row.station,"segment":segment,"kind":"included","cut":cut,"fill":fill,"net":cut-fill})
 if not points.is_empty():segments.append(points)
 var low=0.0
 var high=0.0
 for group in segments:
  for point in group:
   low=min(low,point.y)
   high=max(high,point.y)
 return {"segments":segments,"rows":rows,"gaps":gaps,"low":low,"high":high,"length":sections[-1].station if not sections.is_empty() else 0.0}

func set_data(value):
 data=value
 selected=-1
 fit()

func fit():
 view_start=0
 view_end=max(1.0,data.get("length",1.0))
 queue_redraw()

func plot_rect():
 return Rect2(100,30,max(1,size.x-125),max(1,size.y-85))

func y_range():
 var low=data.get("low",0.0)
 var high=data.get("high",0.0)
 var pad=max(1.0,(high-low)*0.08)
 return Vector2(low-pad,high+pad)

func screen(point):
 var rect=plot_rect()
 var bounds=y_range()
 return Vector2(rect.position.x+(point.x-view_start)/(view_end-view_start)*rect.size.x,rect.end.y-(point.y-bounds.x)/(bounds.y-bounds.x)*rect.size.y)

func station_at(x):
 var rect=plot_rect()
 return clamp(view_start+(x-rect.position.x)/rect.size.x*(view_end-view_start),0,data.get("length",0.0))

func zoom_at(x,factor):
 var length=max(1.0,data.get("length",1.0))
 var span=clamp((view_end-view_start)*factor,min(1.0,length),length)
 var ratio=clamp((x-plot_rect().position.x)/plot_rect().size.x,0,1)
 var anchor=view_start+ratio*(view_end-view_start)
 view_start=clamp(anchor-ratio*span,0,length-span)
 view_end=view_start+span
 queue_redraw()

func _gui_input(event):
 if data.is_empty():return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_MIDDLE:
   dragging=event.pressed
   accept_event()
  elif event.pressed and plot_rect().has_point(event.position):
   if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_at(event.position.x,0.8)
   elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_at(event.position.x,1.25)
   elif event.button_index==MOUSE_BUTTON_LEFT:
    if event.double_click:fit()
    else:
     var station=station_at(event.position.x)
     var best=INF
     var nearest=-1.0
     for row in data.rows:
      if row.segment!=null and abs(row.station-station)<best:
       best=abs(row.station-station)
       nearest=row.station
     if nearest>=0:
      selected=nearest
      station_selected.emit(nearest)
      queue_redraw()
   accept_event()
 elif event is InputEventMouseMotion and dragging:
  var span=view_end-view_start
  view_start=clamp(view_start-event.relative.x/plot_rect().size.x*span,0,max(0,data.length-span))
  view_end=view_start+span
  queue_redraw()

func _notification(what):
 if what==NOTIFICATION_RESIZED:queue_redraw()
 if what==NOTIFICATION_MOUSE_EXIT:dragging=false

func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color("14202d"))
 if data.is_empty():return
 var rect=plot_rect()
 var font=ThemeDB.fallback_font
 var bounds=y_range()
 for i in range(6):
  var t=i/5.0
  var y=lerpf(rect.end.y,rect.position.y,t)
  var value=lerpf(bounds.x,bounds.y,t)
  draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color("304456"))
  draw_string(font,Vector2(3,y+4),"%.0f" % value,HORIZONTAL_ALIGNMENT_LEFT,-1,13)
  var x=lerpf(rect.position.x,rect.end.x,t)
  draw_string(font,Vector2(x-25,rect.end.y+22),"%.1f" % lerpf(view_start,view_end,t),HORIZONTAL_ALIGNMENT_LEFT,-1,13)
 draw_string(font,Vector2(5,18),"CUT - FILL (m³)",HORIZONTAL_ALIGNMENT_LEFT,-1,13)
 draw_string(font,Vector2(rect.end.x-55,rect.end.y+43),"STA (m)",HORIZONTAL_ALIGNMENT_LEFT,-1,13)
 for gap in data.gaps:
  var a=max(rect.position.x,screen(Vector2(gap.x,0)).x)
  var b=min(rect.end.x,screen(Vector2(gap.y,0)).x)
  if b>a:draw_rect(Rect2(a,rect.position.y,b-a,rect.size.y),Color(0.9,0.3,0.3,0.16))
 draw_line(Vector2(rect.position.x,screen(Vector2(0,0)).y),Vector2(rect.end.x,screen(Vector2(0,0)).y),Color("708698"))
 for group in data.segments:
  var line=PackedVector2Array()
  for i in range(1,group.size()):
   var a=group[i-1]
   var b=group[i]
   if b.x<view_start or a.x>view_end:continue
   var left=max(a.x,view_start)
   var right=min(b.x,view_end)
   if line.is_empty():line.append(screen(Vector2(left,lerpf(a.y,b.y,(left-a.x)/(b.x-a.x)))))
   line.append(screen(Vector2(right,lerpf(a.y,b.y,(right-a.x)/(b.x-a.x)))))
  if line.size()>1:draw_polyline(line,Color("70ddbc"),2,true)
 if selected>=view_start and selected<=view_end:
  var x=screen(Vector2(selected,0)).x
  draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("ffd27f"),1)
  draw_string(font,Vector2(x+5,rect.position.y+15),"STA %.3f" % selected,HORIZONTAL_ALIGNMENT_LEFT,-1,13)
 if data.segments.is_empty():draw_string(font,rect.position+Vector2(20,40),"No valid intervals",HORIZONTAL_ALIGNMENT_LEFT,-1,20)
