extends Control
const EarthworkReport=preload("res://scripts/earthwork_report.gd")
var earthwork_report
const StationTable=preload("res://scripts/station_table.gd")
var station_table
const ReviewWindow=preload("res://scripts/review_window.gd")
var review_window
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
var station_node: MeshInstance3D
var station_input: SpinBox
var station_step: SpinBox
var station_info: Label
var station_previous: Button
var station_next: Button
var terrain_material: StandardMaterial3D
var status: Label
var metrics: Label
var width_input: SpinBox
var offset_input: SpinBox
var slope_input: SpinBox
var cut_slope_input: SpinBox
var left_fall_input: SpinBox
var right_fall_input: SpinBox
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
var pi_add_button: Button
var radius_input: SpinBox
var spiral_input: SpinBox
var vertical_input: SpinBox
var pvi_height_input: SpinBox
var pvi_selector: OptionButton
var pvi_station_input: SpinBox
var curve_info: Window
var curve_table: TextEdit
var x_input: SpinBox
var y_input: SpinBox
var coordinate_info: Label
var insert_dialog: ConfirmationDialog
var insert_x: SpinBox
var insert_y: SpinBox
var insert_after=-1
var insert_button: Button
var delete_pi_button: Button
var undo_button: Button
var redo_button: Button
var undo_stack=[]
var redo_stack=[]
var gesture_state={}
const HISTORY_LIMIT=100

func _ready():
 build_ui()
 get_window().focus_exited.connect(cancel_gesture)
 model.demo()
 reset_terrain()
 if "--station-table-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_station_table_smoke")
 elif "--station-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_station_smoke")
 elif "--pi-add-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_pi_add_smoke")
 elif "--navigation-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_navigation_smoke")
 elif "--slopes-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_slopes_smoke")
 elif "--section-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_section_smoke")
 elif "--crossfall-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_crossfall_smoke")
 elif "--review-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_review_smoke")
 elif "--topology-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_topology_smoke")
 elif "--earthwork-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_earthwork_smoke")
 elif "--pvi-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_pvi_smoke")
 elif "--edit-smoke" in OS.get_cmdline_user_args():
  call_deferred("run_edit_smoke")
 elif "--alignment-smoke" in OS.get_cmdline_user_args():
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
 if mode in ["plan","profile"]:
  var tools_row=HBoxContainer.new()
  box.add_child(tools_row)
  if mode=="plan":
   pi_add_button=Button.new()
   pi_add_button.text="PI 추가"
   pi_add_button.toggle_mode=true
   pi_add_button.tooltip_text="추가 도구 선택: 클릭으로 PI 연속 추가 / Esc로 종료"
   pi_add_button.toggled.connect(set_pi_add_mode)
   tools_row.add_child(pi_add_button)
  button(tools_row,"확대",func():canvas.zoom_navigation(canvas.size/2.0,0.8))
  button(tools_row,"축소",func():canvas.zoom_navigation(canvas.size/2.0,1.25))
  button(tools_row,"전체 맞춤",func():cancel_gesture();canvas.fit_navigation())
  button(tools_row,"측점 맞춤",func():cancel_gesture();canvas.focus_navigation())
  var hint=Label.new()
  hint.text="휠 확대 · 가운데 이동" if mode=="plan" else "휠 확대 · Shift 가로 · Ctrl 세로 · 가운데 이동"
  hint.add_theme_font_size_override("font_size",12)
  tools_row.add_child(hint)
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
 button(toolbar,"토공량",func():earthwork_report.popup_centered(Vector2i(1200,720)))
 button(toolbar,"측점표",func():station_table.popup_centered(Vector2i(1250,650)))
 button(toolbar,"설계 검토",func():review_window.popup_centered(Vector2i(1250,650)))
 undo_button=button(toolbar,"실행 취소",undo_edit)
 redo_button=button(toolbar,"다시 실행",redo_edit)
 undo_button.tooltip_text="설계 실행 취소 (Ctrl+Z)"
 redo_button.tooltip_text="설계 다시 실행 (Ctrl+Y / Ctrl+Shift+Z)"
 var settings=HBoxContainer.new()
 root.add_child(settings)
 width_input=number(settings,"전체 폭(m)",20,1,200,0.5)
 offset_input=number(settings,"계획고 보정(m)",0,-1000,1000,0.5)
 slope_input=number(settings,"성토 H:V",1.5,0.1,10,0.1)
 cut_slope_input=number(settings,"절토 H:V",1.5,0.1,10,0.1)
 left_fall_input=number(settings,"좌측 하향(%)",0,-12,12,0.1)
 right_fall_input=number(settings,"우측 하향(%)",0,-12,12,0.1)
 left_fall_input.tooltip_text="진행 방향 기준 좌측. 양수: 중심에서 바깥으로 낮아짐 / 음수: 높아짐"
 right_fall_input.tooltip_text="진행 방향 기준 우측. 양수: 중심에서 바깥으로 낮아짐 / 음수: 높아짐"
 button(settings,"적용",apply_parameters)
 var hint=Label.new()
 hint.text="  양수: 바깥 하향"
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
 pi_selector.item_selected.connect(func(_index):set_pi_add_mode(false);cancel_pi_insertion();sync_curve_values())
 curves.add_child(pi_selector)
 radius_input=number(curves,"R(m)",0,0,100000,0.01)
 spiral_input=number(curves,"완화 Ls(m)",0,0,10000,0.01)
 button(curves,"곡선 적용",apply_curves)
 button(curves,"곡선표",show_curve_table)
 insert_button=button(curves,"PI 뒤에 삽입…",show_pi_insert)
 delete_pi_button=button(curves,"PI 삭제",delete_selected_pi)
 insert_button.tooltip_text="선택 PI와 다음 PI 사이에 새 PI 삽입 · 새 점 R/Ls=0"
 delete_pi_button.tooltip_text="선택한 내부 PI와 그 점의 R/Ls 삭제 · Ctrl+Z로 복원"
 insert_dialog=ConfirmationDialog.new()
 insert_dialog.title="선택 PI 뒤에 중간점 삽입"
 insert_dialog.ok_button_text="입력 좌표 삽입"
 insert_dialog.cancel_button_text="취소"
 insert_dialog.dialog_hide_on_ok=false
 var insert_body=VBoxContainer.new()
 insert_dialog.add_child(insert_body)
 var insert_hint=Label.new()
 insert_hint.text="로컬 좌표(m) · 새 PI의 R/Ls=0 · 기존 PI의 R/Ls와 내부 PVI 유지"
 insert_body.add_child(insert_hint)
 var insert_row=HBoxContainer.new()
 insert_body.add_child(insert_row)
 insert_x=number(insert_row,"동 X",0,0,1000000,0.01)
 insert_y=number(insert_row,"남 Y",0,0,1000000,0.01)
 insert_dialog.confirmed.connect(func():
  if insert_pi(insert_after,Vector2(insert_x.value,insert_y.value)):insert_dialog.hide())
 insert_dialog.add_button("평면에서 지정",false,"pick")
 insert_dialog.custom_action.connect(func(action):
  if action=="pick":
   insert_dialog.hide()
   plan.insert_after=insert_after
   plan.queue_redraw()
   status_note="PI %d 뒤 삽입: 평면 클릭 / Esc 또는 우클릭 취소" % (insert_after+1))
 insert_dialog.canceled.connect(cancel_pi_insertion)
 add_child(insert_dialog)
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
 var pvi_row=HBoxContainer.new()
 root.add_child(pvi_row)
 var pvi_label=Label.new()
 pvi_label.text="독립 종단 PVI"
 pvi_row.add_child(pvi_label)
 pvi_selector=OptionButton.new()
 pvi_selector.custom_minimum_size.x=110
 pvi_selector.item_selected.connect(func(_index):sync_pvi_values())
 pvi_row.add_child(pvi_selector)
 pvi_station_input=number(pvi_row,"측점(m)",0,0,10000000,0.01)
 pvi_height_input=number(pvi_row,"제어고(m)",0,-10000,10000,0.01)
 vertical_input=number(pvi_row,"Lv(m)",0,0,100000,0.01)
 button(pvi_row,"PVI 적용",apply_pvi_values)
 button(pvi_row,"현재 측점에 추가",add_pvi_at_station)
 button(pvi_row,"PVI 삭제",delete_selected_pvi)
 var coordinates=HBoxContainer.new()
 root.add_child(coordinates)
 x_input=number(coordinates,"로컬 동 X(m)",0,0,1000000,0.01)
 y_input=number(coordinates,"로컬 남 Y(m)",0,0,1000000,0.01)
 button(coordinates,"PI 위치 적용",apply_pi_position)
 coordinate_info=Label.new()
 coordinate_info.add_theme_color_override("font_color",Color("94a8ba"))
 coordinate_info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 coordinate_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 coordinates.add_child(coordinate_info)
 var split=VSplitContainer.new()
 split.size_flags_vertical=Control.SIZE_EXPAND_FILL
 split.split_offset=460
 root.add_child(split)
 var upper=HSplitContainer.new()
 upper.split_offset=0
 split.add_child(upper)
 plan=make_canvas(upper,"01  평면 / PLAN · 북쪽 ↑","plan")
 plan.point_added.connect(add_point)
 plan.addition_cancelled.connect(func():set_pi_add_mode(false))
 plan.point_inserted.connect(func(index,point):insert_pi(index,point))
 plan.insertion_cancelled.connect(cancel_pi_insertion)
 plan.point_moved.connect(move_pi)
 plan.gesture_started.connect(begin_gesture)
 plan.gesture_finished.connect(end_gesture)
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
 station_node=MeshInstance3D.new()
 var station_material=StandardMaterial3D.new()
 station_material.albedo_color=Color("7eeaff")
 station_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 station_node.material_override=station_material
 viewport.add_child(station_node)
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
 profile=make_canvas(lower,"03  종단 / PROFILE · PVI 드래그: 측점·표고 / Shift+클릭: 추가","profile")
 profile.elevation_changed.connect(edit_elevation)
 profile.pvi_moved.connect(move_pvi)
 profile.pvi_added.connect(add_pvi)
 profile.station_selected.connect(func(value):station_slider.value=value)
 profile.gesture_started.connect(begin_gesture)
 profile.gesture_finished.connect(end_gesture)
 profile.point_selected.connect(select_pvi)
 plan.point_selected.connect(select_pi)
 var section_box=card(lower,"04  횡단 / SECTION")
 station_slider=HSlider.new()
 station_slider.min_value=0
 station_slider.max_value=1
 station_slider.step=0 # Preserve exact table stations on long alignments.
 station_slider.value=0.5
 station_slider.value_changed.connect(func(value):set_station_distance(value*model.length()))
 var station_row=HBoxContainer.new()
 section_box.add_child(station_row)
 station_input=number(station_row,"STA(m)",0,0,0,0.001)
 station_input.value_changed.connect(set_station_distance)
 station_step=number(station_row,"이동(m)",20,0.001,10000,0.001)
 station_previous=button(station_row,"◀",func():set_station_distance(station_input.value-station_step.value))
 station_next=button(station_row,"▶",func():set_station_distance(station_input.value+station_step.value))
 station_info=Label.new()
 station_info.add_theme_font_size_override("font_size",12)
 station_info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 station_info.tooltip_text="계획−지반은 중심선 한 점의 높이 차이이며 토공량이 아닙니다."
 section_box.add_child(station_info)
 section_box.add_child(station_slider)
 section=DesignCanvas.new()
 section.model=model
 section.mode="section"
 section.custom_minimum_size=Vector2(300,160)
 section.size_flags_vertical=Control.SIZE_EXPAND_FILL
 section_box.add_child(section)
 var section_tools=HBoxContainer.new()
 section_box.add_child(section_tools)
 button(section_tools,"도로 확대",func():section.fit_section(true))
 button(section_tools,"전체 맞춤",func():section.fit_section(false))
 var section_hint=Label.new()
 section_hint.text="H:V 1:1 고정 · 휠: 양축 확대 / 드래그: 이동"
 section_hint.add_theme_font_size_override("font_size",12)
 section_tools.add_child(section_hint)
 var footer=Label.new()
 footer.text="원지형 보존 / 갈색: 성토 · 청회색: 절토 / 지형 계산은 비동기 · 카메라는 독립 갱신"
 footer.add_theme_color_override("font_color",Color("94a8ba"))
 root.add_child(footer)
 dem_dialog=file_dialog(FileDialog.FILE_MODE_OPEN_FILE,"*.tif,*.tiff ; GeoTIFF",open_dem)
 save_dialog=file_dialog(FileDialog.FILE_MODE_SAVE_FILE,"*.kroadg ; MyInfraWorks Godot",save_project)
 load_dialog=file_dialog(FileDialog.FILE_MODE_OPEN_FILE,"*.kroadg ; MyInfraWorks Godot",load_project)
 earthwork_report=EarthworkReport.new()
 earthwork_report.visible=false
 earthwork_report.snapshot_provider=func():return {"snapshot":model.snapshot(),"revision":revision,"length":model.length()}
 earthwork_report.revision_provider=func():return revision
 earthwork_report.station_selected.connect(func(station):
  if model.length()>0:station_slider.value=station/model.length())
 add_child(earthwork_report)
 station_table=StationTable.new()
 station_table.visible=false
 station_table.snapshot_provider=func():return {"snapshot":model.snapshot(),"revision":revision}
 station_table.revision_provider=func():return revision
 station_table.station_selected.connect(set_station_distance)
 add_child(station_table)
 review_window=ReviewWindow.new()
 review_window.visible=false
 review_window.snapshot_provider=func():return {"design":model.edit_state(),"revision":revision}
 review_window.revision_provider=func():return revision
 review_window.finding_selected.connect(func(row):
  if model.length()>0:station_slider.value=row.station/model.length()
  if row.kind=="PI":select_pi(row.index-1)
  elif row.kind=="PVI":select_pvi(row.index-1)
  focus_station())
 add_child(review_window)
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
 set_pi_add_mode(false)
 if plan!=null:plan.fit_navigation()
 if profile!=null:profile.fit_navigation()
 if section!=null:section.fit_section(false)
 cancel_pi_insertion()
 insert_dialog.hide()
 if earthwork_report!=null:earthwork_report.invalidate()
 if station_table!=null:station_table.invalidate()
 if review_window!=null:review_window.invalidate()
 clear_history()
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
 cut_slope_input.value=model.cut_slope
 left_fall_input.value=model.left_fall
 right_fall_input.value=model.right_fall
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

