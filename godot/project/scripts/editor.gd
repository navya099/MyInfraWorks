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
var save_button: Button
var pi_selector: OptionButton
var radius_input: SpinBox
var spiral_input: SpinBox
var vertical_input: SpinBox
var pvi_height_input: SpinBox
var curve_info: Window
var curve_table: TextEdit

func _ready():
 build_ui()
 model.demo()
 reset_terrain()
 if "--alignment-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_alignment_smoke")
 elif "--dem-smoke" in OS.get_cmdline_user_args():
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
 save_button=button(toolbar,"저장",func():save_dialog.popup_centered_ratio(0.65))
 load_button=button(toolbar,"프로젝트 열기",func():load_dialog.popup_centered_ratio(0.65))
 button(toolbar,"마지막 점 취소",remove_last)
 clear_button=button(toolbar,"노선 초기화",clear_route)
 button(toolbar,"화면 맞춤",fit_camera)
 button(toolbar,"측점 보기",focus_station)
 var settings=HBoxContainer.new()
 root.add_child(settings)
 width_input=number(settings,"전체 폭(m)",20,1,200,0.5)
 offset_input=number(settings,"계획고 보정(m)",0,-1000,1000,0.5)
 slope_input=number(settings,"사면 H:V",1.5,0.1,10,0.1)
 button(settings,"적용",apply_parameters)
 var hint=Label.new()
 hint.text="  직선 / 원곡선 / 클로소이드 / 포물선 종단곡선"
 hint.add_theme_color_override("font_color",Color("94a8ba"))
 settings.add_child(hint)
 status=Label.new()
 status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 root.add_child(status)
 var curves=HBoxContainer.new()
 root.add_child(curves)
 var pi_label=Label.new()
 pi_label.text="선형 제어점"
 curves.add_child(pi_label)
 pi_selector=OptionButton.new()
 pi_selector.custom_minimum_size.x=180
 pi_selector.item_selected.connect(func(_index):sync_curve_values())
 curves.add_child(pi_selector)
 radius_input=number(curves,"R(m)",0,0,100000,0.01)
 spiral_input=number(curves,"완화 Ls(m)",0,0,10000,0.01)
 vertical_input=number(curves,"종단 Lv(m)",0,0,100000,0.01)
 button(curves,"곡선 적용",apply_curves)
 pvi_height_input=number(curves,"PVI고(m)",0,-10000,10000,0.01)
 button(curves,"표고 적용",apply_pvi_height)
 button(curves,"곡선표",show_curve_table)
 curve_info=Window.new()
 curve_info.visible=false
 curve_info.title="선형 요소 / 측점 / 곡률"
 curve_info.min_size=Vector2i(800,400)
 curve_info.close_requested.connect(curve_info.hide)
 add_child(curve_info)
 curve_table=TextEdit.new()
 curve_table.editable=false
 curve_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 curve_table.add_theme_font_size_override("font_size",14)
 curve_table.add_theme_color_override("font_readonly_color",Color("dce8f2"))
 curve_info.add_child(curve_table)
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
 profile.point_selected.connect(select_pi)
 plan.point_selected.connect(select_pi)
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
 sync_alignment_controls()

func fit_camera():
 var ext=model.extent()
 distance=max(ext.x,ext.y)*1.05
 target=Vector3(0,(model.terrain.Max-model.terrain.Min)/2,0)
 pitch=0.65
 camera.near=max(0.2,distance/100000)
 camera.far=max(10000,distance*15)
 update_camera()

