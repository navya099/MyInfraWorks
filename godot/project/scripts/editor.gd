extends Control
const Model = preload("res://scripts/road_model.gd")
const DesignCanvas = preload("res://scripts/design_canvas.gd")
const TILE = 32
var model = Model.new()
var plan
var profile
var section
var viewport: SubViewport
var camera: Camera3D
var terrain_root: Node3D
var road_node: MeshInstance3D
var terrain_material: StandardMaterial3D
var status: Label
var metrics: Label
var width_input: SpinBox
var offset_input: SpinBox
var slope_input: SpinBox
var station_slider: HSlider
var dem_dialog: FileDialog
var save_dialog: FileDialog
var load_dialog: FileDialog
var message: AcceptDialog
var tiles = {}
var dirty = {}
var worker: Thread
var import_worker: Thread
var revision = 0
var running_revision = -1
var apply_queue = []
var apply_revision = -1
var last_build_ms = 0.0
var last_applied = 0
var total_mesh_updates = 0
var next_launch = 0
var yaw = 0.7
var pitch = 0.65
var distance = 5000.0
var target = Vector3.ZERO
var status_note = ""
var demo_button: Button
var open_button: Button
var load_button: Button
var clear_button: Button

func _ready():
 build_ui()
 model.demo()
 reset_terrain()
 if "--dem-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_dem_smoke")
 elif "--smoke" in OS.get_cmdline_user_args():
  call_deferred("run_smoke")
 elif "--visual-test" in OS.get_cmdline_user_args():
  call_deferred("run_visual_test")

func button(row,text,action):
 var b=Button.new()
 b.text=text
 b.pressed.connect(action)
 row.add_child(b)
 return b

func card(parent,title):
 var panel=PanelContainer.new()
 panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box=VBoxContainer.new()
 panel.add_child(box)
 var label=Label.new()
 label.text="  "+title
 label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.clip_text=true
 label.add_theme_color_override("font_color",Color("8edac3"))
 box.add_child(label)
 return box

func make_canvas(parent,title,mode):
 var box=card(parent,title)
 var canvas=DesignCanvas.new()
 canvas.model=model
 canvas.mode=mode
 canvas.custom_minimum_size=Vector2(280,180)
 canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
 box.add_child(canvas)
 return canvas

func number(row,title,value,minimum,maximum,step):
 var label=Label.new()
 label.text=title
 row.add_child(label)
 var spin=SpinBox.new()
 spin.min_value=minimum
 spin.max_value=maximum
 spin.step=step
 spin.value=value
 spin.custom_minimum_size.x=100
 row.add_child(spin)
 return spin

