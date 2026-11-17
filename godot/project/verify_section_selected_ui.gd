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
 assert("원지반 꺼짐 / 설계선 켜짐" in app.section_dxf.table.text)
 assert("공통 -10000.000m" in app.section_dxf.table.text)
 app.section_dxf.export_axes.button_pressed=false
 assert(app.section_dxf.result.is_empty())
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 app.section_dxf.export_axes.set_pressed_no_signal(true)
 assert(not app.section_dxf.export_csv("user://section-selected-stale.dxf"))
 assert(app.model.edit_state()==before and app.undo_stack.size()==history and app.revision==rev)
 app.section_dxf.reset_settings()
 assert(app.section_dxf.result.is_empty() and app.section_dxf.csv_button.disabled)
 assert(app.section_dxf.interval.value==1000 and app.section_dxf.reach.value==100 and app.section_dxf.lateral_step.value==2 and app.section_dxf.columns.value==3)
 assert(not app.section_dxf.extras_only.button_pressed and app.section_dxf.extra_input.text=="")
 assert(not app.section_dxf.grid_enabled.button_pressed and not app.section_dxf.grid_interval.editable and app.section_dxf.grid_interval.value==10)
 assert(not app.section_dxf.common_datum_enabled.button_pressed and not app.section_dxf.common_datum_input.editable)
 assert(app.section_dxf.export_ground.button_pressed and app.section_dxf.export_design.button_pressed and app.section_dxf.export_axes.button_pressed)
 assert(app.section_dxf.interval.editable and not app.section_dxf.include_boundaries.disabled)
 app.section_dxf.start_calculation()
 app.section_dxf.reset_settings()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.is_empty())
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(not app.section_dxf.result.is_empty())
 assert(app.model.edit_state()==before and app.undo_stack.size()==history and app.revision==rev)
 assert("원지반 켜짐 / 설계선 켜짐 / 축선 켜짐" in app.section_dxf.table.text)
 assert("횡단별 자동" in app.section_dxf.table.text and "글자 높이: 자동" in app.section_dxf.table.text)
 assert(not app.section_dxf.copy_button.disabled)
 assert(app.section_dxf.result_text()==app.section_dxf.table.text and "STA(m)" in app.section_dxf.result_text())
 if DisplayServer.get_name()!="headless":
  assert(app.section_dxf.copy_result())
  assert(DisplayServer.clipboard_get().replace("\r\n","\n")==app.section_dxf.table.text)
 var original_station=app.model.station
 var row=app.section_dxf.row_stations.keys()[-1]
 var exact_station=app.section_dxf.row_stations[row]
 app.section_dxf.table.set_caret_line(row)
 app.section_dxf.select_row()
 assert(is_equal_approx(app.model.station*app.model.length(),exact_station))
 assert("선택 STA %.3fm" % exact_station in app.section_dxf.selected_summary.text)
 assert("원지반 결측" in app.section_dxf.selected_summary.text)
 app.section_dxf.table.set_caret_line(0)
 app.section_dxf.select_row()
 assert(is_equal_approx(app.model.station*app.model.length(),exact_station))
 assert(app.section_dxf.move_result(1))
 var first=app.section_dxf.row_stations.keys()[0]
 assert(app.section_dxf.table.get_caret_line()==first)
 assert(app.section_dxf.move_result(-1))
 assert(app.section_dxf.table.get_caret_line()==row)
 app.section_dxf.search_input.text=str(exact_station+0.1)
 assert(app.section_dxf.find_result())
 assert(is_equal_approx(app.model.station*app.model.length(),exact_station))
 app.model.station=0.999
 var unchanged_dxf=app.section_dxf.result.text
 assert(app.section_dxf.find_current_result())
 assert(is_equal_approx(app.model.station*app.model.length(),exact_station))
 assert(app.section_dxf.result.text==unchanged_dxf)
 app.section_dxf.search_input.text="NaN"
 assert(not app.section_dxf.find_result())
 app.model.station=original_station
 var preserved_signature=app.section_dxf.input_signature()
 var preserved_result=app.section_dxf.result.text
 app.section_dxf.collapse_button.button_pressed=true
 for settings_row in app.section_dxf.settings_rows:assert(not settings_row.visible)
 assert(app.section_dxf.result.text==preserved_result and app.section_dxf.input_signature()==preserved_signature)
 assert(not app.section_dxf.csv_button.disabled and app.section_dxf.move_result(1))
 app.section_dxf.collapse_button.button_pressed=false
 for settings_row in app.section_dxf.settings_rows:assert(settings_row.visible)
 var original_dxf=app.section_dxf.result.text
 var original_rows=app.section_dxf.table.text
 app.section_dxf.missing_only.button_pressed=true
 assert("목록: 결측만" in app.section_dxf.table.text and app.section_dxf.result.text==original_dxf)
 app.section_dxf.missing_only.button_pressed=false
 assert(app.section_dxf.table.text==original_rows)
 var report_path="user://section-result-report.txt"
 app.section_dxf.report_dialog.file_selected.emit(report_path)
 assert(FileAccess.get_file_as_string(report_path)==app.section_dxf.table.text+"\n")
 assert(app.section_dxf.save_report(report_path))
 assert(not app.section_dxf.save_report("user://missing-directory/report.txt"))
 app.section_dxf.label_decimals.set_value_no_signal(1)
 assert(app.section_dxf.result_text()=="" and app.section_dxf.copy_button.disabled)
 assert(not app.section_dxf.save_report(report_path) and app.section_dxf.report_button.disabled)
 assert(app.section_dxf.selected_summary.text=="선택 횡단: 없음")
 assert(not app.section_dxf.move_result(1))
 assert(not app.section_dxf.find_current_result())
 for button in app.section_dxf.navigation_buttons:assert(button.disabled)
 var ground_gap={"ground_missing":1,"design_missing":0}
 var design_gap={"ground_missing":0,"design_missing":10}
 assert(app.section_dxf.matches_missing(ground_gap,10,1))
 assert(not app.section_dxf.matches_missing(ground_gap,10,2))
 assert(not app.section_dxf.matches_missing(ground_gap,10,3))
 assert(app.section_dxf.matches_missing(design_gap,10,2) and app.section_dxf.matches_missing(design_gap,10,3))
 app.section_dxf.reach.value=150
 assert(app.section_dxf.save_preset("user://test-section-preset.cfg"))
 app.section_dxf.reach.value=200
 var bounds_before=app.section_dxf.begin_input.text
 assert(app.section_dxf.load_preset("user://test-section-preset.cfg"))
 assert(app.section_dxf.reach.value==150 and app.section_dxf.begin_input.text==bounds_before)
 assert(app.section_dxf.result.is_empty())
 assert(not app.section_dxf.load_preset("user://missing-section-preset.cfg"))
 app.section_dxf.reach.value=175
 app.section_dxf.preset_export_dialog.file_selected.emit("user://portable-section.cfg")
 app.section_dxf.reach.value=250
 app.section_dxf.preset_import_dialog.file_selected.emit("user://portable-section.cfg")
 assert(app.section_dxf.reach.value==175)
 var damaged=ConfigFile.new()
 damaged.set_value("format","version",1)
 damaged.set_value("settings","interval",-1)
 damaged.save("user://damaged-section.cfg")
 var preserved=app.section_dxf.input_signature()
 assert(not app.section_dxf.load_preset("user://damaged-section.cfg"))
 assert(app.section_dxf.input_signature()==preserved)
 for invalid in [{"key":"columns","value":2.5},{"key":"text_height","value":0.05},{"key":"ground","value":1},{"key":"interval","value":-1}]:
  var config=ConfigFile.new()
  assert(config.load("user://portable-section.cfg")==OK)
  config.set_value("settings",invalid.key,invalid.value)
  config.save("user://invalid-section.cfg")
  assert(not app.section_dxf.load_preset("user://invalid-section.cfg"))
  assert(app.section_dxf.input_signature()==preserved)
 var no_traces=ConfigFile.new()
 no_traces.load("user://portable-section.cfg")
 no_traces.set_value("settings","ground",false)
 no_traces.set_value("settings","design",false)
 no_traces.save("user://invalid-section.cfg")
 assert(not app.section_dxf.load_preset("user://invalid-section.cfg"))
 assert("하나 이상" in app.section_dxf.status.text and app.section_dxf.input_signature()==preserved)
 var valid=[{"station":0.0,"ground_missing":0,"design_missing":0}]
 assert("모든 횡단" in app.section_dxf.missing_summary(valid,10))
 var gaps=[{"station":12.5,"ground_missing":10,"design_missing":2},{"station":20.0,"ground_missing":0,"design_missing":10}]
 var warning=app.section_dxf.missing_summary(gaps,10)
 assert("2/2횡단" in warning and "원지반 10 / 설계 12표본" in warning)
 assert("원지반 1 / 설계 1" in warning and "12.500, 20.000" in warning)
 var many=[]
 for i in range(12):many.append({"station":float(i),"ground_missing":1,"design_missing":0})
 assert("외 2개" in app.section_dxf.missing_summary(many,10))
 print("PASS MISSING SUMMARY: valid, partial/full ground/design gaps, exact counts and bounded station list")
 print("PASS REPORT: UTF-8 content, overwrite, invalid path and stale-result rejection")
 print("PASS COPY: result text, stale input rejection and copy availability")
 print("PASS RESET: defaults, control states, stale worker rejection, recalculation and immutable design")
 print("PASS SECTION SELECTED UI: empty rejection, current station single save, disabled/restored controls, stale result/export rejection, immutable design/history")
 quit(0)