func focus_station():
 if model.route.size()<2:
  return
 var point=model.sample(model.length()*model.station).point
 point.y+=model.offset
 target=model.world(point)
 distance=max(200.0,model.road_width*12)
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
 var started=Time.get_ticks_usec()
 var error=model.rebuild_alignment()
 var rebuild_time=Time.get_ticks_usec()-started
 if error!="":
  model.restore(previous)
  sync_alignment_controls()
  show_error("곡선 조건을 적용할 수 없습니다.\n"+error)
  return false
 var horizontal_changed=previous.pi_route.size()!=model.route.size() or previous.radii!=model.radii or previous.spirals!=model.spirals or previous.vertical_lengths!=model.vertical_lengths
 if not horizontal_changed:
  for i in range(model.route.size()):
   if previous.pi_route[i].x!=model.route[i].x or previous.pi_route[i].z!=model.route[i].z:
    horizontal_changed=true
    break
 if horizontal_changed:
  sync_alignment_controls()
 revision+=1
 apply_queue.clear()
 dirty.merge(Model.affected(previous,TILE),true)
 dirty.merge(Model.affected(model.snapshot(),TILE),true)
 update_road()
 redraw_canvases()
 if "--profile-phases" in OS.get_cmdline_user_args():
  print("EDIT PHASES: rebuild %.2f / all %.2f ms" % [rebuild_time/1000.0,(Time.get_ticks_usec()-started)/1000.0])
 return true

func add_point(point):
 var height=model.ground(point.x,point.y)
 if not is_finite(height):
  status_note="NoData 영역에는 노선을 추가할 수 없습니다."
  return
 if model.route.size()>0 and Vector2(model.route[-1].x-point.x,model.route[-1].z-point.y).length()<1:
  return
 var previous=model.snapshot()
 model.route.append(Vector3(point.x,height,point.y))
 if changed(previous):
  select_pi(max(0,model.route.size()-2))

func edit_elevation(index,height):
 if index<0 or index>=model.route.size() or not is_finite(height):
  return
 var previous=model.snapshot()
 var point=model.route[index]
 point.y=height
 model.route[index]=point
 if changed(previous) and pi_selector.selected==index:
  pvi_height_input.value=model.route[index].y

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
 var extent=model.extent()
 var data=model.alignment.ribbon(model.road_width,model.offset,model.terrain.Min,extent.x/2,extent.y/2)
 if data.is_empty():
  return
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=data.vertices
 arrays[Mesh.ARRAY_INDEX]=data.indices
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 road_node.mesh=mesh

static func build_job(snapshot_data,keys):
 var start=Time.get_ticks_usec()
 var core=ClassDB.instantiate("KRoadCore")
 var result=[]
 core.prepare_corridor(snapshot_data.route,snapshot_data.width,snapshot_data.offset,snapshot_data.slope,snapshot_data.terrain.Min,snapshot_data.terrain.Max,max(snapshot_data.terrain.Dx,snapshot_data.terrain.Dy)*2)
 for key in keys:
  var data=core.build_render_tile(snapshot_data.terrain,snapshot_data.source,snapshot_data.route,key.x*TILE,key.y*TILE,TILE,snapshot_data.width,snapshot_data.offset,snapshot_data.slope,snapshot_data.refinement)
  result.append({"key":key,"data":data})
 return {"items":result,"ms":(Time.get_ticks_usec()-start)/1000.0}

func _process(_delta):
 if import_worker != null and not import_worker.is_alive():
  var result=import_worker.wait_to_finish()
  import_worker=null
  open_button.disabled=false
  save_button.disabled=false
  demo_button.disabled=false
  load_button.disabled=false
  if result.has("error"):
   show_error(result.error)
  elif result.get("saved",false):
   status_note="프로젝트 저장 완료"
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
 status.text="%s  |  계산 %.1fm / 화면 %.0fm / 국부 ×%d  |  노선 %.0fm  |  %s" % [str(model.terrain.get("Name","")).get_file(),model.source.Dx,model.terrain.Dx,model.refinement(),model.length(),"계산/반영 중" if worker!=null or not dirty.is_empty() else status_note]

func start_import(callable):
 if import_worker!=null:
  return
 open_button.disabled=true
 save_button.disabled=true
 demo_button.disabled=true
 load_button.disabled=true
 status_note="DEM/프로젝트 읽는 중 · 카메라는 계속 사용할 수 있습니다."
 import_worker=Thread.new()
 if import_worker.start(callable)!=OK:
  import_worker=null
  open_button.disabled=false
  save_button.disabled=false
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
 var result=read_document(destination,false)
 if result.has("temporary_binary"):
  DirAccess.remove_absolute(result.temporary_binary)
  result.erase("temporary_binary")
 return result

