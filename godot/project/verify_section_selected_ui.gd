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
 var content_before_wrap=app.section_dxf.table.text
 var count_before_wrap=app.section_dxf.table.get_line_count()
 app.section_dxf.wrap_results.button_pressed=true
 assert(app.section_dxf.table.wrap_mode==TextEdit.LINE_WRAPPING_BOUNDARY)
 assert(app.section_dxf.table.text==content_before_wrap and app.section_dxf.table.get_line_count()==count_before_wrap)
 assert(app.section_dxf.move_result(1))
 assert(app.section_dxf.row_stations.has(app.section_dxf.table.get_caret_line()))
 app.section_dxf.wrap_results.button_pressed=false
 assert(app.section_dxf.table.wrap_mode==TextEdit.LINE_WRAPPING_NONE)
 var wheel=InputEventMouseButton.new()
 wheel.pressed=true
 wheel.ctrl_pressed=true
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP
 app.section_dxf.set_result_font(14)
 assert(app.section_dxf.handle_result_input(wheel))
 assert(app.section_dxf.table.get_theme_font_size("font_size")==16)
 wheel.ctrl_pressed=false
 assert(not app.section_dxf.handle_result_input(wheel))
 var key=InputEventKey.new()
 key.pressed=true
 key.ctrl_pressed=true
 key.keycode=KEY_0
 assert(app.section_dxf.handle_result_input(key))
 assert(app.section_dxf.table.get_theme_font_size("font_size")==app.section_dxf.default_result_font)
 key.ctrl_pressed=false
 key.alt_pressed=true
 key.keycode=KEY_RIGHT
 assert(app.section_dxf.handle_result_input(key))
 assert(app.section_dxf.row_stations.has(app.section_dxf.table.get_caret_line()))
 var text_before_zoom=app.section_dxf.table.text
 app.section_dxf.set_result_font(24)
 assert(app.section_dxf.table.get_theme_font_size("font_size")==24)
 app.section_dxf.set_result_font(100)
 assert(app.section_dxf.table.get_theme_font_size("font_size")==30)
 app.section_dxf.set_result_font(1)
 assert(app.section_dxf.table.get_theme_font_size("font_size")==10)
 app.section_dxf.set_result_font(app.section_dxf.default_result_font)
 assert(app.section_dxf.table.text==text_before_zoom and not app.section_dxf.result.is_empty())
 var preserved_signature=app.section_dxf.input_signature()
 var preserved_result=app.section_dxf.result.text
 app.section_dxf.collapse_button.button_pressed=true
 for settings_row in app.section_dxf.settings_rows:assert(not settings_row.visible)
 assert(app.section_dxf.result.text==preserved_result and app.section_dxf.input_signature()==preserved_signature)
 assert(not app.section_dxf.csv_button.disabled and app.section_dxf.move_result(1))
 app.section_dxf.collapse_button.button_pressed=false
 for settings_row in app.section_dxf.settings_rows:assert(settings_row.visible)
 var current_before_sort=app.model.station
 var selected_before_sort=app.section_dxf.row_stations[app.section_dxf.table.get_caret_line()]
 app.section_dxf.result_sort.select(1)
 app.section_dxf.render_result()
 assert(app.section_dxf.row_stations[app.section_dxf.table.get_caret_line()]==selected_before_sort)
 assert(app.model.station==current_before_sort)
 app.section_dxf.result_sort.select(0)
 app.section_dxf.render_result()
 var station_before_worst=app.model.station
 var dxf_before_worst=app.section_dxf.result.text
 assert(app.section_dxf.find_worst_result(true))
 var expected_worst=app.section_dxf.sorted_sections(app.section_dxf.displayed_sections(),1)[0].station
 assert(is_equal_approx(app.model.station*app.model.length(),expected_worst))
 assert(app.section_dxf.find_worst_result(false))
 assert(app.section_dxf.result.text==dxf_before_worst)
 app.model.station=station_before_worst
 var review_target=app.section_dxf.result.sections[-1].station
 app.section_dxf.review_begin.text=str(review_target)
 app.section_dxf.review_end.text=str(review_target)
 assert(app.section_dxf.apply_review_range())
 assert(app.section_dxf.displayed_sections().size()==1)
 assert("표시 1횡단 유효 표본 비율" in app.section_dxf.table.text)
 assert("전체 %d횡단" % app.section_dxf.result.sections.size() in app.section_dxf.table.text)
 app.section_dxf.review_begin.text="NaN"
 assert(not app.section_dxf.apply_review_range())
 assert(app.section_dxf.displayed_sections().size()==1)
 assert("표시 1횡단 유효 표본 비율" in app.section_dxf.table.text)
 assert("전체 %d횡단" % app.section_dxf.result.sections.size() in app.section_dxf.table.text)
 app.section_dxf.review_begin.text=""
 app.section_dxf.review_end.text=""
 assert(app.section_dxf.apply_review_range())
 var filter_dxf=app.section_dxf.result.text
 var filter_signature=app.section_dxf.input_signature()
 app.section_dxf.missing_only.button_pressed=true
 app.section_dxf.result_sort.select(2)
 app.section_dxf.review_range={"begin":0.0,"end":0.0}
 app.section_dxf.render_result()
 app.section_dxf.reset_review_filters()
 assert(not app.section_dxf.missing_only.button_pressed and app.section_dxf.missing_type.disabled)
 assert(app.section_dxf.result_sort.selected==0 and app.section_dxf.review_range.is_empty())
 assert(app.section_dxf.displayed_sections().size()==app.section_dxf.result.sections.size())
 assert(app.section_dxf.result.text==filter_dxf and app.section_dxf.input_signature()==filter_signature)
 var full_details_text=app.section_dxf.table.text
 var details_dxf=app.section_dxf.result.text
 app.section_dxf.details_only.button_pressed=true
 assert(app.section_dxf.table.text.begins_with("STA(m) | DATUM(m)"))
 assert(app.section_dxf.save_report("user://full-summary-report.txt"))
 assert("전체" in FileAccess.get_file_as_string("user://full-summary-report.txt"))
 assert(FileAccess.get_file_as_string("user://full-summary-report.txt")==app.section_dxf.result_text(true)+"\n")
 app.section_dxf.report_include_summary.button_pressed=false
 assert(app.section_dxf.save_report("user://details-only-report.txt"))
 assert(FileAccess.get_file_as_string("user://details-only-report.txt")==app.section_dxf.table.text+"\n")
 app.section_dxf.report_include_summary.button_pressed=true
 assert(app.section_dxf.table.get_line_count()==app.section_dxf.displayed_sections().size()+1)
 assert(app.section_dxf.move_result(1))
 assert(app.section_dxf.result.text==details_dxf)
 app.section_dxf.details_only.button_pressed=false
 assert(app.section_dxf.table.text==full_details_text)
 var original_dxf=app.section_dxf.result.text
 var original_rows=app.section_dxf.table.text
 app.section_dxf.missing_only.button_pressed=true
 assert("목록: 결측만" in app.section_dxf.table.text and app.section_dxf.result.text==original_dxf)
 app.section_dxf.missing_only.button_pressed=false
 assert(app.section_dxf.table.text==original_rows)
 app.section_dxf.result_csv_dialog.file_selected.emit("user://section-results.csv")
 var csv=FileAccess.open("user://section-results.csv",FileAccess.READ)
 var bytes=csv.get_buffer(3)
 assert(bytes==PackedByteArray([239,187,191]))
 var header=csv.get_csv_line()
 assert(header[0]=="station_m" and header.size()==10)
 for section in app.section_dxf.result.sections:
  var values=csv.get_csv_line()
  assert(values[0].to_float()==section.station and values[3].to_int()==section.ground_missing)
  assert(is_equal_approx(values[8].to_float(),app.section_dxf.valid_percent(section.ground_missing,app.section_dxf.result.lateral_count)))
 csv.close()
 var report_path="user://section-result-report.txt"
 app.section_dxf.report_dialog.file_selected.emit(report_path)
 assert(FileAccess.get_file_as_string(report_path)==app.section_dxf.table.text+"\n")
 assert(app.section_dxf.save_report(report_path))
 assert(not app.section_dxf.save_report("user://missing-directory/report.txt"))
 app.section_dxf.label_decimals.set_value_no_signal(1)
 assert(app.section_dxf.result_text()=="" and app.section_dxf.copy_button.disabled)
 assert(not app.section_dxf.save_report(report_path) and app.section_dxf.report_button.disabled)
 assert(app.section_dxf.selected_summary.text=="선택 횡단: 없음")
 assert(not app.section_dxf.save_result_csv("user://stale-section-results.csv"))
 assert(not app.section_dxf.find_worst_result(true))
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
 app.section_dxf.set_result_font(22)
 app.section_dxf.wrap_results.button_pressed=true
 app.section_dxf.collapse_button.button_pressed=true
 assert(app.section_dxf.save_preset("user://view-preset.cfg"))
 app.section_dxf.set_result_font(14)
 app.section_dxf.wrap_results.button_pressed=false
 app.section_dxf.collapse_button.button_pressed=false
 assert(app.section_dxf.load_preset("user://view-preset.cfg"))
 assert(app.section_dxf.table.get_theme_font_size("font_size")==22)
 assert(app.section_dxf.wrap_results.button_pressed and app.section_dxf.collapse_button.button_pressed)
 var old=ConfigFile.new()
 old.load("user://view-preset.cfg")
 old.erase_section("view")
 old.save("user://legacy-preset.cfg")
 assert(app.section_dxf.load_preset("user://legacy-preset.cfg"))
 assert(app.section_dxf.table.get_theme_font_size("font_size")==22)
 old.set_value("view","font_size",100)
 old.save("user://bad-view-preset.cfg")
 assert(not app.section_dxf.load_preset("user://bad-view-preset.cfg"))
 assert(app.section_dxf.table.get_theme_font_size("font_size")==22)
 assert(app.section_dxf.valid_percent(0,10)==100)
 assert(app.section_dxf.valid_percent(3,10)==70)
 assert(app.section_dxf.valid_percent(10,10)==0)
 var coverage_sample={"ground_missing":1,"design_missing":0}
 assert(not app.section_dxf.matches_missing(coverage_sample,10,6))
 assert(app.section_dxf.matches_missing(coverage_sample,10,7))
 coverage_sample.ground_missing=2
 assert(app.section_dxf.matches_missing(coverage_sample,10,6))
 assert(not app.section_dxf.matches_missing(coverage_sample,10,5))
 coverage_sample.ground_missing=5
 assert(not app.section_dxf.matches_missing(coverage_sample,10,4))
 coverage_sample.ground_missing=6
 assert(app.section_dxf.matches_missing(coverage_sample,10,4))
 var unsorted=[{"station":20.0,"ground_missing":2,"design_missing":0},{"station":10.0,"ground_missing":2,"design_missing":5},{"station":30.0,"ground_missing":8,"design_missing":1}]
 assert(app.section_dxf.sorted_sections(unsorted,1).map(func(v):return v.station)==[30.0,10.0,20.0])
 assert(app.section_dxf.sorted_sections(unsorted,2).map(func(v):return v.station)==[10.0,30.0,20.0])
 assert(unsorted[0].station==20.0)
 var coverage_stats=app.section_dxf.coverage_summary([{"ground_missing":0,"design_missing":10},{"ground_missing":5,"design_missing":0}],10)
 assert("원지반 평균 75.0% / 최저 50.0%" in coverage_stats)
 assert("설계 평균 50.0% / 최저 0.0%" in coverage_stats)
 assert("산출 횡단 없음" in app.section_dxf.coverage_summary([],10))
 var grouped=app.section_dxf.missing_ranges([{"station":30.0,"ground_missing":0,"design_missing":1},{"station":0.0,"ground_missing":1,"design_missing":0},{"station":10.0,"ground_missing":2,"design_missing":0},{"station":20.0,"ground_missing":0,"design_missing":0}])
 assert(grouped.size()==2)
 assert(grouped[0].begin==0 and grouped[0].end==10 and grouped[0].count==2)
 assert(grouped[1].begin==30 and grouped[1].end==30 and grouped[1].count==1)
 assert(app.section_dxf.missing_ranges([]).is_empty())
 assert("표시 유효 비율: 산출 횡단 없음"==app.section_dxf.coverage_summary([],10,"표시"))
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
 app.section_dxf.reset_settings()
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()>1)
 app.section_dxf.review_begin.text="1000"
 app.section_dxf.review_end.text="1000"
 assert(app.section_dxf.apply_review_range())
 assert(not app.section_dxf.recalculate_review_button.disabled)
 assert(app.section_dxf.recalculate_review())
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()==1 and app.section_dxf.result.sections[0].station==1000)
 assert(app.section_dxf.extras_only.button_pressed)
 print("PASS REVIEW RECALCULATION")
 app.section_dxf.reset_settings()
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()>1)
 assert(app.section_dxf.recalculate_selected_button.disabled)
 assert(not app.section_dxf.recalculate_selected())
 var selected_line=app.section_dxf.row_stations.keys()[1]
 var chosen_station=app.section_dxf.row_stations[selected_line]
 app.section_dxf.table.set_caret_line(selected_line)
 app.section_dxf.select_row(false)
 assert(not app.section_dxf.recalculate_selected_button.disabled)
 app.section_dxf.recalculate_selected_button.pressed.emit()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()==1 and app.section_dxf.result.sections[0].station==chosen_station)
 print("PASS SELECTED STATION RECALCULATION")
 app.section_dxf.reset_settings()
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 var rows=app.section_dxf.row_stations.keys()
 assert(rows.size()>2)
 for collection_row in [rows[0],rows[-1]]:
  app.section_dxf.table.set_caret_line(collection_row)
  assert(app.section_dxf.collect_selected_station())
  assert(not app.section_dxf.collect_selected_station())
 assert(app.section_dxf.result.sections.size()>2)
 assert(app.section_dxf.calculate_collection())
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.map(func(section):return section.station)==app.section_dxf.collected_stations)
 print("PASS STATION COLLECTION")
 assert(app.section_dxf.collection_picker.item_count==2)
 var remaining_station=app.section_dxf.collected_stations[1]
 app.section_dxf.collection_picker.select(1)
 app.section_dxf.collection_jump_button.pressed.emit()
 assert(is_equal_approx(app.model.station*app.model.length(),remaining_station))
 assert(app.section_dxf.result.sections.size()==2)
 app.section_dxf.collection_picker.select(0)
 app.section_dxf.remove_collection_button.pressed.emit()
 assert(app.section_dxf.collected_stations==[remaining_station])
 assert(app.section_dxf.result.sections.size()==2)
 assert(app.section_dxf.calculate_collection())
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.size()==1 and app.section_dxf.result.sections[0].station==remaining_station)
 app.section_dxf.remove_collection_button.pressed.emit()
 assert(app.section_dxf.collection_picker.disabled and app.section_dxf.apply_collection_button.disabled)
 assert(app.section_dxf.collection_jump_button.disabled and not app.section_dxf.jump_to_collected_station())
 print("PASS COLLECTION EDIT AND NAVIGATION")
 app.section_dxf.reset_settings()
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 var bulk_sections=app.section_dxf.result.sections
 app.section_dxf.table.set_caret_line(app.section_dxf.row_stations.keys()[0])
 assert(app.section_dxf.collect_selected_station())
 app.section_dxf.review_begin.text=str(bulk_sections[0].station)
 app.section_dxf.review_end.text=str(bulk_sections[1].station)
 assert(app.section_dxf.apply_review_range())
 assert(not app.section_dxf.collect_displayed_button.disabled)
 app.section_dxf.collect_displayed_button.pressed.emit()
 assert(app.section_dxf.collected_stations==[bulk_sections[0].station,bulk_sections[1].station])
 assert(not app.section_dxf.collect_displayed_stations())
 assert(app.section_dxf.result.sections.size()>2)
 print("PASS BULK STATION COLLECTION")
 var removed_station=app.section_dxf.collected_stations[0]
 var retained_station=app.section_dxf.collected_stations[1]
 var dxf_before_removal=app.section_dxf.result.text
 app.section_dxf.review_begin.text=str(removed_station)
 app.section_dxf.review_end.text=str(removed_station)
 assert(app.section_dxf.apply_review_range())
 assert(not app.section_dxf.remove_displayed_button.disabled)
 app.section_dxf.remove_displayed_button.pressed.emit()
 assert(app.section_dxf.collected_stations==[retained_station])
 assert(app.section_dxf.remove_displayed_button.disabled)
 assert(app.section_dxf.result.text==dxf_before_removal)
 print("PASS BULK STATION REMOVAL")
 app.section_dxf.reset_review_filters()
 app.section_dxf.collected_only.button_pressed=true
 assert(app.section_dxf.displayed_sections().map(func(section):return section.station)==[retained_station])
 assert(app.section_dxf.row_stations.values()==[retained_station])
 app.section_dxf.remove_collection_button.pressed.emit()
 assert(app.section_dxf.row_stations.is_empty())
 assert(app.section_dxf.result.text==dxf_before_removal)
 app.section_dxf.reset_review_filters()
 assert(not app.section_dxf.collected_only.button_pressed)
 assert(app.section_dxf.row_stations.size()==app.section_dxf.result.sections.size())
 print("PASS COLLECTED STATION FILTER")
 app.section_dxf.collected_only.button_pressed=true
 app.section_dxf.uncollected_only.button_pressed=true
 assert(not app.section_dxf.collected_only.button_pressed)
 var row_to_collect=app.section_dxf.row_stations.keys()[0]
 var collected_from_filter=app.section_dxf.row_stations[row_to_collect]
 app.section_dxf.table.set_caret_line(row_to_collect)
 assert(app.section_dxf.collect_selected_station())
 assert(not app.section_dxf.row_stations.values().has(collected_from_filter))
 app.section_dxf.remove_collection_button.pressed.emit()
 assert(app.section_dxf.row_stations.values().has(collected_from_filter))
 app.section_dxf.reset_review_filters()
 assert(not app.section_dxf.uncollected_only.button_pressed)
 print("PASS UNCOLLECTED STATION FILTER")
 assert(app.section_dxf.copy_collection_button.disabled)
 assert(not app.section_dxf.copy_collected_stations())
 assert(app.section_dxf.format_station_list([100.125,200.25])=="100.125, 200.25")
 app.section_dxf.table.set_caret_line(app.section_dxf.row_stations.keys()[0])
 assert(app.section_dxf.collect_selected_station())
 assert(not app.section_dxf.copy_collection_button.disabled)
 if DisplayServer.get_name()!="headless":
  assert(app.section_dxf.copy_collected_stations())
  assert(DisplayServer.clipboard_get()==app.section_dxf.format_station_list(app.section_dxf.collected_stations))
 var paste_before=app.section_dxf.collected_stations.duplicate()
 assert(not app.section_dxf.paste_collected_stations("20, bad"))
 assert(not app.section_dxf.paste_collected_stations("20, -1"))
 assert(app.section_dxf.collected_stations==paste_before)
 assert(app.section_dxf.paste_collected_stations("20.125, 20.125, 30"))
 assert(app.section_dxf.collected_stations.slice(paste_before.size())==[20.125,30.0])
 print("PASS STATION PASTE")
 assert(not app.section_dxf.undo_collection_button.disabled)
 app.section_dxf.undo_collection_button.pressed.emit()
 assert(app.section_dxf.collected_stations==paste_before)
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.collected_stations.is_empty())
 assert(app.section_dxf.redo_collection_edit())
 assert(app.section_dxf.collected_stations==paste_before)
 assert(app.section_dxf.redo_collection_button.text.ends_with("(1)"))
 print("PASS MULTI-STEP STATION COLLECTION UNDO")
 assert(not app.section_dxf.redo_collection_button.disabled)
 app.section_dxf.redo_collection_button.pressed.emit()
 assert(app.section_dxf.collected_stations.slice(paste_before.size())==[20.125,30.0])
 assert(app.section_dxf.redo_collection_button.disabled)
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.paste_collected_stations("40.5"))
 assert(not app.section_dxf.redo_collection_edit())
 assert(app.section_dxf.redo_collection_button.text.ends_with("(0)"))
 print("PASS STATION COLLECTION REDO")
 assert(app.section_dxf.paste_collected_stations("35.5"))
 var before_sort=app.section_dxf.collected_stations.duplicate()
 app.section_dxf.collection_picker.select(before_sort.size()-1)
 app.section_dxf.sort_collection_button.pressed.emit()
 var sorted_expected=before_sort.duplicate()
 sorted_expected.sort()
 assert(app.section_dxf.collected_stations==sorted_expected)
 assert(app.section_dxf.collected_stations[app.section_dxf.collection_picker.selected]==35.5)
 assert(not app.section_dxf.sort_collected_stations())
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.collected_stations==before_sort)
 assert(app.section_dxf.redo_collection_edit())
 assert(app.section_dxf.collected_stations==sorted_expected)
 print("PASS COLLECTION SORT")
 app.section_dxf.collection_picker.select(0)
 app.section_dxf.update_collection_move_buttons()
 assert(app.section_dxf.collection_up.disabled)
 assert(not app.section_dxf.move_collected_station(-1))
 app.section_dxf.collection_down.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==1)
 assert(app.section_dxf.collected_stations[1]==sorted_expected[0])
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.collected_stations==sorted_expected)
 assert(app.section_dxf.redo_collection_edit())
 assert(app.section_dxf.collected_stations[1]==sorted_expected[0])
 print("PASS COLLECTION REORDER")
 var before_move_first=app.section_dxf.collected_stations.duplicate()
 var last_station=before_move_first[-1]
 app.section_dxf.collection_picker.select(before_move_first.size()-1)
 app.section_dxf.collection_first.pressed.emit()
 assert(app.section_dxf.collected_stations[0]==last_station)
 assert(app.section_dxf.collected_stations.slice(1)==before_move_first.slice(0,-1))
 assert(app.section_dxf.collection_picker.selected==0 and app.section_dxf.collection_first.disabled)
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.collected_stations==before_move_first)
 print("PASS COLLECTION MOVE FIRST")
 app.section_dxf.collection_picker.select(0)
 app.section_dxf.collection_last.pressed.emit()
 var after_move_last=before_move_first.slice(1)
 after_move_last.append(before_move_first[0])
 assert(app.section_dxf.collected_stations==after_move_last)
 assert(app.section_dxf.collection_picker.selected==after_move_last.size()-1)
 assert(app.section_dxf.collection_last.disabled)
 assert(app.section_dxf.undo_collection_edit())
 assert(app.section_dxf.collected_stations==before_move_first)
 assert(app.section_dxf.redo_collection_edit())
 assert(app.section_dxf.collected_stations==after_move_last)
 assert(app.section_dxf.collection_position.text.ends_with("/ %d" % after_move_last.size()))
 print("PASS COLLECTION MOVE LAST")
 var stepping_order=app.section_dxf.collected_stations.duplicate()
 app.section_dxf.collection_picker.select(0)
 app.section_dxf.update_collection_move_buttons()
 assert(app.section_dxf.collection_previous.disabled)
 assert(not app.section_dxf.step_collected_station(-1))
 app.section_dxf.collection_next.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==1)
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[1]))
 app.section_dxf.collection_previous.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==0)
 assert(app.section_dxf.collected_stations==stepping_order)
 print("PASS COLLECTION STEP NAVIGATION")
 app.section_dxf.collection_jump_last.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==stepping_order.size()-1)
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[-1]))
 assert(app.section_dxf.collection_jump_last.disabled)
 app.section_dxf.collection_jump_first.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==0)
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[0]))
 assert(app.section_dxf.collection_jump_first.disabled)
 assert(app.section_dxf.collected_stations==stepping_order)
 print("PASS COLLECTION ENDPOINT NAVIGATION")
 assert(app.section_dxf.collection_number_range.text=="입력 범위 1~%d" % stepping_order.size())
 app.section_dxf.collection_number.text="2"
 app.section_dxf.collection_jump_number.pressed.emit()
 assert(app.section_dxf.collection_picker.selected==1)
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[1]))
 assert(app.section_dxf.collected_stations==stepping_order)
 var number_editor=app.section_dxf.collection_number
 number_editor.text="1"
 number_editor.text_submitted.emit("1")
 assert(app.section_dxf.collection_picker.selected==0)
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[0]))
 for invalid_number in ["","abc","1.5","0","999"]:
  number_editor.text=invalid_number
  app.section_dxf.collection_jump_number.pressed.emit()
  assert(app.section_dxf.status.text=="목록 번호는 1~%d 사이의 정수로 입력하세요." % stepping_order.size())
  assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[0]))
 assert(app.section_dxf.collection_picker.selected==0)
 number_editor.text="999"
 var cancel_number=InputEventKey.new()
 cancel_number.keycode=KEY_ESCAPE
 cancel_number.pressed=true
 number_editor.gui_input.emit(cancel_number)
 assert(number_editor.text=="1")
 assert(app.section_dxf.collection_picker.selected==0)
 app.section_dxf.collection_search.text=str(stepping_order[-1]+0.01)
 app.section_dxf.collection_search_button.pressed.emit()
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[-1]))
 assert(not app.section_dxf.find_collected_station("bad"))
 assert(is_equal_approx(app.model.station*app.model.length(),stepping_order[-1]))
 assert(app.section_dxf.CrossDxf.parse_station("1+234.567")==1234.567)
 assert(not is_finite(app.section_dxf.CrossDxf.parse_station("1+1000")))
 assert(not is_finite(app.section_dxf.CrossDxf.parse_station("-1+20")))
 assert(app.section_dxf.paste_collected_stations("20, 40"))
 app.section_dxf.collection_search.text_submitted.emit("0+040.000")
 assert(is_equal_approx(app.model.station*app.model.length(),40.0))
 app.set_station_distance(20.1)
 app.section_dxf.collection_current_button.pressed.emit()
 assert(app.section_dxf.status.text=="기준 STA 20.100m → 담은 STA 20.000m (측점 차이 0.100m)")
 assert(is_equal_approx(app.model.station*app.model.length(),20.0))
 assert(app.section_dxf.collected_stations[app.section_dxf.collection_picker.selected]==20.0)
 app.section_dxf.search_input.text="0+000"
 assert(app.section_dxf.find_result())
 assert(is_zero_approx(app.model.station))
 app.section_dxf.search_input.text="0+1000"
 assert(not app.section_dxf.find_result())
 assert(is_zero_approx(app.model.station))
 app.section_dxf.reset_settings()
 assert(app.section_dxf.collection_jump_number.disabled)
 assert(not app.section_dxf.collection_number.editable)
 assert(app.section_dxf.collection_number_range.text=="담은 측점 없음")
 assert(app.section_dxf.collection_search_button.disabled)
 assert(app.section_dxf.collection_current_button.disabled)
 print("PASS COLLECTION NUMBER AND NEAREST NAVIGATION")
 app.section_dxf.review_begin.text="0+125.5"
 app.section_dxf.review_end.text="1+025"
 assert(app.section_dxf.apply_review_range())
 assert(app.section_dxf.review_range=={"begin":125.5,"end":1025.0})
 app.section_dxf.review_end.text="0+100"
 assert(not app.section_dxf.apply_review_range())
 assert(app.section_dxf.review_range.end==1025.0)
 app.section_dxf.begin_input.text="0+125.5"
 app.section_dxf.end_input.text="1+025"
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.begin==125.5 and app.section_dxf.result.end==1025.0)
 app.set_station_distance(200.0)
 app.section_dxf.add_current_station()
 assert(is_equal_approx(app.section_dxf.extra_input.text.to_float(),200.0))
 app.section_dxf.extra_input.text="0+200.125, 300"
 app.section_dxf.extras_only.button_pressed=true
 app.section_dxf.start_calculation()
 while app.section_dxf.worker!=null:await process_frame
 assert(app.section_dxf.result.sections.map(func(section):return section.station)==[200.125,300.0])
 assert(not app.section_dxf.paste_collected_stations("0+1000, 300"))
 print("PASS MIXED EXTRA STATIONS")
 assert(app.section_dxf.paste_collected_stations("0+500.25\r\n\r\n600\n"))
 assert(app.section_dxf.collected_stations.has(500.25) and app.section_dxf.collected_stations.has(600.0))
 var before_bad_paste=app.section_dxf.collected_stations.duplicate()
 assert(not app.section_dxf.paste_collected_stations("700\nSTA"))
 assert(app.section_dxf.collected_stations==before_bad_paste)
 print("PASS MULTILINE STATION PASTE")
 quit(0)