func changed(previous, record_history=true, quiet=false):
 var started=Time.get_ticks_usec()
 var error=model.rebuild_alignment()
 var rebuild_time=Time.get_ticks_usec()-started
 if error!="":
  model.restore(previous)
  sync_alignment_controls()
  sync_pvi_controls()
  if quiet:
   status_note="이동 거절: "+error
  else:
   show_error("곡선 조건을 적용할 수 없습니다.\n"+error)
  return false
 var horizontal_changed=previous.pi_route.size()!=model.route.size() or previous.radii!=model.radii or previous.spirals!=model.spirals or previous.vertical_lengths!=model.vertical_lengths
 if not horizontal_changed:
  for i in range(model.route.size()):
   if previous.pi_route[i].x!=model.route[i].x or previous.pi_route[i].z!=model.route[i].z:
    horizontal_changed=true
    break
 if horizontal_changed and gesture_state.is_empty():
  sync_alignment_controls()
 elif horizontal_changed:
  sync_curve_values()
 if gesture_state.is_empty():
  sync_pvi_controls()
 else:
  sync_pvi_values()
 if record_history and gesture_state.is_empty():
  remember_edit(previous)
 cancel_pi_insertion()
 revision+=1
 if earthwork_report!=null:earthwork_report.invalidate()
 if station_table!=null:station_table.invalidate()
 if review_window!=null:review_window.invalidate()
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
 if index>=0 and index<model.pvi_stations.size():
  return move_pvi(index,model.pvi_stations[index],height)
 return false

func apply_parameters():
 var previous=model.snapshot()
 model.road_width=width_input.value
 model.offset=offset_input.value
 model.slope=slope_input.value
 model.cut_slope=cut_slope_input.value
 model.left_fall=left_fall_input.value
 model.right_fall=right_fall_input.value
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
 refresh_station_controls()
 road_node.mesh=null
 if model.route.size()<2:
  return
 var extent=model.extent()
 var data=model.alignment.ribbon_crossfall(model.road_width,model.offset,model.terrain.Min,extent.x/2,extent.y/2,model.left_fall,model.right_fall)
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
 core.set_crossfall(snapshot_data.left_fall,snapshot_data.right_fall)
 core.set_cut_slope(snapshot_data.get("cut_slope",snapshot_data.slope))
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
  if document.get("version",0) not in [1,2,3,4,5,6]:
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
  candidate.cut_slope=candidate.slope
  if int(document.version)>=6:
   var cut_value=document.get("cut_slope",null)
   if typeof(cut_value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(cut_value)) or cut_value<0.1 or cut_value>10:
    show_error("절토 사면비는 0.1~10의 유한한 숫자여야 합니다.")
    return
   candidate.cut_slope=float(cut_value)
  if int(document.version)>=5:
   var fall=document.get("crossfall",null)
   if not fall is Dictionary:
    show_error("횡단구배 형식이 올바르지 않습니다.")
    return
   for key in ["left","right"]:
    var value=fall.get(key,null)
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or abs(float(value))>12:
     show_error("횡단구배는 -12~12%의 숫자여야 합니다.")
     return
   candidate.left_fall=float(fall.left)
   candidate.right_fall=float(fall.right)

  if not is_finite(candidate.road_width) or not is_finite(candidate.offset) or not is_finite(candidate.slope) or candidate.road_width<1 or candidate.road_width>200 or candidate.slope<0.1 or candidate.slope>10 or abs(candidate.offset)>1000:
   show_error("프로젝트 폭/사면비/높이 보정 값이 범위를 벗어났습니다.")
   return
 var curve_options=document.get("alignment",{}) if is_project else {}
 if not curve_options is Dictionary:
  show_error("선형 매개변수 형식이 올바르지 않습니다.")
  return
 if not curve_options.is_empty():
  for key in (["radii","spirals","vertical_lengths"] if int(document.get("version",0))<4 else ["radii","spirals"]):
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
  candidate.vertical_lengths=PackedFloat64Array(curve_options.get("vertical_lengths",[]))
 var alignment_error=""
 if is_project and int(document.get("version",0))<4:
  # Normalize old parameter arrays, then reproduce the original linked profile once.
  var legacy_lengths=candidate.vertical_lengths.duplicate()
  candidate.rebuild_alignment()
  candidate.vertical_lengths=legacy_lengths
  if candidate.vertical_lengths.size()!=candidate.route.size():
   candidate.vertical_lengths.resize(candidate.route.size())
   candidate.vertical_lengths.fill(0)
  alignment_error=candidate.migrate_linked_profile()
 elif is_project:
  var saved_profile=document.get("profile",{})
  if not saved_profile is Dictionary:
   show_error("독립 종단 형식이 올바르지 않습니다.")
   return
  for key in ["stations","heights","lengths"]:
   var values=saved_profile.get(key,null)
   if not values is Array and not values is PackedFloat64Array:
    show_error("PVI 배열 형식이 올바르지 않습니다.")
    return
   for value in values:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
     show_error("PVI 배열에는 유한한 숫자만 사용할 수 있습니다.")
     return
  var pvi_count=saved_profile.stations.size()
  if saved_profile.heights.size()!=pvi_count or saved_profile.lengths.size()!=pvi_count or (candidate.route.size()>=2 and pvi_count<2) or (candidate.route.size()<2 and pvi_count>0):
   show_error("PVI 배열 수 또는 시·종점 구성이 올바르지 않습니다.")
   return
  candidate.pvi_stations=PackedFloat64Array(saved_profile.stations)
  candidate.pvi_heights=PackedFloat64Array(saved_profile.heights)
  candidate.pvi_lengths=PackedFloat64Array(saved_profile.lengths)
 if alignment_error=="":
  alignment_error=candidate.rebuild_alignment()
 if alignment_error!="":
  show_error("저장된 선형이 올바르지 않습니다.\n"+alignment_error)
  return
 model=candidate
 plan.model=model
 profile.model=model
 section.model=model
 section.fit_section(false)
 profile.edit_index=-1
 reset_terrain()