static func read_document(path,is_project):
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:
  return {"error":"파일을 읽지 못했습니다: "+path}
 if is_project and file.get_length()>=7 and file.get_buffer(7).get_string_from_ascii()=="KROAD2\n":
  var document=file.get_var(false)
  if not document is Dictionary:
   return {"error":"프로젝트 바이너리가 올바르지 않습니다."}
  return {"document":document,"is_project":true}
 file.seek(0)
 var parser=JSON.new()
 if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary:
  return {"error":"올바른 지형/프로젝트 파일이 아닙니다."}
 var document=parser.data
 var result={"document":document,"is_project":is_project}
 if not is_project and document.has("SourceFile"):
  var name=str(document.SourceFile)
  if name!=name.get_file() or document.get("SourceEncoding","")!="float32-le" or not document.get("Source",null) is Dictionary:
   return {"error":"계산용 높이 파일 참조가 올바르지 않습니다."}
  var source=document.Source
  var count=int(source.get("Nx",0))*int(source.get("Ny",0))
  var binary_path=path.get_base_dir().path_join(name)
  var binary=FileAccess.open(binary_path,FileAccess.READ)
  if count<4 or count>64000000 or binary==null or binary.get_length()!=count*4:
   return {"error":"계산용 높이 파일이 없거나 크기가 일치하지 않습니다."}
  source.Heights=binary.get_buffer(count*4).to_float32_array()
  binary.close()
  result.temporary_binary=binary_path
 return result

func apply_document(document,is_project):
 var candidate=Model.new()
 var t=document.get("terrain",{}) if is_project else document
 var error=candidate.set_terrain(t,document.get("source",{}) if is_project else {})
 if error!="":
  show_error(error)
  return
 if is_project:
  if document.get("version",0) not in [1,2,3]:
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
 var curve_options=document.get("alignment",{}) if is_project else {}
 if not curve_options is Dictionary:
  show_error("선형 매개변수 형식이 올바르지 않습니다.")
  return
 if not curve_options.is_empty():
  for key in ["radii","spirals","vertical_lengths"]:
   var values=curve_options.get(key,null)
   if not values is PackedFloat64Array and not values is Array:
    show_error("곡선 매개변수 배열이 올바르지 않습니다.")
    return
   for value in values:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
     show_error("곡선 매개변수에는 유한한 숫자만 사용할 수 있습니다.")
     return
   if values.size()!=candidate.route.size():
    show_error("곡선 매개변수와 제어점 수가 다릅니다.")
    return
  candidate.radii=PackedFloat64Array(curve_options.radii)
  candidate.spirals=PackedFloat64Array(curve_options.spirals)
  candidate.vertical_lengths=PackedFloat64Array(curve_options.vertical_lengths)
 var alignment_error=candidate.rebuild_alignment()
 if alignment_error!="":
  show_error("저장된 선형이 올바르지 않습니다.\n"+alignment_error)
  return
 model=candidate
 plan.model=model
 profile.model=model
 section.model=model
 profile.edit_index=-1
 reset_terrain()

func project_document():
 var points=[]
 for point in model.route:
  points.append([point.x,point.y,point.z])
 return {"version":3,"alignment":{"radii":model.radii.duplicate(),"spirals":model.spirals.duplicate(),"vertical_lengths":model.vertical_lengths.duplicate()},"terrain":model.terrain.duplicate(),"source":model.source.duplicate(),"route":points,"width":model.road_width,"offset":model.offset,"slope":model.slope}

static func save_job(path,document):
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  return {"error":"프로젝트를 저장하지 못했습니다."}
 file.store_buffer("KROAD2\n".to_ascii_buffer())
 file.store_var(document,false)
 file.flush()
 var write_error=file.get_error()
 file.close()
 if write_error!=OK:
  DirAccess.remove_absolute(temporary)
  return {"error":"프로젝트 쓰기에 실패했습니다. 기존 파일은 보존됩니다."}
 if DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  return {"error":"프로젝트 파일 교체에 실패했습니다. 기존 파일은 보존됩니다."}
 return {"saved":true}