func build_ui():
 var theme_data=Theme.new()
 theme_data.default_font_size=14
 theme=theme_data
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","top","right","bottom"]:
  margin.add_theme_constant_override("margin_"+side,14)
 add_child(margin)
 var root=VBoxContainer.new()
 root.add_theme_constant_override("separation",10)
 margin.add_child(root)
 var heading=HBoxContainer.new()
 root.add_child(heading)
 var title=Label.new()
 title.text="MY INFRAWORKS  /  GODOT + C++"
 title.add_theme_font_size_override("font_size",24)
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 heading.add_child(title)
 metrics=Label.new()
 metrics.add_theme_color_override("font_color",Color("8edac3"))
 heading.add_child(metrics)
 var toolbar=HBoxContainer.new()
 root.add_child(toolbar)
 open_button=button(toolbar,"DEM 열기",func():dem_dialog.popup_centered_ratio(0.75))
 demo_button=button(toolbar,"데모",func():model.demo();reset_terrain())
 button(toolbar,"저장",func():save_dialog.popup_centered_ratio(0.65))
 load_button=button(toolbar,"프로젝트 열기",func():load_dialog.popup_centered_ratio(0.65))
 button(toolbar,"마지막 점 취소",remove_last)
 clear_button=button(toolbar,"노선 초기화",clear_route)
 button(toolbar,"화면 맞춤",fit_camera)
 var settings=HBoxContainer.new()
 root.add_child(settings)
 width_input=number(settings,"전체 폭(m)",20,1,200,0.5)
 offset_input=number(settings,"계획고 보정(m)",0,-1000,1000,0.5)
 slope_input=number(settings,"사면 H:V",1.5,0.1,10,0.1)
 button(settings,"적용",apply_parameters)
 var hint=Label.new()
 hint.text="  직선 노선 · 단순 사면 · DEM 미리보기"
 hint.add_theme_color_override("font_color",Color("94a8ba"))
 settings.add_child(hint)
 status=Label.new()
 status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 root.add_child(status)
 var split=VSplitContainer.new()
 split.size_flags_vertical=Control.SIZE_EXPAND_FILL
 split.split_offset=460
 root.add_child(split)
 var upper=HSplitContainer.new()
 upper.split_offset=0
 split.add_child(upper)
 plan=make_canvas(upper,"01  평면 / PLAN · 북쪽 ↑","plan")
 plan.point_added.connect(add_point)
 var view_box=card(upper,"02  3D · 왼쪽 드래그 Orbit / 오른쪽·가운데 드래그 Pan / 휠 Zoom")
 var container=SubViewportContainer.new()
 container.stretch=true
 container.custom_minimum_size=Vector2(400,240)
 container.size_flags_vertical=Control.SIZE_EXPAND_FILL
 container.gui_input.connect(camera_input)
 view_box.add_child(container)
 viewport=SubViewport.new()
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.physics_object_picking=false
 container.add_child(viewport)
 terrain_root=Node3D.new()
 viewport.add_child(terrain_root)
 road_node=MeshInstance3D.new()
 viewport.add_child(road_node)
 camera=Camera3D.new()
 camera.current=true
 viewport.add_child(camera)
 var sun=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-55,-25,0)
 sun.light_energy=1.1
 viewport.add_child(sun)
 var environment=WorldEnvironment.new()
 var config=Environment.new()
 config.background_mode=Environment.BG_COLOR
 config.background_color=Color("101b29")
 config.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 config.ambient_light_color=Color("b4d4dc")
 config.ambient_light_energy=0.65
 environment.environment=config
 viewport.add_child(environment)
 terrain_material=StandardMaterial3D.new()
 terrain_material.vertex_color_use_as_albedo=true
 terrain_material.roughness=0.95
 terrain_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 var road_material=StandardMaterial3D.new()
 road_material.albedo_color=Color("ffb45e")
 road_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 road_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 road_node.material_override=road_material
 var lower=HSplitContainer.new()
 lower.split_offset=0
 split.add_child(lower)
 profile=make_canvas(lower,"03  종단 / PROFILE · 제어점 부근에서 드래그하여 계획고 변경","profile")
 profile.elevation_changed.connect(edit_elevation)
 var section_box=card(lower,"04  횡단 / SECTION")
 station_slider=HSlider.new()
 station_slider.min_value=0
 station_slider.max_value=1
 station_slider.step=0.001
 station_slider.value=0.5
 station_slider.value_changed.connect(func(value):model.station=value;profile.queue_redraw();section.queue_redraw())
 section_box.add_child(station_slider)
 section=DesignCanvas.new()
 section.model=model
 section.mode="section"
 section.custom_minimum_size=Vector2(300,160)
 section.size_flags_vertical=Control.SIZE_EXPAND_FILL
 section_box.add_child(section)
 var footer=Label.new()
 footer.text="원지형 보존 / 갈색: 성토 · 청회색: 절토 / 지형 계산은 비동기 · 카메라는 독립 갱신"
 footer.add_theme_color_override("font_color",Color("94a8ba"))
 root.add_child(footer)
 dem_dialog=file_dialog(FileDialog.FILE_MODE_OPEN_FILE,"*.tif,*.tiff ; GeoTIFF",open_dem)
 save_dialog=file_dialog(FileDialog.FILE_MODE_SAVE_FILE,"*.kroadg ; MyInfraWorks Godot",save_project)
 load_dialog=file_dialog(FileDialog.FILE_MODE_OPEN_FILE,"*.kroadg ; MyInfraWorks Godot",load_project)
 message=AcceptDialog.new()
 add_child(message)

func file_dialog(mode,filter_text,action):
 var dialog=FileDialog.new()
 dialog.access=FileDialog.ACCESS_FILESYSTEM
 dialog.file_mode=mode
 dialog.filters=PackedStringArray([filter_text])
 dialog.file_selected.connect(action)
 add_child(dialog)
 return dialog