func project_document():
 var points=[]
 for point in model.route:
  points.append([point.x,point.y,point.z])
 return {"version":6,"cut_slope":model.cut_slope,"crossfall":{"left":model.left_fall,"right":model.right_fall},"profile":{"stations":model.pvi_stations.duplicate(),"heights":model.pvi_heights.duplicate(),"lengths":model.pvi_lengths.duplicate()},"alignment":{"radii":model.radii.duplicate(),"spirals":model.spirals.duplicate(),"vertical_lengths":model.vertical_lengths.duplicate()},"terrain":model.terrain.duplicate(),"source":model.source.duplicate(),"route":points,"width":model.road_width,"offset":model.offset,"slope":model.slope}

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
 assert(model.pvi_heights[1]==200)
 assert(last_applied<tiles.size(),"Local route edit rebuilt every tile")
 assert(road_node.mesh!=null)
 var saved_route=model.route.duplicate()
 save_project("user://smoke.kroadg")
 while import_worker!=null:
  await get_tree().process_frame
 var loaded=read_document("user://smoke.kroadg",true)
 apply_document(loaded.document,true)
 assert(model.route==saved_route,"Project roundtrip changed route")
 assert(loaded.document.version==6,"New projects must store alignment parameters")
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
 add_pvi(model.length()*0.5,model.ground(extent.x*0.5,extent.y*0.5)+20)
 if "--curve-demo" in arguments:
  clear_route()
  add_point(Vector2(extent.x*0.15,extent.y*0.60))
  add_point(Vector2(extent.x*0.55,extent.y*0.60))
  add_point(Vector2(extent.x*0.55,extent.y*0.20))
  select_pi(1)
  radius_input.value=min(extent.x,extent.y)*0.13
  spiral_input.value=min(extent.x,extent.y)*0.03
  apply_curves()
  var mid=model.sample(model.length()*0.5).point
  add_pvi(model.length()*0.5,model.ground(mid.x,mid.z)+20)
  select_pvi(1)
  vertical_input.value=min(extent.x,extent.y)*0.12
  apply_pvi_values()
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
  apply_curves()
  var mid=model.sample(model.length()*0.5).point
  add_pvi(model.length()*0.5,model.ground(mid.x,mid.z)+20)
  select_pvi(1)
  vertical_input.value=4000
  apply_pvi_values()
  print("LONG ALIGNMENT: %.3fm / %d corridor points" % [model.length(),model.centerline.size()])
 if "--slopes-demo" in arguments:
  slope_input.value=2.0
  cut_slope_input.value=0.5
  apply_parameters()
 if "--crossfall-demo" in arguments:
  width_input.value=40
  left_fall_input.value=8
  right_fall_input.value=4
  apply_parameters()
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
 if "--pi-drag-test" in arguments:
  var map=plan.map_rect()
  var pi_point=model.route[1]
  var start_position=map.position+Vector2(pi_point.x,pi_point.z)/model.extent()*map.size
  var click=InputEventMouseButton.new()
  click.button_index=MOUSE_BUTTON_LEFT
  click.pressed=true
  click.position=start_position
  plan._gui_input(click)
  var drag_times=[]
  var previous_frame=Time.get_ticks_usec()
  for i in range(60):
   var move=InputEventMouseMotion.new()
   move.position=start_position+Vector2(sin(i*0.1)*6,cos(i*0.1)*6)
   plan._gui_input(move)
   yaw+=0.001
   update_camera()
   await get_tree().process_frame
   var now=Time.get_ticks_usec()
   drag_times.append((now-previous_frame)/1000.0)
   previous_frame=now
  click.pressed=false
  plan._gui_input(click)
  while worker!=null or not dirty.is_empty():
   await get_tree().process_frame
  drag_times.sort()
  print("BENCH PI DRAG+ORBIT: 60 frames / median %.2f ms / p95 %.2f ms / %d history entries" % [drag_times[30],drag_times[56],undo_stack.size()])
 var plot=profile.plot_rect()
 var bounds=profile.chart_bounds()
 var x=plot.position.x+model.pvi_stations[1]/model.length()*plot.size.x
 var pvi_screen_y=plot.end.y-(model.pvi_heights[1]+model.offset-bounds.x)/(bounds.y-bounds.x)*plot.size.y
 var press=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT
 press.pressed=true
 press.position=Vector2(x,pvi_screen_y)
 profile._gui_input(press)
 var edit_times=[]
 var edited_frame=Time.get_ticks_usec()
 for i in range(60):
  var motion=InputEventMouseMotion.new()
  motion.position=Vector2(x+sin(i*0.1)*2,pvi_screen_y+sin(i*0.1)*12)
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
 if "--topology-demo" in arguments:
  var a=model.route[0]
  var b=model.route[1]
  var point=Vector2((a.x+b.x)*0.5,(a.z+b.z)*0.5)-Vector2(0,extent.y*0.01)
  var started=Time.get_ticks_usec()
  assert(insert_pi(0,point,true))
  var insert_ms=(Time.get_ticks_usec()-started)/1000.0
  var inserted=model.edit_state()
  started=Time.get_ticks_usec()
  assert(delete_selected_pi(true))
  var delete_ms=(Time.get_ticks_usec()-started)/1000.0
  undo_edit()
  assert(model.edit_state()==inserted)
  print("BENCH TOPOLOGY: insert %.2f ms / delete %.2f ms / %d PI / %.3fm / undo restored" % [insert_ms,delete_ms,model.route.size(),model.length()])
  while worker!=null or not dirty.is_empty():await get_tree().process_frame
  if "--insert-dialog" in arguments:
   select_pi(0)
   show_pi_insert()
 if "--earthwork-demo" in arguments:
  earthwork_report.popup_centered(Vector2i(1200,720))
  earthwork_report.start_calculation()
  var work_start=Time.get_ticks_usec()
  var work_frames=0
  while earthwork_report.worker!=null:
   yaw+=0.0003
   update_camera()
   work_frames+=1
   await get_tree().process_frame
  if not earthwork_report.result.is_empty():
   print("BENCH EARTHWORK: %.1f ms / %d sections / %.2f%% covered / %d rendered frames" % [earthwork_report.result.ms,earthwork_report.result.sections.size(),earthwork_report.result.coverage*100,work_frames])
 if "--navigation-demo" in arguments:
  var map=plan.map_rect()
  var point=model.sample(model.length()*0.5).point
  var screen=map.position+Vector2(point.x,point.z)/model.extent()*map.size
  plan.zoom_navigation(screen,0.4)
  profile.zoom_navigation(profile.profile_screen(model.pvi_stations[1],model.pvi_heights[1]+model.offset),0.4)
  var press_pan=InputEventMouseButton.new()
  press_pan.button_index=MOUSE_BUTTON_MIDDLE
  press_pan.pressed=true
  press_pan.position=plan.size/2
  plan._gui_input(press_pan)
  press_pan.position=profile.plot_rect().get_center()
  profile._gui_input(press_pan)
  var frame_times=[]
  var previous_frame=Time.get_ticks_usec()
  var uploads_before=total_mesh_updates
  for i in range(60):
   var pan=InputEventMouseMotion.new()
   pan.button_mask=MOUSE_BUTTON_MASK_MIDDLE
   pan.relative=Vector2(sin(i*0.2)*2,cos(i*0.2))
   plan._gui_input(pan)
   profile._gui_input(pan)
   yaw+=0.001
   update_camera()
   await get_tree().process_frame
   var now=Time.get_ticks_usec()
   frame_times.append((now-previous_frame)/1000.0)
   previous_frame=now
  press_pan.pressed=false
  plan._gui_input(press_pan)
  profile._gui_input(press_pan)
  assert(total_mesh_updates==uploads_before)
  frame_times.sort()
  print("BENCH 2D NAVIGATION+ORBIT: zoomed plan/profile pan median %.2f ms / p95 %.2f ms / zero terrain uploads" % [frame_times[30],frame_times[56]])
 if "--section-zoom-demo" in arguments:
  left_fall_input.value=2
  right_fall_input.value=4
  apply_parameters()
  section.fit_section(true)
  while worker!=null or not dirty.is_empty():await get_tree().process_frame
 if "--station-table-demo" in arguments:
  station_table.popup_centered(Vector2i(1250,650))
  station_table.start_calculation()
  while station_table.worker!=null:await get_tree().process_frame
  assert(not station_table.result.is_empty())
  print("BENCH STATION TABLE: %.1f ms / %d rows / %d missing" % [station_table.result.ms,station_table.result.rows.size(),station_table.result.missing])
 if "--review-demo" in arguments:
  review_window.popup_centered(Vector2i(1250,650))
  review_window.inputs.min_r.value=1000
  review_window.inputs.min_ls.value=200
  review_window.inputs.max_grade.value=1
  review_window.inputs.min_k_crest.value=500
  assert(review_window.run_review())
  print("BENCH REVIEW: %.2f ms / %d findings / %d checks" % [review_window.result.ms,review_window.result.issues.size(),review_window.result.checks])
 if "--station-demo" in arguments:
  var samples=[]
  var previous_time=Time.get_ticks_usec()
  var uploads_before=total_mesh_updates
  var rev_before=revision
  for i in range(60):
   set_station_distance(model.length()*(0.43+sin(i*0.15)*0.01))
   yaw+=0.001
   update_camera()
   await get_tree().process_frame
   var now=Time.get_ticks_usec()
   samples.append((now-previous_time)/1000.0)
   previous_time=now
  assert(total_mesh_updates==uploads_before and revision==rev_before)
  samples.sort()
  print("BENCH STATION+ORBIT: median %.2f ms / p95 %.2f ms / zero terrain uploads and revision changes" % [samples[30],samples[56]])
  set_station_distance(model.length()*0.43)
  plan.zoom_navigation(plan.size/2,0.6)
  plan.focus_navigation()
  profile.focus_navigation()
  focus_station()
 if "--pi-add-demo" in arguments:
  set_pi_add_mode(true)
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
 assert(model.pvi_heights[1]==169.0)
 print("PASS DEM EDITOR: background GeoTIFF import, %d orbit frames, %d/%d tiles for local edit, latest height 169m; edit sequence %.1fms" % [orbit_count,last_applied,tiles.size(),(Time.get_ticks_usec()-edit_started)/1000.0])
 # Full-resolution heights and NoData must survive project save without sidecars.
 var source_count=model.source.Heights.size()
 var source_height=model.ground(ext.x*0.5,ext.y*0.5)
 save_project("user://source_roundtrip.kroadg")
 while import_worker!=null:
  await get_tree().process_frame
 var saved=read_document("user://source_roundtrip.kroadg",true)
 assert(saved.document.version==6)
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
 sync_pvi_controls()

func sync_curve_values():
 var index=pi_selector.selected
 plan.selected_index=index
 plan.queue_redraw()
 profile.queue_redraw()
 var active=index>0 and index<model.route.size()-1
 insert_button.disabled=index<0 or index>=model.route.size()-1
 delete_pi_button.disabled=not active
 x_input.editable=index>=0
 y_input.editable=index>=0
 x_input.max_value=model.extent().x
 y_input.max_value=model.extent().y
 if index>=0 and index<model.route.size():
  x_input.value=model.route[index].x
  y_input.value=model.route[index].z
  var point=model.route[index]
  if model.source.has("OriginX") and model.source.has("OriginY"):
   coordinate_info.text="EPSG:5179  E %.2f / N %.2f  |  이동 시 PVI고 유지" % [model.source.OriginX+point.x,model.source.OriginY-point.z]
  else:
   coordinate_info.text="현장 로컬 좌표 / 이동 시 PVI고 유지"
 else:
  coordinate_info.text="PI를 선택하세요."
 radius_input.editable=active
 spiral_input.editable=active
 if index>=0 and index<model.radii.size():
  radius_input.value=model.radii[index]
  spiral_input.value=model.spirals[index]
 else:
  radius_input.value=0
  spiral_input.value=0