func save_project(path):
 start_import(save_job.bind(path,project_document()))

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
 while import_worker!=null:
  await get_tree().process_frame
 var loaded=read_document("user://smoke.kroadg",true)
 apply_document(loaded.document,true)
 assert(model.route==saved_route,"Project roundtrip changed route")
 assert(loaded.document.version==3,"New projects must store alignment parameters")
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
 if "--curve-demo" in arguments:
  clear_route()
  add_point(Vector2(extent.x*0.15,extent.y*0.60))
  add_point(Vector2(extent.x*0.55,extent.y*0.60))
  add_point(Vector2(extent.x*0.55,extent.y*0.20))
  select_pi(1)
  radius_input.value=min(extent.x,extent.y)*0.13
  spiral_input.value=min(extent.x,extent.y)*0.03
  vertical_input.value=min(extent.x,extent.y)*0.12
  apply_curves()
 if "--long-curve" in arguments:
  clear_route()
  var probe=ClassDB.instantiate("KRoadAlignment")
  var points=PackedVector3Array([Vector3(0,100,0),Vector3(50000,100,0),Vector3(50000,100,-50000)])
  var initial=probe.configure(points,PackedFloat64Array([0,12000,0]),PackedFloat64Array([0,1000,0]),PackedFloat64Array([0,4000,0]))
  var leg=50000+(98235-initial.length)/2
  var origin=Vector2(extent.x*0.05,extent.y*0.75)
  add_point(origin)
  add_point(origin+Vector2(leg,0))
  add_point(origin+Vector2(leg,-leg))
  select_pi(1)
  radius_input.value=12000
  spiral_input.value=1000
  vertical_input.value=4000
  apply_curves()
  print("LONG ALIGNMENT: %.3fm / %d corridor points" % [model.length(),model.centerline.size()])
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
 focus_station()
 if "--table-demo" in arguments:
  show_curve_table()
  await get_tree().process_frame
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
 # Full-resolution heights and NoData must survive project save without sidecars.
 var source_count=model.source.Heights.size()
 var source_height=model.ground(ext.x*0.5,ext.y*0.5)
 save_project("user://source_roundtrip.kroadg")
 while import_worker!=null:
  await get_tree().process_frame
 var saved=read_document("user://source_roundtrip.kroadg",true)
 assert(saved.document.version==3)
 assert(saved.document.source.Heights is PackedFloat32Array)
 apply_document(saved.document,true)
 assert(model.source.Heights.size()==source_count)
 assert(abs(model.ground(ext.x*0.5,ext.y*0.5)-source_height)<0.0001)
 print("PASS DEM PROJECT: float32 source embedded and restored without TIFF/cache")
 clear_route()
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 assert(road_node.mesh==null)
 print("PASS DEM EDITOR: clear route restores affected terrain")
 get_tree().quit(0)

func sync_alignment_controls():
 var selected=pi_selector.selected
 pi_selector.clear()
 for i in range(model.route.size()):
  pi_selector.add_item("PI %d / 대응 %.1f" % [i+1,model.pi_station(i)])
 if model.route.size()>0:
  pi_selector.select(clampi(selected if selected>=0 else 1,0,model.route.size()-1))
 sync_curve_values()

func sync_curve_values():
 var index=pi_selector.selected
 var active=index>0 and index<model.route.size()-1
 pvi_height_input.editable=index>=0
 if index>=0 and index<model.route.size():
  pvi_height_input.value=model.route[index].y
 radius_input.editable=active
 spiral_input.editable=active
 vertical_input.editable=active
 if index>=0 and index<model.radii.size():
  radius_input.value=model.radii[index]
  spiral_input.value=model.spirals[index]
  vertical_input.value=model.vertical_lengths[index]
 else:
  radius_input.value=0
  spiral_input.value=0
  vertical_input.value=0