func show_error(text):
 message.dialog_text=text
 message.popup_centered(Vector2i(620,220))

func reset_terrain():
 revision+=1
 apply_queue.clear()
 dirty.clear()
 for node in terrain_root.get_children():
  terrain_root.remove_child(node)
  node.queue_free()
 tiles.clear()
 var t=model.terrain
 for y in range(ceili(float(t.Ny-1)/TILE)):
  for x in range(ceili(float(t.Nx-1)/TILE)):
   var key=Vector2i(x,y)
   var node=MeshInstance3D.new()
   node.material_override=terrain_material
   terrain_root.add_child(node)
   tiles[key]=node
   dirty[key]=true
 width_input.value=model.road_width
 offset_input.value=model.offset
 slope_input.value=model.slope
 fit_camera()
 update_road()
 redraw_canvases()
 status_note="지형 초기 메시 생성 중"

func fit_camera():
 var ext=model.extent()
 distance=max(ext.x,ext.y)*1.05
 target=Vector3(0,(model.terrain.Max-model.terrain.Min)/2,0)
 pitch=0.65
 camera.near=max(0.2,distance/100000)
 camera.far=max(10000,distance*15)
 update_camera()

func update_camera():
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
 camera.look_at(target,Vector3.UP)

func camera_input(event):
 if event is InputEventMouseMotion:
  if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
   yaw-=event.relative.x*0.006
   pitch=clamp(pitch+event.relative.y*0.006,0.08,1.50)
   update_camera()
  elif event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_MIDDLE):
   var right=camera.global_basis.x
   var up=camera.global_basis.y
   target+=(-right*event.relative.x+up*event.relative.y)*distance*0.0015
   update_camera()
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:
   distance=max(10.0,distance*0.88)
   update_camera()
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
   distance=min(max(model.extent().x,model.extent().y)*8,distance/0.88)
   update_camera()

func changed(previous):
 revision+=1
 apply_queue.clear()
 dirty.merge(Model.affected(previous,TILE),true)
 dirty.merge(Model.affected(model.snapshot(),TILE),true)
 update_road()
 redraw_canvases()

func add_point(point):
 var height=model.ground(point.x,point.y)
 if not is_finite(height):
  status_note="NoData 영역에는 노선을 추가할 수 없습니다."
  return
 if model.route.size()>0 and Vector2(model.route[-1].x-point.x,model.route[-1].z-point.y).length()<1:
  return
 var previous=model.snapshot()
 model.route.append(Vector3(point.x,height,point.y))
 changed(previous)

func edit_elevation(index,height):
 if index<0 or index>=model.route.size() or not is_finite(height):
  return
 var previous=model.snapshot()
 var point=model.route[index]
 point.y=height
 model.route[index]=point
 changed(previous)

func apply_parameters():
 var previous=model.snapshot()
 model.road_width=width_input.value
 model.offset=offset_input.value
 model.slope=slope_input.value
 changed(previous)

func remove_last():
 if model.route.is_empty():
  return
 var previous=model.snapshot()
 model.route.resize(model.route.size()-1)
 changed(previous)

func clear_route():
 var previous=model.snapshot()
 model.route=PackedVector3Array()
 changed(previous)

func redraw_canvases():
 plan.queue_redraw()
 profile.queue_redraw()
 section.queue_redraw()

func update_road():
 road_node.mesh=null
 if model.route.size()<2:
  return
 var vertices=PackedVector3Array()
 var indices=PackedInt32Array()
 var length=model.length()
 var steps=max(2,ceili(length/max(5.0,min(model.terrain.Dx,model.terrain.Dy)/4)))
 for i in range(steps+1):
  var at=model.sample(length*i/steps)
  for side in [-1,1]:
   var point=at.point+Vector3(at.normal.x*side*model.road_width/2,model.offset+0.5,at.normal.y*side*model.road_width/2)
   vertices.append(model.world(point))
  if i>0:
   var a=(i-1)*2
   indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 road_node.mesh=mesh