func select_pi(index):
 if index>=0 and index<pi_selector.item_count:
  pi_selector.select(index)
  sync_curve_values()

func apply_pvi_height():
 apply_pvi_values()

func apply_curves():
 var index=pi_selector.selected
 if index<=0 or index>=model.route.size()-1:
  show_error("시점/종점 사이의 내부 제어점을 선택하세요.")
  return
 var previous=model.snapshot()
 model.radii[index]=radius_input.value
 model.spirals[index]=spiral_input.value
 changed(previous)

func show_curve_table():
 var text="곡선 길이 기준 측점 / R=0: 직선 연결 / Ls: 각 진입·진출 완화곡선 길이\n"
 text+="독립 종단 PVI / 내부 측점은 평면 PI와 독립 · 종점은 노선 끝에 고정\n\n"
 for element in model.alignment_data.elements:
  text+="STA %.3f → %.3f  |  %s  |  L=%.3fm  |  κ %.7f → %.7f\n" % [element.station,element.station+element.length,element.type,element.length,element.k0,element.k1]
 text+="\n총 길이: %.3fm\n" % model.length()
 for i in range(1,model.pvi_stations.size()-1):
  var station=model.pvi_stations[i]
  var g1=100*(model.pvi_heights[i]-model.pvi_heights[i-1])/(station-model.pvi_stations[i-1])
  var g2=100*(model.pvi_heights[i+1]-model.pvi_heights[i])/(model.pvi_stations[i+1]-station)
  var k="∞" if abs(g2-g1)<0.000000001 else "%.3f m/%%" % (model.pvi_lengths[i]/abs(g2-g1))
  text+="PVI %d: STA %.3f / 제어고 %.3f / Lv %.3f / 시작 %.3f / 끝 %.3f / g %.4f%% → %.4f%% / K %s\n" % [i+1,station,model.pvi_heights[i],model.pvi_lengths[i],station-model.pvi_lengths[i]/2,station+model.pvi_lengths[i]/2,g1,g2,k]
 curve_table.text=text
 curve_info.popup_centered(Vector2i(1000,600))

func run_alignment_smoke():
 await run_pvi_smoke()

static func compact_state(state):
 var result={}
 for key in ["pi_route","radii","spirals","vertical_lengths","pvi_stations","pvi_heights","pvi_lengths","width","offset","slope","cut_slope","left_fall","right_fall"]:
  result[key]=state[key]
 return result.duplicate(true)

func remember_edit(previous):
 var state=compact_state(previous)
 if state==model.edit_state():
  return
 undo_stack.append(state)
 if undo_stack.size()>HISTORY_LIMIT:
  undo_stack.pop_front()
 redo_stack.clear()
 refresh_history_buttons()

func refresh_history_buttons():
 undo_button.disabled=undo_stack.is_empty() or not gesture_state.is_empty()
 redo_button.disabled=redo_stack.is_empty() or not gesture_state.is_empty()

func clear_history():
 undo_stack.clear()
 redo_stack.clear()
 gesture_state.clear()
 if plan!=null:
  plan.drag_index=-1
 if profile!=null:
  profile.edit_index=-1
 if undo_button!=null:
  refresh_history_buttons()

func begin_gesture():
 if gesture_state.is_empty():
  gesture_state=model.edit_state()
 refresh_history_buttons()

func end_gesture():
 if gesture_state.is_empty():
  return
 var previous=gesture_state
 gesture_state={}
 remember_edit(previous)
 sync_alignment_controls()
 refresh_history_buttons()

func cancel_gesture():
 if gesture_state.is_empty():
  return
 var state=gesture_state
 gesture_state={}
 plan.drag_index=-1
 plan.drag_rejected=false
 profile.edit_index=-1
 apply_history_state(state)
 status_note="드래그 취소"
 refresh_history_buttons()

func apply_history_state(state):
 var previous=model.snapshot()
 model.restore(state)
 changed(previous,false,true)
 width_input.value=model.road_width
 offset_input.value=model.offset
 slope_input.value=model.slope
 cut_slope_input.value=model.cut_slope
 left_fall_input.value=model.left_fall
 right_fall_input.value=model.right_fall
 sync_alignment_controls()

func undo_edit():
 if undo_stack.is_empty() or not gesture_state.is_empty():
  return
 redo_stack.append(model.edit_state())
 apply_history_state(undo_stack.pop_back())
 status_note="실행 취소 완료"
 refresh_history_buttons()

func redo_edit():
 if redo_stack.is_empty() or not gesture_state.is_empty():
  return
 undo_stack.append(model.edit_state())
 apply_history_state(redo_stack.pop_back())
 status_note="다시 실행 완료"
 refresh_history_buttons()

func move_pi(index,point):
 if index<0 or index>=model.route.size():
  return false
 var extent=model.extent()
 if not point.is_finite() or point.x<0 or point.y<0 or point.x>extent.x or point.y>extent.y or not is_finite(model.ground(point.x,point.y)):
  status_note="이동 거절: 지형 범위 또는 NoData 영역"
  plan.drag_rejected=true
  plan.queue_redraw()
  return false
 var previous=model.snapshot()
 var old=model.route[index]
 model.route[index]=Vector3(point.x,old.y,point.y)
 var accepted=changed(previous,true,not gesture_state.is_empty())
 plan.drag_rejected=not accepted
 plan.queue_redraw()
 return accepted

func apply_pi_position():
 move_pi(pi_selector.selected,Vector2(x_input.value,y_input.value))

func _input(event):
 if not event is InputEventKey or not event.pressed or event.keycode!=KEY_ESCAPE:return
 var handled=false
 if plan.append_mode:
  set_pi_add_mode(false)
  handled=true
 if plan.insert_after>=0:
  cancel_pi_insertion()
  handled=true
 if not gesture_state.is_empty():
  cancel_gesture()
  handled=true
 if handled:get_viewport().set_input_as_handled()

func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo or not event.ctrl_pressed:
  return
 var focused=get_viewport().gui_get_focus_owner()
 if focused is LineEdit or focused is TextEdit:
  return
 if event.keycode==KEY_Z and not event.shift_pressed:
  undo_edit()
 elif event.keycode==KEY_Y or (event.keycode==KEY_Z and event.shift_pressed):
  redo_edit()
 else:
  return
 get_viewport().set_input_as_handled()

func run_edit_smoke():
 await run_pvi_smoke()

func sync_pvi_controls():
 var selected=pvi_selector.selected
 pvi_selector.clear()
 for i in range(model.pvi_stations.size()):
  pvi_selector.add_item("PVI %d" % (i+1))
 if pvi_selector.item_count>0:
  pvi_selector.select(clampi(selected if selected>=0 else 0,0,pvi_selector.item_count-1))
 sync_pvi_values()

func sync_pvi_values():
 var index=pvi_selector.selected
 var valid=index>=0 and index<model.pvi_stations.size()
 var internal=valid and index>0 and index<model.pvi_stations.size()-1
 pvi_station_input.editable=internal
 pvi_height_input.editable=valid
 vertical_input.editable=internal
 if not valid:
  pvi_station_input.value=0
  pvi_height_input.value=0
  vertical_input.value=0
 if valid:
  pvi_station_input.max_value=max(1.0,model.length())
  pvi_station_input.value=model.pvi_stations[index]
  pvi_height_input.value=model.pvi_heights[index]
  vertical_input.value=model.pvi_lengths[index]
 profile.selected_index=index
 profile.queue_redraw()

func select_pvi(index):
 if index>=0 and index<pvi_selector.item_count:
  pvi_selector.select(index)
  sync_pvi_values()

func move_pvi(index,station,height):
 if index<0 or index>=model.pvi_stations.size() or not is_finite(station) or not is_finite(height):
  return false
 var previous=model.snapshot()
 if index==0:
  station=0.0
 elif index==model.pvi_stations.size()-1:
  station=model.length()
 model.pvi_stations[index]=station
 model.pvi_heights[index]=height
 var accepted=changed(previous,true,not gesture_state.is_empty())
 profile.drag_rejected=not accepted
 profile.queue_redraw()
 return accepted

func apply_pvi_values():
 var index=pvi_selector.selected
 if index<0 or index>=model.pvi_stations.size():
  return
 var previous=model.snapshot()
 if index>0 and index<model.pvi_stations.size()-1:
  model.pvi_stations[index]=pvi_station_input.value
  model.pvi_lengths[index]=vertical_input.value
 model.pvi_heights[index]=pvi_height_input.value
 changed(previous)

func add_pvi(station,height):
 if model.route.size()<2 or not is_finite(station) or not is_finite(height):
  return false
 if station<1 or station>model.length()-1:
  status_note="PVI는 시·종점에서 1m 이상 떨어져야 합니다."
  return false
 var previous=model.snapshot()
 var index=1
 while index<model.pvi_stations.size() and model.pvi_stations[index]<station:
  index+=1
 model.pvi_stations.insert(index,station)
 model.pvi_heights.insert(index,height)
 model.pvi_lengths.insert(index,0.0)
 if changed(previous):
  select_pvi(index)
  return true
 return false

func add_pvi_at_station():
 var station=model.length()*model.station
 add_pvi(station,model.sample(station).elevation)

func delete_selected_pvi():
 var index=pvi_selector.selected
 if index<=0 or index>=model.pvi_stations.size()-1:
  status_note="시·종점 PVI는 삭제할 수 없습니다."
  return
 var previous=model.snapshot()
 model.pvi_stations.remove_at(index)
 model.pvi_heights.remove_at(index)
 model.pvi_lengths.remove_at(index)
 changed(previous)