func select_pi(index):
 if index>=0 and index<pi_selector.item_count:
  pi_selector.select(index)
  sync_curve_values()

func apply_pvi_height():
 var index=pi_selector.selected
 if index>=0 and index<model.route.size():
  edit_elevation(index,pvi_height_input.value)

func apply_curves():
 var index=pi_selector.selected
 if index<=0 or index>=model.route.size()-1:
  show_error("시점/종점 사이의 내부 제어점을 선택하세요.")
  return
 var previous=model.snapshot()
 model.radii[index]=radius_input.value
 model.spirals[index]=spiral_input.value
 model.vertical_lengths[index]=vertical_input.value
 changed(previous)

func show_curve_table():
 var text="곡선 길이 기준 측점 / R=0: 직선 연결 / Ls: 각 진입·진출 완화곡선 길이\n"
 text+="종단 제어점은 평면 PI의 곡선 중앙 대응 측점에 배치됩니다.\n\n"
 for element in model.alignment_data.elements:
  text+="STA %.3f → %.3f  |  %s  |  L=%.3fm  |  κ %.7f → %.7f\n" % [element.station,element.station+element.length,element.type,element.length,element.k0,element.k1]
 text+="\n총 길이: %.3fm\n" % model.length()
 for i in range(1,model.route.size()-1):
  var station=model.pi_station(i)
  var g1=100*(model.route[i].y-model.route[i-1].y)/(station-model.pi_station(i-1))
  var g2=100*(model.route[i+1].y-model.route[i].y)/(model.pi_station(i+1)-station)
  var k="∞" if abs(g2-g1)<0.000000001 else "%.3f m/%%" % (model.vertical_lengths[i]/abs(g2-g1))
  text+="PVI %d: STA %.3f / 제어고 %.3f / Lv %.3f / 시작 %.3f / 끝 %.3f / g %.4f%% → %.4f%% / K %s\n" % [i+1,station,model.route[i].y,model.vertical_lengths[i],station-model.vertical_lengths[i]/2,station+model.vertical_lengths[i]/2,g1,g2,k]
 curve_table.text=text
 curve_info.popup_centered(Vector2i(1000,600))

func run_alignment_smoke():
 var started=Time.get_ticks_msec()
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 add_point(Vector2(300,3000))
 add_point(Vector2(3000,3000))
 add_point(Vector2(3000,400))
 select_pi(1)
 radius_input.value=500
 spiral_input.value=100
 vertical_input.value=400
 apply_curves()
 var before=model.length()
 assert(model.alignment_data.elements.size()==5)
 assert(model.centerline.size()>100)
 var pvi=model.pi_station(1)
 var old_elevation=model.route[1].y
 pvi_height_input.value=old_elevation+15
 apply_pvi_height()
 assert(model.sample(pvi).point.y!=model.route[1].y,"Vertical curve should not pass through its PVI")
 assert(abs(model.length()-before)<0.0001,"Vertical edit changed horizontal length")
 while worker!=null or not dirty.is_empty():
  if Time.get_ticks_msec()-started>30000:
   push_error("Curve editor timed out")
   get_tree().quit(1)
   return
  await get_tree().process_frame
 var saved_points=model.route.duplicate()
 var saved_polyline=model.centerline.duplicate()
 save_project("user://alignment_roundtrip.kroadg")
 while import_worker!=null:
  await get_tree().process_frame
 var stored=read_document("user://alignment_roundtrip.kroadg",true)
 assert(stored.document.version==3)
 apply_document(stored.document,true)
 assert(model.route==saved_points and model.centerline==saved_polyline)
 assert(model.radii[1]==500 and model.spirals[1]==100 and model.vertical_lengths[1]==400)
 show_curve_table()
 assert("spiral_in" in curve_table.text)
 curve_info.hide()
 print("PASS ALIGNMENT EDITOR: R/Ls/Lv controls, exact chainage, PVI parabola, async terrain, v3 curve roundtrip")
 get_tree().quit(0)
