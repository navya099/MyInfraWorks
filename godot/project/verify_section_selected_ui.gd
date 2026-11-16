extends SceneTree
var app
func _initialize():
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 call_deferred("run")

func run():
 while app.worker!=null or not app.dirty.is_empty():await process_frame
 app.add_point(Vector2(600,1000))
 app.add_point(Vector2(1800,1000))
 var before=app.model.edit_state()
 var history=app.undo_stack.size()
 var rev=app.revision
 app.section_dxf.open_export()
 assert(not app.section_dxf.extras_only.button_pressed and app.section_dxf.interval.editable)
 app.section_dxf.include_boundaries.button_pressed=true
 app.section_dxf.extras_only.button_pressed=true
 assert(not app.section_dxf.interval.editable and app.section_dxf.include_boundaries.disabled)
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.is_empty() and "하나 이상" in app.section_dxf.status.text)
 app.section_dxf.add_current_station()
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()==1 and app.section_dxf.result.extras_only)
 assert(is_equal_approx(app.section_dxf.result.sections[0].station,app.model.station*app.model.length()))
 assert(not app.section_dxf.result.include_boundaries and app.section_dxf.result.boundary_sections==0)
 app.section_dxf.csv_dialog.file_selected.emit("user://section-selected-ui.dxf")
 assert(FileAccess.file_exists("user://section-selected-ui.dxf"))
 app.section_dxf.extras_only.button_pressed=false
 assert(app.section_dxf.result.is_empty() and app.section_dxf.csv_button.disabled)
 assert(app.section_dxf.interval.editable and not app.section_dxf.include_boundaries.disabled and app.section_dxf.include_boundaries.button_pressed)
 app.section_dxf.start_calculation()
 app.section_dxf.extras_only.button_pressed=true
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.is_empty())
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 app.section_dxf.text_height_input.value=1.5
 assert(app.section_dxf.result.is_empty() and app.section_dxf.csv_button.disabled)
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 app.section_dxf.number_sections.button_pressed=true
 assert(app.section_dxf.result.is_empty() and app.section_dxf.csv_button.disabled)
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert("SEC 001 | STA" in app.section_dxf.result.text)
 app.section_dxf.common_datum_enabled.button_pressed=true
 assert(app.section_dxf.result.is_empty() and app.section_dxf.common_datum_input.editable)
 app.section_dxf.common_datum_input.value=-10000
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections[0].datum==-10000)
 app.section_dxf.export_ground.button_pressed=false
 assert(app.section_dxf.result.is_empty())
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections[0].ground_runs==0)
 app.section_dxf.export_axes.button_pressed=false
 assert(app.section_dxf.result.is_empty())
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 app.section_dxf.export_axes.set_pressed_no_signal(true)
 assert(not app.section_dxf.export_csv("user://section-selected-stale.dxf"))
 assert(app.model.edit_state()==before and app.undo_stack.size()==history and app.revision==rev)
 print("PASS SECTION SELECTED UI: empty rejection, current station single save, disabled/restored controls, stale result/export rejection, immutable design/history")
 quit(0)