func run_pvi_smoke():
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 add_point(Vector2(300,3000))
 add_point(Vector2(3000,3000))
 add_point(Vector2(3000,400))
 select_pi(1)
 radius_input.value=500
 spiral_input.value=100
 apply_curves()
 assert(model.pvi_stations.size()==2)
 var length=model.length()
 assert(add_pvi(length*0.35,190))
 select_pvi(1)
 vertical_input.value=300
 apply_pvi_values()
 var station=model.pvi_stations[1]
 var heights=model.pvi_heights.duplicate()
 var old_length=model.length()
 assert(move_pi(1,Vector2(3100,3100)))
 assert(model.pvi_stations[1]==station and model.pvi_heights==heights)
 assert(model.length()!=old_length)
 assert(abs(model.pvi_stations[-1]-model.length())<0.00001)
 clear_history()
 # Actual profile drag moves independent station and height in one history step.
 var before=model.edit_state()
 var rect=profile.plot_rect()
 var bounds=profile.chart_bounds()
 var screen=Vector2(rect.position.x+station/model.length()*rect.size.x,rect.end.y-(model.pvi_heights[1]+model.offset-bounds.x)/(bounds.y-bounds.x)*rect.size.y)
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=screen
 profile._gui_input(click)
 for i in range(1,5):
  var motion=InputEventMouseMotion.new()
  motion.position=screen+Vector2(i*3,-i*2)
  profile._gui_input(motion)
 click.pressed=false
 profile._gui_input(click)
 assert(model.pvi_stations[1]!=station and undo_stack.size()==1)
 var after=model.edit_state()
 undo_edit()
 assert(model.edit_state()==before)
 redo_edit()
 assert(model.edit_state()==after)
 # Endpoint station is locked, interior ordering and overlapping curves are checked.
 var endpoint=model.pvi_stations[-1]
 begin_gesture()
 assert(move_pvi(0,200,model.pvi_heights[0]+1))
 assert(model.pvi_stations[0]==0)
 cancel_gesture()
 begin_gesture()
 var valid=model.edit_state()
 assert(not move_pvi(1,-10,190))
 assert(model.edit_state()==valid)
 cancel_gesture()
 select_pvi(1)
 var count=model.pvi_stations.size()
 delete_selected_pvi()
 assert(model.pvi_stations.size()==count-1)
 undo_edit()
 assert(model.pvi_stations.size()==count)
 while worker!=null or not dirty.is_empty():
  await get_tree().process_frame
 var saved=model.edit_state()
 save_project("user://independent_pvi.kroadg")
 while import_worker!=null:
  await get_tree().process_frame
 var stored=read_document("user://independent_pvi.kroadg",true)
 assert(stored.document.version==6)
 apply_document(stored.document,true)
 assert(model.edit_state()==saved and undo_stack.is_empty())
 # Actual v3 document migration must preserve the legacy shape, not just array sizes.
 var legacy=project_document()
 legacy.version=3
 legacy.erase("profile")
 legacy.alignment.vertical_lengths=PackedFloat64Array([0,300,0])
 var reference=ClassDB.instantiate("KRoadAlignment")
 var expected=reference.configure(model.route,model.radii,model.spirals,legacy.alignment.vertical_lengths)
 assert(expected.ok)
 apply_document(legacy,true)
 for i in range(101):
  var station_v=expected.length*i/100
  assert(abs(model.sample(station_v).elevation-reference.sample(station_v).elevation)<0.0000001)
  assert(abs(model.sample(station_v).grade-reference.sample(station_v).grade)<0.0000001)
 print("PASS V3 MIGRATION: preserved 101 elevation/grade samples")
 print("PASS INDEPENDENT PVI EDITOR: add/apply, absolute stations across PI move, endpoint anchor, profile drag/history, invalid rollback, delete/undo, v6 roundtrip")
 get_tree().quit(0)

func run_earthwork_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,1000))
 add_point(Vector2(1800,1000))
 # Keep all slopes inside the demo grid, while exercising async sampling/export.
 earthwork_report.interval.value=20
 earthwork_report.reach.value=300
 earthwork_report.start_calculation()
 var count=0
 while earthwork_report.worker!=null:
  yaw+=0.001
  update_camera()
  count+=1
  await get_tree().process_frame
 assert(not earthwork_report.result.is_empty())
 assert(earthwork_report.result.sections.size()>20)
 assert(earthwork_report.export_csv("user://earthwork-smoke.csv"))
 var csv=FileAccess.open("user://earthwork-smoke.csv",FileAccess.READ)
 csv.get_buffer(3)
 var header=csv.get_csv_line()
 var row=csv.get_csv_line()
 assert(header.size()==21 and row.size()==21)
 assert(row[0]=="average_end_area")
 var old=earthwork_report.result
 edit_elevation(1,model.pvi_heights[1]+1)
 assert(earthwork_report.result.is_empty() and earthwork_report.csv_button.disabled)
 assert(not earthwork_report.export_csv("user://stale-earthwork.csv"))
 earthwork_report.start_calculation()
 edit_elevation(1,model.pvi_heights[1]+1)
 while earthwork_report.worker!=null:await get_tree().process_frame
 assert(earthwork_report.result.is_empty())
 print("PASS EARTHWORK UI: background calculation, camera response, 21-column CSV, invalidated export and stale result discard")
 get_tree().quit(0)


func cancel_pi_insertion():
 insert_after=-1
 if plan!=null:
  if plan.insert_after>=0:status_note="PI 삽입 모드 종료"
  plan.insert_after=-1
  plan.queue_redraw()

func show_pi_insert():
 if not gesture_state.is_empty():return
 set_pi_add_mode(false)
 var index=pi_selector.selected
 if index<0 or index+1>=model.route.size():return
 cancel_pi_insertion()
 insert_after=index
 var midpoint=(model.route[index]+model.route[index+1])*0.5
 insert_x.max_value=model.extent().x
 insert_y.max_value=model.extent().y
 insert_x.value=midpoint.x
 insert_y.value=midpoint.z
 insert_dialog.title="PI %d → PI %d 사이 삽입" % [index+1,index+2]
 insert_dialog.popup_centered(Vector2i(650,160))

func insert_pi(after_index,point,quiet=false):
 if not gesture_state.is_empty() or after_index<0 or after_index+1>=model.route.size():return false
 var extent=model.extent()
 if not point.is_finite() or point.x<0 or point.y<0 or point.x>extent.x or point.y>extent.y or not is_finite(model.ground(point.x,point.y)):
  status_note="삽입 거절: 지형 범위 또는 NoData 영역"
  if not quiet:show_error(status_note)
  return false
 for index in [after_index,after_index+1]:
  var p=model.route[index]
  if point.distance_to(Vector2(p.x,p.z))<1.0:
   status_note="삽입 거절: 인접 PI와 1m 이상 떨어져야 합니다."
   if not quiet:show_error(status_note)
   return false
 var previous=model.snapshot()
 var index=after_index+1
 model.route.insert(index,Vector3(point.x,model.ground(point.x,point.y),point.y))
 model.radii.insert(index,0.0)
 model.spirals.insert(index,0.0)
 model.vertical_lengths.insert(index,0.0)
 if not changed(previous,true,quiet):return false
 select_pi(index)
 status_note="PI %d 삽입 완료 · R/Ls=0 · 내부 PVI 측점·제어고 유지" % (index+1)
 return true

func delete_selected_pi(quiet=false):
 var index=pi_selector.selected
 if not gesture_state.is_empty() or index<=0 or index>=model.route.size()-1:return false
 var previous=model.snapshot()
 model.route.remove_at(index)
 model.radii.remove_at(index)
 model.spirals.remove_at(index)
 model.vertical_lengths.remove_at(index)
 if not changed(previous,true,quiet):return false
 select_pi(min(index,model.route.size()-1))
 status_note="PI %d 삭제 완료 · 실행 취소로 복원 가능" % (index+1)
 return true

func run_topology_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(300,3300))
 add_point(Vector2(2700,3300))
 add_point(Vector2(2700,600))
 add_point(Vector2(4200,600))
 select_pi(1)
 radius_input.value=300
 spiral_input.value=60
 apply_curves()
 select_pi(2)
 radius_input.value=200
 spiral_input.value=40
 apply_curves()
 assert(add_pvi(1000,195))
 clear_history()
 var original=model.edit_state()
 # A click on the armed plan inserts in the selected leg, not at the route end.
 select_pi(0)
 show_pi_insert()
 insert_dialog.custom_action.emit("pick")
 assert(plan.insert_after==0)
 earthwork_report.result={"test_marker":true}
 var rect=plan.map_rect()
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=rect.position+Vector2(1400,3200)/model.extent()*rect.size
 plan._gui_input(click)
 assert(model.route.size()==5 and pi_selector.selected==1 and plan.insert_after==-1)
 assert(earthwork_report.result.is_empty())
 assert(model.radii==PackedFloat64Array([0,0,300,200,0]))
 assert(model.spirals==PackedFloat64Array([0,0,60,40,0]))
 assert(model.pvi_stations[1]==1000 and model.pvi_heights==original.pvi_heights)
 assert(abs(model.pvi_stations[-1]-model.length())<0.00001)
 assert(undo_stack.size()==1)
 var inserted=model.edit_state()
 undo_edit()
 assert(model.edit_state()==original)
 redo_edit()
 assert(model.edit_state()==inserted)
 # Deleting a curved PI removes its own parameters, leaving the next curve intact.
 select_pi(2)
 assert(delete_selected_pi(true))
 assert(model.radii==PackedFloat64Array([0,0,200,0]))
 assert(model.spirals==PackedFloat64Array([0,0,40,0]))
 undo_edit()
 assert(model.edit_state()==inserted)
 select_pi(1)
 assert(delete_selected_pi(true))
 assert(model.edit_state()==original)
 undo_edit()
 assert(model.edit_state()==inserted)
 # Invalid insertion near an existing curve must restore all arrays and history.
 var history_count=undo_stack.size()
 var current_revision=revision
 earthwork_report.result={"test_marker":true}
 assert(not insert_pi(1,Vector2(2680,3300),true))
 assert(model.edit_state()==inserted and undo_stack.size()==history_count and revision==current_revision)
 assert(earthwork_report.result.has("test_marker"))
 assert(not insert_pi(0,Vector2(-1,100),true))
 assert(not insert_pi(0,Vector2(model.route[0].x,model.route[0].z),true))
 var old_source=model.source
 model.source=model.source.duplicate(true)
 var nx=model.source.Nx
 var h=model.source.Heights.duplicate()
 for dy in [0,1]:
  for dx in [0,1]:h[(50+dy)*nx+50+dx]=NAN
 model.source.Heights=h
 assert(not insert_pi(0,Vector2(1505,1505),true))
 model.source=old_source
 assert(model.edit_state()==inserted and undo_stack.size()==history_count)
 select_pi(0)
 assert(not delete_selected_pi(true))
 select_pi(model.route.size()-1)
 assert(not delete_selected_pi(true))
 # Esc/right-click cancel only the insertion mode; never mutate the route.
 select_pi(0)
 show_pi_insert()
 insert_dialog.custom_action.emit("pick")
 var escape=InputEventKey.new()
 escape.pressed=true
 escape.keycode=KEY_ESCAPE
 _input(escape)
 assert(plan.insert_after==-1 and model.edit_state()==inserted)
 show_pi_insert()
 insert_dialog.custom_action.emit("pick")
 click.button_index=MOUSE_BUTTON_RIGHT
 plan._gui_input(click)
 assert(plan.insert_after==-1 and model.edit_state()==inserted)
 # Numeric dialog uses the same validation and selects the new PI.
 show_pi_insert()
 insert_x.value=850
 insert_y.value=3250
 insert_dialog.confirmed.emit()
 assert(model.route.size()==6 and pi_selector.selected==1 and not insert_dialog.visible)
 assert(model.radii[3]==300 and model.radii[4]==200)
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 var saved=model.edit_state()
 save_project("user://topology.kroadg")
 while import_worker!=null:await get_tree().process_frame
 var stored=read_document("user://topology.kroadg",true)
 apply_document(stored.document,true)
 assert(model.edit_state()==saved)
 # A shortcut that would strand an independent PVI is rejected atomically.
 clear_route()
 add_point(Vector2(500,500))
 add_point(Vector2(4000,500))
 add_point(Vector2(4000,4000))
 assert(add_pvi(6000,190))
 select_pi(1)
 var detour=model.edit_state()
 history_count=undo_stack.size()
 current_revision=revision
 assert(not delete_selected_pi(true))
 assert(model.edit_state()==detour and undo_stack.size()==history_count and revision==current_revision)
 print("PASS PI TOPOLOGY: canvas/numeric insert, R/Ls association, independent PVI, delete/undo/redo, overlap/NoData/bounds/endpoint rejection, Esc/right-click, v6 roundtrip, shortening rollback")
 get_tree().quit(0)