static func build_job(snapshot_data,keys):
 var start=Time.get_ticks_usec()
 var core=ClassDB.instantiate("KRoadCore")
 var result=[]
 for key in keys:
  var data=core.build_tile(snapshot_data.terrain,snapshot_data.route,key.x*TILE,key.y*TILE,TILE,snapshot_data.width,snapshot_data.offset,snapshot_data.slope)
  result.append({"key":key,"data":data})
 return {"items":result,"ms":(Time.get_ticks_usec()-start)/1000.0}

func _process(_delta):
 if import_worker != null and not import_worker.is_alive():
  var result=import_worker.wait_to_finish()
  import_worker=null
  open_button.disabled=false
  demo_button.disabled=false
  load_button.disabled=false
  if result.has("error"):
   show_error(result.error)
  else:
   apply_document(result.document,result.get("is_project",false))
 if worker != null and not worker.is_alive():
  var result=worker.wait_to_finish()
  worker=null
  if running_revision==revision:
   apply_queue=result.items
   apply_revision=revision
   last_build_ms=result.ms
   last_applied=apply_queue.size()
 if apply_revision==revision and not apply_queue.is_empty():
  # Bound main-thread uploads: at most two small meshes per frame.
  for i in range(min(2,apply_queue.size())):
   var item=apply_queue.pop_front()
   if not tiles.has(item.key):
    continue
   var data=item.data
   var node=tiles[item.key]
   if data.is_empty() or data.indices.is_empty():
    node.mesh=null
   else:
    var arrays=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=data.vertices
    arrays[Mesh.ARRAY_NORMAL]=data.normals
    arrays[Mesh.ARRAY_COLOR]=data.colors
    arrays[Mesh.ARRAY_INDEX]=data.indices
    var mesh=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    node.mesh=mesh
   total_mesh_updates+=1
  if apply_queue.is_empty():
   dirty.clear()
   status_note="계획지형 갱신 완료"
 if worker==null and apply_queue.is_empty() and not dirty.is_empty() and Time.get_ticks_msec()>=next_launch:
  running_revision=revision
  worker=Thread.new()
  var error=worker.start(build_job.bind(model.snapshot(),dirty.keys()))
  if error!=OK:
   worker=null
   status_note="계산 스레드를 시작하지 못했습니다."
  next_launch=Time.get_ticks_msec()+70
 metrics.text="%d FPS  |  C++ %.1f ms  |  %d / %d tiles" % [Engine.get_frames_per_second(),last_build_ms,last_applied,tiles.size()]
 status.text="%s  |  %d×%d / %.0fm  |  노선 %.0fm  |  %s" % [str(model.terrain.get("Name","")),model.terrain.Nx,model.terrain.Ny,model.terrain.Dx,model.length(),"계산/반영 중" if worker!=null or not dirty.is_empty() else status_note]

func start_import(callable):
 if import_worker!=null:
  return
 open_button.disabled=true
 demo_button.disabled=true
 load_button.disabled=true
 status_note="DEM/프로젝트 읽는 중 · 카메라는 계속 사용할 수 있습니다."
 import_worker=Thread.new()
 if import_worker.start(callable)!=OK:
  import_worker=null
  open_button.disabled=false
  demo_button.disabled=false
  load_button.disabled=false
  show_error("파일 읽기 스레드를 시작하지 못했습니다.")

func open_dem(path):
 var python_script=ProjectSettings.globalize_path("res://tools/import_dem.py")
 var destination=ProjectSettings.globalize_path("user://terrain_import.json")
 start_import(import_dem_job.bind(path,python_script,destination))

static func import_dem_job(path,script,destination):
 var output=[]
 var exit_code=OS.execute("python",PackedStringArray([script,path,destination]),output,true,false)
 if exit_code!=0:
  return {"error":"DEM 변환 실패. Python/numpy/rasterio를 확인하세요.\n"+"\n".join(output)}
 return read_document(destination,false)

static func read_document(path,is_project):
 var text=FileAccess.get_file_as_string(path)
 if FileAccess.get_open_error()!=OK:
  return {"error":"파일을 읽지 못했습니다: "+path}
 var parser=JSON.new()
 var error=parser.parse(text)
 if error!=OK or not parser.data is Dictionary:
  return {"error":"올바른 JSON 지형/프로젝트가 아닙니다."}
 return {"document":parser.data,"is_project":is_project}