func run_review_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(300,3300))
 add_point(Vector2(2700,3300))
 add_point(Vector2(2700,600))
 select_pi(1)
 radius_input.value=300
 spiral_input.value=50
 apply_curves()
 assert(add_pvi(1000,220))
 select_pvi(1)
 vertical_input.value=200
 apply_pvi_values()
 review_window.inputs.min_r.value=500
 review_window.inputs.min_ls.value=100
 review_window.inputs.max_grade.value=1
 assert(review_window.run_review())
 assert(review_window.result.violations>=2)
 var item=review_window.table.get_root().get_first_child()
 var selected=-1
 while item!=null:
  var index=int(item.get_metadata(0))
  if review_window.result.issues[index].kind=="PI":
   selected=index
   item.select(0)
   review_window.table.item_selected.emit()
   break
  item=item.get_next()
 assert(selected>=0)
 var row=review_window.result.issues[selected]
 assert(pi_selector.selected==row.index-1)
 assert(abs(station_slider.value*model.length()-row.station)<0.01)
 item=review_window.table.get_root().get_first_child()
 var pvi_found=false
 while item!=null:
  var index=int(item.get_metadata(0))
  var finding=review_window.result.issues[index]
  if finding.kind=="PVI":
   item.select(0)
   review_window.table.item_selected.emit()
   assert(pvi_selector.selected==finding.index-1)
   assert(abs(model.station*model.length()-finding.station)<0.00001)
   pvi_found=true
   break
  item=item.get_next()
 assert(pvi_found)
 var exact_fraction=12345.6789/98234.998
 station_slider.value=exact_fraction
 assert(abs(station_slider.value-exact_fraction)<1e-12)
 assert(review_window.export_csv("user://review-smoke.csv"))
 var csv=FileAccess.open("user://review-smoke.csv",FileAccess.READ)
 assert(csv.get_csv_line().size()==22)
 var summary_row=csv.get_csv_line()
 assert(summary_row.size()==22 and summary_row[0]=="summary")
 var count=0
 while csv.get_position()<csv.get_length():
  var record=csv.get_csv_line()
  assert(record.size()==22 and record[0]=="finding")
  count+=1
 assert(count==review_window.result.issues.size())
 csv.close()
 # Rejected geometry does not discard a valid review; accepted edits do.
 var before=model.edit_state()
 assert(not insert_pi(0,Vector2(-10,100),true))
 assert(model.edit_state()==before and not review_window.result.is_empty())
 assert(move_pi(1,Vector2(2800,3300)))
 assert(review_window.result.is_empty() and review_window.csv_button.disabled)
 assert(not review_window.export_csv("user://stale-review.csv"))
 undo_edit()
 assert(review_window.result.is_empty())
 assert(review_window.run_review())
 review_window.inputs.min_r.value=600
 assert(review_window.result.is_empty() and review_window.csv_button.disabled)
 # A report with no issues still exports settings and summary.
 clear_route()
 add_point(Vector2(300,1000))
 add_point(Vector2(2000,1000))
 for key in review_window.inputs:review_window.inputs[key].value=0
 assert(review_window.run_review() and review_window.result.issues.is_empty())
 assert(review_window.export_csv("user://review-empty.csv"))
 csv=FileAccess.open("user://review-empty.csv",FileAccess.READ)
 assert(csv.get_csv_line().size()==22)
 assert(csv.get_csv_line()[0]=="summary")
 assert(csv.get_position()==csv.get_length())
 csv.close()
 print("PASS DESIGN REVIEW UI: row navigation, 22-column CSV, settings/revision invalidation, rejected edit preservation, empty summary export")
 get_tree().quit(0)


func run_crossfall_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,1000))
 add_point(Vector2(1800,1000))
 var flat=model.edit_state()
 var flat_center=model.sample(600).elevation
 left_fall_input.value=2
 right_fall_input.value=4
 apply_parameters()
 assert(model.left_fall==2 and model.right_fall==4 and model.sample(600).elevation==flat_center)
 assert(undo_stack[-1].left_fall==0)
 var crowned=model.edit_state()
 undo_edit()
 assert(model.edit_state()==flat and left_fall_input.value==0)
 redo_edit()
 assert(model.edit_state()==crowned and right_fall_input.value==4)
 var quantity=EarthworkReport.calculate_job(model.snapshot(),20,300,2)
 assert(quantity.ok and quantity.left_fall==2 and quantity.right_fall==4)
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 assert(road_node.mesh!=null)
 save_project("user://crossfall-v6.kroadg")
 while import_worker!=null:await get_tree().process_frame
 var saved=read_document("user://crossfall-v6.kroadg",true)
 assert(saved.document.version==6 and saved.document.crossfall.left==2)
 apply_document(saved.document,true)
 assert(model.edit_state()==crowned)
 # Bad v5 parameters must leave the current model untouched.
 var invalid=saved.document.duplicate(true)
 invalid.crossfall.right=13
 apply_document(invalid,true)
 assert(model.edit_state()==crowned)
 message.hide()
 # v4 projects must retain their flat shape regardless of current UI settings.
 var old=saved.document.duplicate(true)
 old.version=4
 old.erase("crossfall")
 apply_document(old,true)
 assert(model.left_fall==0 and model.right_fall==0)
 assert(model.pvi_heights==crowned.pvi_heights)
 var legacy=model.edit_state()
 assert(legacy.radii==crowned.radii and legacy.pi_route==crowned.pi_route)
 print("PASS CROSSFALL UI: parameters/history, shared quantities, rendered mesh, v6 roundtrip, bad v6 rollback, v4 flat migration")
 get_tree().quit(0)


func section_equal_check():
 var rect=section.plot_rect()
 var at=model.sample(model.length()*model.station)
 var centre=at.elevation+model.offset
 var transform=section.get_viewport().get_screen_transform()*section.get_global_transform_with_canvas()
 var zero=transform*section.section_screen(0,centre,centre,rect)
 var east=transform*section.section_screen(1,centre,centre,rect)
 var up=transform*section.section_screen(0,centre+1,centre,rect)
 assert(abs(zero.distance_to(east)-zero.distance_to(up))<max(0.001,zero.distance_to(east)*0.00001))

func run_section_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,1000))
 add_point(Vector2(1800,1000))
 left_fall_input.value=2
 right_fall_input.value=4
 apply_parameters()
 var before=model.edit_state()
 var rev=revision
 section.fit_section(true)
 section.queue_redraw()
 await get_tree().process_frame
 await get_tree().process_frame
 section_equal_check()
 var at=model.sample(model.length()*model.station)
 var rect=section.plot_rect()
 var centre=at.elevation+model.offset
 var a=section.section_screen(0,centre,centre,rect)
 var b=section.section_screen(-10,centre-0.2,centre,rect)
 var rendered=section.get_viewport().get_screen_transform()*section.get_global_transform_with_canvas()
 a=rendered*a
 b=rendered*b
 assert(abs(abs((b.y-a.y)/(b.x-a.x))-0.02)<0.00001)
 var old_view=section.section_view
 var wheel=InputEventMouseButton.new()
 wheel.pressed=true
 wheel.position=rect.position+rect.size*Vector2(0.37,0.65)
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 var cursor=Vector2(0.37,0.35)
 var anchor=old_view.position+cursor*old_view.size
 section._gui_input(wheel)
 assert(section.section_mode=="manual" and section.section_view.size.x<old_view.size.x and section.section_view.size.y<old_view.size.y)
 assert((section.section_view.position+cursor*section.section_view.size).distance_to(anchor)<0.00001)
 section_equal_check()
 # Modifier keys can no longer distort one axis.
 old_view=section.section_view
 wheel.shift_pressed=true
 section._gui_input(wheel)
 assert(section.section_view.size.x<old_view.size.x and section.section_view.size.y<old_view.size.y)
 section_equal_check()
 wheel.shift_pressed=false
 wheel.ctrl_pressed=true
 old_view=section.section_view
 section._gui_input(wheel)
 assert(section.section_view.size.x<old_view.size.x and section.section_view.size.y<old_view.size.y)
 section_equal_check()
 var press=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT
 press.pressed=true
 press.position=rect.get_center()
 section._gui_input(press)
 var move=InputEventMouseMotion.new()
 move.button_mask=MOUSE_BUTTON_MASK_LEFT
 move.relative=Vector2(20,10)
 old_view=section.section_view
 section._gui_input(move)
 assert(section.section_view.position!=old_view.position)
 press.pressed=false
 section._gui_input(press)
 assert(not section.section_panning)
 section_equal_check()
 # Resize preserves physical pixel scale and view centre, not independent spans.
 var old_centre=section.section_view.get_center()
 var mpp=section.section_mpp
 var resized=Rect2(Vector2(48,20),Vector2(900,260))
 section.sync_section_scale(resized)
 assert(section.section_view.get_center().distance_to(old_centre)<0.00001 and section.section_mpp==mpp)
 var pixels=section.section_pixels(resized)
 assert(abs(pixels.x/section.section_view.size.x-pixels.y/section.section_view.size.y)<0.00001)
 section.sync_section_scale(rect)
 # Also compensate unequal parent/window scaling in the rendered geometry.
 var old_scale=section.scale
 section.scale=Vector2(1.4,0.8)
 section.sync_section_scale(rect)
 section_equal_check()
 section.scale=old_scale
 section.sync_section_scale(rect)
 section.fit_section(false)
 section.queue_redraw()
 await get_tree().process_frame
 await get_tree().process_frame
 assert(section.section_mode=="full")
 section_equal_check()
 assert(model.edit_state()==before and revision==rev)
 print("PASS SECTION 1:1: physical metre equality, actual 2% slope, cursor zoom, modifiers remain equal, pan, resize/nonuniform scaling, full fit, unchanged design/revision")
 get_tree().quit(0)


func run_navigation_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,3000))
 add_point(Vector2(2400,3000))
 add_point(Vector2(3600,1000))
 assert(add_pvi(model.length()*0.5,210))
 var before=model.edit_state()
 var rev=revision
 var history=undo_stack.size()
 var uploads=total_mesh_updates
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 uploads=total_mesh_updates
 # Plan cursor anchor and middle-button pan are purely visual.
 var wheel=InputEventMouseButton.new()
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 wheel.pressed=true
 wheel.position=plan.size*Vector2(0.6,0.45)
 var old=plan.map_rect()
 var anchor=(wheel.position-old.position)/old.size
 plan._gui_input(wheel)
 var current=plan.map_rect()
 assert(current.size.x>old.size.x and current.size.y>old.size.y)
 assert(((wheel.position-current.position)/current.size).distance_to(anchor)<1e-6)
 var press=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_MIDDLE
 press.pressed=true
 press.position=plan.size/2
 plan._gui_input(press)
 var move=InputEventMouseMotion.new()
 move.button_mask=MOUSE_BUTTON_MASK_MIDDLE
 move.relative=Vector2(20,-10)
 old=plan.map_rect()
 plan._gui_input(move)
 assert((plan.map_rect().position-old.position).distance_to(move.relative)<0.0001)
 press.pressed=false
 plan._gui_input(press)
 assert(not plan.navigation_panning)
 # Profile zoom including axis modifiers preserves cursor station and elevation.
 wheel.position=profile.plot_rect().get_center()
 var world=profile.profile_world(wheel.position)
 profile._gui_input(wheel)
 assert(profile.profile_manual and profile.profile_world(wheel.position).distance_to(world)<0.000001)
 var view=profile.profile_view
 wheel.shift_pressed=true
 profile._gui_input(wheel)
 assert(profile.profile_view.size.x<view.size.x and is_equal_approx(profile.profile_view.size.y,view.size.y))
 view=profile.profile_view
 wheel.shift_pressed=false
 wheel.ctrl_pressed=true
 profile._gui_input(wheel)
 assert(is_equal_approx(profile.profile_view.size.x,view.size.x) and profile.profile_view.size.y<view.size.y)
 press.pressed=true
 press.position=profile.plot_rect().get_center()
 profile._gui_input(press)
 move.relative=Vector2(12,8)
 view=profile.profile_view
 profile._gui_input(move)
 assert(profile.profile_view.position!=view.position)
 press.pressed=false
 profile._gui_input(press)
 assert(not profile.navigation_panning)
 assert(model.edit_state()==before and revision==rev and undo_stack.size()==history)
 await get_tree().process_frame
 assert(total_mesh_updates==uploads)
 # Actual PI drag after zoom/pan uses the new map transform.
 var map=plan.map_rect()
 var pi=model.route[1]
 var screen=map.position+Vector2(pi.x,pi.z)/model.extent()*map.size
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=screen
 plan._gui_input(click)
 assert(plan.drag_index==1)
 var wheel_zoom=plan.plan_zoom
 wheel.position=screen
 plan._gui_input(wheel)
 assert(plan.plan_zoom==wheel_zoom)
 move.button_mask=MOUSE_BUTTON_MASK_LEFT
 move.position=screen+Vector2(5,-3)
 plan._gui_input(move)
 click.pressed=false
 plan._gui_input(click)
 assert(model.route[1].x!=pi.x and undo_stack.size()==history+1)
 undo_edit()
 assert(model.edit_state()==before)
 # Armed insertion still picks the intended local coordinate after navigation.
 select_pi(0)
 show_pi_insert()
 insert_dialog.custom_action.emit("pick")
 map=plan.map_rect()
 click.pressed=true
 click.position=map.position+Vector2(1500,3100)/model.extent()*map.size
 assert(plan.plan_area().has_point(click.position))
 plan._gui_input(click)
 assert(model.route.size()==before.pi_route.size()+1)
 assert(Vector2(model.route[1].x,model.route[1].z).distance_to(Vector2(1500,3100))<0.001)
 undo_edit()
 assert(model.edit_state()==before)
 # PVI hit testing, station/elevation edits and undo work in the zoomed chart.
 var station=model.pvi_stations[1]
 var height=model.pvi_heights[1]
 var pvi=profile.profile_screen(station,height+model.offset)
 assert(profile.plot_rect().has_point(pvi))
 click.pressed=true
 click.position=pvi
 profile._gui_input(click)
 assert(profile.edit_index==1)
 var target=pvi+Vector2(8,-4)
 var expected=profile.profile_world(target)
 move.position=target
 profile._gui_input(move)
 click.pressed=false
 profile._gui_input(click)
 assert(abs(model.pvi_stations[1]-expected.x)<0.00001 and abs(model.pvi_heights[1]-(expected.y-model.offset))<0.00001)
 undo_edit()
 assert(model.edit_state()==before)
 # Shift-click adds a PVI at visible station, then undo restores the design.
 click.pressed=true
 click.shift_pressed=true
 click.position=profile.profile_screen(station+100,height+1+model.offset)
 expected=profile.profile_world(click.position)
 profile._gui_input(click)
 assert(model.pvi_stations.size()==before.pvi_stations.size()+1)
 var found=false
 for s in model.pvi_stations:
  if abs(s-expected.x)<0.00001:found=true
 assert(found)
 undo_edit()
 assert(model.edit_state()==before)
 plan.fit_navigation()
 profile.fit_navigation()
 assert(plan.plan_zoom==1 and plan.plan_shift==Vector2.ZERO and not profile.profile_manual)
 var endpoint=profile.profile_screen(model.length(),model.pvi_heights[-1]+model.offset)
 assert(profile.nearest_pvi(endpoint)==model.pvi_stations.size()-1)
 print("PASS PLAN/PROFILE NAVIGATION: cursor/axis zoom, middle pan, no design/revision/mesh changes, zoomed PI/PVI edits and undo, Shift-add, full fit")
 get_tree().quit(0)


func set_pi_add_mode(active):
 if plan==null:return
 if active:
  cancel_gesture()
  cancel_pi_insertion()
  insert_dialog.hide()
 plan.append_mode=active
 plan.mouse_default_cursor_shape=Control.CURSOR_CROSS if active else Control.CURSOR_ARROW
 if pi_add_button!=null:
  pi_add_button.set_pressed_no_signal(active)
  pi_add_button.text="PI 추가 중" if active else "PI 추가"
 plan.queue_redraw()
 status_note="PI 추가 모드 · 평면 클릭으로 연속 추가 / Esc 종료" if active else "PI 선택·이동 모드"

func run_pi_add_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 assert(not plan.append_mode and not pi_add_button.button_pressed)
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 var map=plan.map_rect()
 click.position=map.position+Vector2(700,3000)/model.extent()*map.size
 var initial=model.edit_state()
 var rev=revision
 plan._gui_input(click)
 click.shift_pressed=true
 plan._gui_input(click)
 assert(model.edit_state()==initial and revision==rev)
 # Use the actual toggle, not a direct model call, to create a route.
 pi_add_button.button_pressed=true
 assert(plan.append_mode)
 click.shift_pressed=false
 plan._gui_input(click)
 map=plan.map_rect()
 click.position=map.position+Vector2(2400,3000)/model.extent()*map.size
 plan._gui_input(click)
 assert(model.route.size()==2 and plan.append_mode)
 var created=model.edit_state()
 var count=undo_stack.size()
 var escape=InputEventKey.new()
 escape.keycode=KEY_ESCAPE
 escape.pressed=true
 _input(escape)
 assert(not plan.append_mode and not pi_add_button.button_pressed and model.edit_state()==created and undo_stack.size()==count)
 click.position=map.position+Vector2(3500,2000)/model.extent()*map.size
 plan._gui_input(click)
 assert(model.edit_state()==created)
 # Existing PI selection/drag remains available in the default mode.
 var pi=model.route[1]
 click.position=map.position+Vector2(pi.x,pi.z)/model.extent()*map.size
 plan._gui_input(click)
 assert(plan.drag_index==1)
 var move=InputEventMouseMotion.new()
 move.button_mask=MOUSE_BUTTON_MASK_LEFT
 move.position=click.position+Vector2(5,-5)
 plan._gui_input(move)
 click.pressed=false
 plan._gui_input(click)
 assert(model.route[1]!=pi)
 undo_edit()
 assert(model.edit_state()==created)
 # Add and insert tools are exclusive, and navigation does not append points.
 pi_add_button.button_pressed=true
 var wheel=InputEventMouseButton.new()
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 wheel.position=plan.size/2
 wheel.pressed=true
 plan._gui_input(wheel)
 assert(plan.append_mode and model.edit_state()==created)
 select_pi(0)
 show_pi_insert()
 assert(not plan.append_mode and not pi_add_button.button_pressed)
 insert_dialog.custom_action.emit("pick")
 assert(plan.insert_after==0)
 pi_add_button.button_pressed=true
 assert(plan.append_mode and plan.insert_after==-1)
 click.pressed=true
 click.button_index=MOUSE_BUTTON_RIGHT
 plan._gui_input(click)
 assert(not plan.append_mode and model.edit_state()==created)
 pi_add_button.button_pressed=true
 pi_add_button.button_pressed=false
 assert(not plan.append_mode)
 # Reopening a project returns to selection mode, never re-arms adding.
 var document=project_document()
 pi_add_button.button_pressed=true
 apply_document(document,true)
 assert(not plan.append_mode and not pi_add_button.button_pressed and model.edit_state()==created)
 print("PASS PI ADD MODE: default/Shift no append, toggled continuous add, Esc preserves design, select/drag/undo, navigation, insert exclusivity, right cancel, reload resets mode")
 get_tree().quit(0)


func set_station_distance(distance_m):
 if not is_finite(distance_m):return
 if model.length()>0:model.station=clamp(distance_m/model.length(),0.0,1.0)
 refresh_station_controls()
 plan.queue_redraw()
 profile.queue_redraw()
 section.queue_redraw()