func apply_document(document,is_project):
 var candidate=Model.new()
 var t=document.get("terrain",{}) if is_project else document
 var error=candidate.set_terrain(t)
 if error!="":
  show_error(error)
  return
 if is_project:
  if document.get("version",0)!=1:
   show_error("지원하지 않는 프로젝트 버전입니다.")
   return
  var points=document.get("route",[])
  for value in points:
   if not value is Array or value.size()!=3:
    show_error("올바르지 않은 노선 좌표입니다.")
    return
   var point=Vector3(float(value[0]),float(value[1]),float(value[2]))
   var ext=candidate.extent()
   if not point.is_finite() or point.x<0 or point.z<0 or point.x>ext.x or point.z>ext.y:
    show_error("노선 좌표가 지형 범위를 벗어났습니다.")
    return
   if not candidate.route.is_empty() and Vector2(point.x-candidate.route[-1].x,point.z-candidate.route[-1].z).length()<1:
    show_error("중복 노선 점입니다.")
    return
   candidate.route.append(point)
  candidate.road_width=float(document.get("width",20))
  candidate.offset=float(document.get("offset",0))
  candidate.slope=float(document.get("slope",1.5))
  if not is_finite(candidate.road_width) or not is_finite(candidate.offset) or not is_finite(candidate.slope) or candidate.road_width<1 or candidate.road_width>200 or candidate.slope<0.1 or candidate.slope>10 or abs(candidate.offset)>1000:
   show_error("프로젝트 폭/사면비/높이 보정 값이 범위를 벗어났습니다.")
   return
 model=candidate
 plan.model=model
 profile.model=model
 section.model=model
 profile.edit_index=-1
 reset_terrain()

func save_project(path):
 var t=model.terrain.duplicate()
 var values=[]
 for h in t.Heights:
  values.append(h if is_finite(h) else null)
 t.Heights=values
 var points=[]
 for point in model.route:
  points.append([point.x,point.y,point.z])
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:
  show_error("프로젝트를 저장하지 못했습니다.")
  return
 file.store_string(JSON.stringify({"version":1,"terrain":t,"route":points,"width":model.road_width,"offset":model.offset,"slope":model.slope}))
 status_note="프로젝트 저장 완료"

func load_project(path):
 start_import(read_document.bind(path,true))

func _exit_tree():
 if worker!=null:
  worker.wait_to_finish()
 if import_worker!=null:
  import_worker.wait_to_finish()

func run_smoke():
 var start=Time.get_ticks_msec()
 while worker!=null or not dirty.is_empty():
  if Time.get_ticks_msec()-start>30000:
   push_error("Initial terrain job timed out")
   get_tree().quit(1)
   return
  await get_tree().process_frame
 add_point(Vector2(300,300))
 add_point(Vector2(2000,2400))
 add_point(Vector2(4400,4400))
 for height in [180.0,190.0,200.0]:
  edit_elevation(1,height)
 var updates=total_mesh_updates
 var pivot=camera.position
 for i in range(100):
  yaw+=0.01
  update_camera()
 assert(total_mesh_updates==updates,"Camera changed terrain meshes")
 assert(camera.position!=pivot,"Orbit did not move")
 while worker!=null or not dirty.is_empty():
  if Time.get_ticks_msec()-start>30000:
   push_error("Edited terrain job timed out")
   get_tree().quit(2)
   return
  await get_tree().process_frame
 assert(model.route.size()==3)
 assert(model.route[1].y==200)
 assert(last_applied<tiles.size(),"Local route edit rebuilt every tile")
 assert(road_node.mesh!=null)
 var saved_route=model.route.duplicate()
 save_project("user://smoke.kroadg")
 var loaded=read_document("user://smoke.kroadg",true)
 apply_document(loaded.document,true)
 assert(model.route==saved_route,"Project roundtrip changed route")
 print("PASS GODOT EDITOR: async tiles, stale edit coalescing, camera independence, local rebuild, road mesh, project roundtrip")
 get_tree().quit(0)