func refresh_station_controls():
 if station_input==null:return
 var length=model.length()
 station_input.editable=length>0
 station_slider.editable=length>0
 station_input.set_block_signals(true)
 station_input.max_value=max(0.0,length)
 station_previous.disabled=length<=0 or model.station<=0
 station_next.disabled=length<=0 or model.station>=1
 station_input.set_value_no_signal(length*model.station if length>0 else 0.0)
 station_input.set_block_signals(false)
 station_slider.set_value_no_signal(model.station)
 var info=model.inspect_station(length*model.station)
 if not info.ok:
  station_info.text="노선을 작성하면 선택 측점의 정보를 표시합니다."
  if station_node!=null:station_node.mesh=null
  return
 var ground_text="NoData" if not is_finite(info.ground) else "%.2fm" % info.ground
 var delta_text="NoData" if not is_finite(info.delta) else "%+.2fm" % info.delta
 var radius="직선" if abs(info.curvature)<1e-12 else "R %.2fm" % abs(1.0/info.curvature)
 station_info.text="계획 %.2fm / 지반 %s / 계획−지반 %s / 구배 %+.3f%% / %s" % [info.elevation,ground_text,delta_text,info.grade_pct,radius]
 var coordinates="로컬 X %.3f / 남 Y %.3f" % [info.x,info.y]
 if info.has("easting"):coordinates="EPSG:5179 E %.3f / N %.3f" % [info.easting,info.northing]
 station_info.tooltip_text=station_info.text+"\n"+coordinates+"\n계획−지반은 중심선 한 점의 높이 차이이며 토공량이 아닙니다."
 update_station_marker(info)

func update_station_marker(info):
 if station_node==null:return
 var centre=Vector3(info.x,info.elevation+0.65,info.y)
 var normal=Vector3(-sin(info.heading),0,cos(info.heading))
 var left=centre-normal*model.road_width/2.0
 var right=centre+normal*model.road_width/2.0
 left.y-=model.road_width/2.0*model.left_fall/100.0
 right.y-=model.road_width/2.0*model.right_fall/100.0
 var top=centre+Vector3(0,max(2.0,model.road_width*0.15),0)
 var vertices=PackedVector3Array([model.world(left),model.world(centre),model.world(centre),model.world(right),model.world(centre),model.world(top)])
 if is_finite(info.ground):vertices.append_array(PackedVector3Array([model.world(centre),model.world(Vector3(info.x,info.ground+0.05,info.y))]))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
 station_node.mesh=mesh


func run_station_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 assert(not station_input.editable and station_previous.disabled and station_next.disabled and station_node.mesh==null)
 add_point(Vector2(600,3000))
 add_point(Vector2(3000,3000))
 add_point(Vector2(3000,600))
 select_pi(1)
 radius_input.value=300
 spiral_input.value=50
 apply_curves()
 assert(add_pvi(1500,230))
 select_pvi(1)
 vertical_input.value=200
 apply_pvi_values()
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 var before=model.edit_state()
 var rev=revision
 var history=undo_stack.size()
 var uploads=total_mesh_updates
 var previous_target=target
 # Numeric control, stepping and slider share one exact station state.
 station_input.value=1234.567
 assert(abs(model.station*model.length()-1234.567)<1e-8)
 assert(abs(station_slider.value*model.length()-1234.567)<1e-8)
 assert(station_node.mesh!=null)
 var info=model.inspect_station(1234.567)
 assert(info.ok and abs(info.station-1234.567)<1e-8)
 assert(abs(info.elevation-(model.sample(info.station).elevation+model.offset))<1e-10)
 assert(abs(info.grade_pct-model.sample(info.station).grade*100)<1e-10)
 station_step.value=20
 station_next.pressed.emit()
 assert(abs(station_input.value-1254.567)<1e-8)
 station_previous.pressed.emit()
 assert(abs(station_input.value-1234.567)<1e-8)
 set_station_distance(-100)
 assert(model.station==0 and station_previous.disabled)
 set_station_distance(model.length()+100)
 assert(model.station==1 and station_next.disabled)
 station_slider.value=0.37
 assert(abs(station_input.value-model.length()*0.37)<=0.001)
 set_station_distance(1550)
 # The 3D marker follows the actual centre elevation and crossfall.
 var arrays=station_node.mesh.surface_get_arrays(0)
 var world_centre=arrays[Mesh.ARRAY_VERTEX][1]
 var at=model.sample(1550)
 assert(world_centre.distance_to(model.world(Vector3(at.x,at.elevation+model.offset+0.65,at.y)))<0.001)
 # Explicit focus affects view transforms only, and preserves manual scale.
 plan.zoom_navigation(plan.size/2,0.5)
 var zoom=plan.plan_zoom
 plan.focus_navigation()
 var rect=plan.map_rect()
 var screen=rect.position+Vector2(at.x,at.y)/model.extent()*rect.size
 assert(screen.distance_to(plan.size/2)<0.001 and plan.plan_zoom==zoom)
 profile.focus_navigation()
 assert(profile.profile_screen(1550,at.elevation+model.offset).distance_to(profile.plot_rect().get_center())<0.001)
 var span=profile.profile_view.size
 set_station_distance(1750)
 profile.focus_navigation()
 assert(profile.profile_view.size==span)
 assert(target==previous_target) # Moving station never drags the 3D camera.
 focus_station()
 assert(target!=previous_target)
 await get_tree().process_frame
 assert(model.edit_state()==before and revision==rev and undo_stack.size()==history and total_mesh_updates==uploads)
 # NoData is reported explicitly rather than inventing zero elevation/difference.
 var source=model.source
 model.source=model.source.duplicate(true)
 var values=model.source.Heights.duplicate()
 values.fill(NAN)
 model.source.Heights=values
 info=model.inspect_station(1550)
 assert(info.ok and not is_finite(info.ground) and not is_finite(info.delta))
 set_station_distance(1550)
 assert("NoData" in station_info.text)
 model.source=source
 refresh_station_controls()
 clear_route()
 assert(not station_input.editable and station_node.mesh==null)
 undo_edit()
 assert(station_input.editable and station_node.mesh!=null)
 print("PASS STATION NAVIGATION: numeric mm station, step/slider sync, endpoint clamp, exact grade/elevation, plan/profile focus, marker, NoData, no design/history/revision/terrain changes, clear/undo")
 get_tree().quit(0)


func run_slopes_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,1000))
 add_point(Vector2(1800,1000))
 var shared=model.edit_state()
 slope_input.value=2
 cut_slope_input.value=0.5
 apply_parameters()
 assert(model.slope==2 and model.cut_slope==0.5)
 var separated=model.edit_state()
 undo_edit()
 assert(model.edit_state()==shared and cut_slope_input.value==shared.cut_slope)
 redo_edit()
 assert(model.edit_state()==separated and cut_slope_input.value==0.5)
 var report=EarthworkReport.calculate_job(model.snapshot(),20,300,2)
 assert(report.ok and report.fill_slope==2 and report.cut_slope==0.5)
 earthwork_report.start_calculation()
 while earthwork_report.worker!=null:await get_tree().process_frame
 assert(earthwork_report.export_csv("user://slopes.csv"))
 var csv=FileAccess.open("user://slopes.csv",FileAccess.READ)
 var header=csv.get_csv_line()
 var row=csv.get_csv_line()
 assert(header.size()==21 and row.size()==21 and header[19]=="fill_slope_hv" and header[20]=="cut_slope_hv")
 assert(float(row[19])==2 and float(row[20])==0.5)
 csv.close()
 save_project("user://slopes-v6.kroadg")
 while import_worker!=null:await get_tree().process_frame
 var stored=read_document("user://slopes-v6.kroadg",true)
 assert(stored.document.version==6 and stored.document.cut_slope==0.5)
 apply_document(stored.document,true)
 assert(model.edit_state()==separated)
 var old=stored.document.duplicate(true)
 old.version=5
 old.erase("cut_slope")
 apply_document(old,true)
 assert(model.slope==2 and model.cut_slope==2)
 var preserved=model.edit_state()
 var invalid=stored.document.duplicate(true)
 invalid.cut_slope="bad"
 apply_document(invalid,true)
 assert(model.edit_state()==preserved)
 message.hide()
 invalid=stored.document.duplicate(true)
 invalid.cut_slope=0
 apply_document(invalid,true)
 assert(model.edit_state()==preserved)
 message.hide()
 invalid.erase("cut_slope")
 apply_document(invalid,true)
 assert(model.edit_state()==preserved)
 message.hide()
 print("PASS CUT/FILL SLOPES UI: controls/history, worker quantities, 21-column CSV, v6 roundtrip, v5 shared-slope migration, invalid/missing cut rollback")
 get_tree().quit(0)


func run_station_table_smoke():
 while worker!=null or not dirty.is_empty():await get_tree().process_frame
 add_point(Vector2(600,1000))
 add_point(Vector2(1800,1000))
 var before=model.edit_state()
 var rev=revision
 var history=undo_stack.size()
 station_table.start_calculation()
 while station_table.worker!=null:await get_tree().process_frame
 assert(not station_table.result.is_empty() and station_table.result.rows.size()>20)
 station_table.table.set_caret_line(3)
 station_table.select_row()
 assert(abs(model.station*model.length()-station_table.result.rows[2].station)<0.00001)
 assert(model.edit_state()==before and revision==rev and undo_stack.size()==history)
 assert(station_table.export_csv("user://station-table.csv"))
 var file=FileAccess.open("user://station-table.csv",FileAccess.READ)
 assert(file.get_csv_line().size()==21)
 var row=file.get_csv_line()
 assert(row.size()==21 and row[3]=="" and row[4]=="" and row[5]=="LOCAL" and row[11]=="")
 file.close()
 station_table.interval.value=25
 assert(station_table.result.is_empty() and station_table.csv_button.disabled)
 station_table.start_calculation()
 assert(move_pi(1,Vector2(1900,1000)))
 while station_table.worker!=null:await get_tree().process_frame
 assert(station_table.result.is_empty())
 assert(not station_table.export_csv("user://stale-station-table.csv"))
 var original=model.source
 model.source=model.source.duplicate(true)
 var heights=model.source.Heights.duplicate()
 heights.fill(NAN)
 model.source.Heights=heights
 station_table.start_calculation()
 while station_table.worker!=null:await get_tree().process_frame
 assert(station_table.result.missing==station_table.result.rows.size())
 assert(station_table.export_csv("user://nodata-station-table.csv"))
 file=FileAccess.open("user://nodata-station-table.csv",FileAccess.READ)
 file.get_csv_line()
 row=file.get_csv_line()
 assert(row[7]=="" and row[8]=="" and row[14]=="nodata" and row[6]!="")
 file.close()
 model.source=original
 station_table.invalidate()
 print("PASS STATION TABLE UI: async result, row navigation, unchanged design/history, 21-column CSV, local/NoData blanks, interval invalidation and stale result rejection")
 get_tree().quit(0)