func run_visual_test():
 var arguments=OS.get_cmdline_user_args()
 if "--visual-dem" in arguments:
  open_dem(arguments[arguments.find("--visual-dem")+1])
  while import_worker!=null:
   await get_tree().process_frame
 await get_tree().create_timer(0.5).timeout
 var extent=model.extent()
 add_point(extent*0.45)
 add_point(extent*0.50)
 add_point(extent*0.55)
 edit_elevation(1,model.ground(extent.x*0.5,extent.y*0.5)+20)
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 await get_tree().create_timer(2.0).timeout
 var updates=total_mesh_updates
 var times=[]
 var start_time=Time.get_ticks_usec()
 var last_frame=start_time
 for i in range(120):
  var motion=InputEventMouseMotion.new()
  motion.button_mask=MOUSE_BUTTON_MASK_LEFT
  motion.relative=Vector2(0.35,0)
  camera_input(motion)
  await get_tree().process_frame
  var now=Time.get_ticks_usec()
  times.append((now-last_frame)/1000.0)
  last_frame=now
 assert(updates==total_mesh_updates,"Orbit rebuilt terrain")
 times.sort()
 print("BENCH ORBIT: 120 frames / avg %.2f ms / p95 %.2f ms / zero terrain uploads" % [(last_frame-start_time)/120000.0,times[113]])
 var plot=profile.plot_rect()
 var bounds=profile.chart_bounds()
 var first_length=Vector2(model.route[1].x-model.route[0].x,model.route[1].z-model.route[0].z).length()
 var x=plot.position.x+first_length/model.length()*plot.size.x
 var press=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT
 press.pressed=true
 press.position=Vector2(x,plot.get_center().y)
 profile._gui_input(press)
 var edit_times=[]
 var edited_frame=Time.get_ticks_usec()
 for i in range(60):
  var motion=InputEventMouseMotion.new()
  motion.position=Vector2(x,plot.get_center().y+sin(i*0.1)*12)
  profile._gui_input(motion)
  yaw+=0.001
  update_camera()
  await get_tree().process_frame
  var now=Time.get_ticks_usec()
  edit_times.append((now-edited_frame)/1000.0)
  edited_frame=now
 press.pressed=false
 profile._gui_input(press)
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 edit_times.sort()
 print("BENCH PROFILE+ORBIT: 60 frames / median %.2f ms / p95 %.2f ms / %d total tiles, %d updated" % [edit_times[30],edit_times[56],tiles.size(),last_applied])
 await RenderingServer.frame_post_draw
 var args=OS.get_cmdline_user_args()
 var path=args[args.find("--visual-test")+1]
 var error=get_viewport().get_texture().get_image().save_png(path)
 print("VISUAL CAPTURE ",error," ",path)
 get_tree().quit(error)

func run_dem_smoke():
 var args=OS.get_cmdline_user_args()
 var path=args[args.find("--dem-smoke")+1]
 open_dem(path)
 var start=Time.get_ticks_msec()
 var orbit_count=0
 while import_worker!=null or worker!=null or not dirty.is_empty():
  yaw+=0.001
  update_camera()
  orbit_count+=1
  if Time.get_ticks_msec()-start>30000:
   push_error("DEM import timed out")
   get_tree().quit(3)
   return
  await get_tree().process_frame
 assert(model.terrain.Nx>2 and model.terrain.Nx<=513)
 assert(model.terrain.Name==path)
 assert(orbit_count>1,"Import blocked the frame loop")
 var ext=model.extent()
 add_point(ext*0.45)
 add_point(ext*0.50)
 var edit_started=Time.get_ticks_usec()
 for i in range(30):
  edit_elevation(1,140.0+i)
  yaw+=0.001
  update_camera()
  await get_tree().process_frame
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 assert(last_applied<tiles.size(),"DEM local edit rebuilt whole terrain")
 assert(model.route[1].y==169.0)
 print("PASS DEM EDITOR: background GeoTIFF import, %d orbit frames, %d/%d tiles for local edit, latest height 169m; edit sequence %.1fms" % [orbit_count,last_applied,tiles.size(),(Time.get_ticks_usec()-edit_started)/1000.0])
 clear_route()
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 assert(road_node.mesh==null)
 print("PASS DEM EDITOR: clear route restores affected terrain")
 get_tree().quit(0)
