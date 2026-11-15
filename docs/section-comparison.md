# 현재 횡단선의 원지반·대안 설계면 표 — 0.28

현재 STA를 정하고 대안 창에서 보관본을 선택한 뒤 현재 횡단선·선택 대안 표 / CSV를 엽니다. 횡단 간격과 조사 반폭을 지정하고 산출을 누릅니다. 현재 노선과 보관본이 모두 필요하며 중첩 표시와는 독립적으로 사용할 수 있습니다.

## 위치와 값

산출 시 현재 STA의 네이티브 중심 좌표·법선을 고정합니다. 0.27 횡단 뷰와 같은 point/normal 표현을 사용해 각 오프셋 d에서 `X = 중심 동 + 법선 동×d`, `Y = 중심 남 + 법선 남×d`를 구합니다. 음수 d는 현재 노선 좌측입니다. 좌표는 동일 DEM의 로컬 동/남(m)이며 EPSG 좌표를 추가하지 않습니다. 현재 측점 이후의 움직이는 화면을 실시간 추적하는 표는 아니고, 측점이 바뀌면 다시 산출해야 합니다.

원본 해상도 DEM을 쌍선형 보간한 원지반과 두 설계의 준비된 네이티브 공간 검색으로 설계면을 평가합니다. 각 설계의 폭·계획고 보정·좌우 횡단구배·절토/성토 사면비를 사용하며 [횡단 중첩의 같은 좌표 평가 방식](alternative-section-overlay.md)과 같습니다. 가까운 보관 노선의 실제 영향만 나타내고 영향이 없으면 원지반을 유지합니다. 다른 노선의 같은 STA를 가져와 중심을 맞추지 않습니다.

현재−지반, 보관−지반, 현재−보관 세 차이를 기록합니다. 모두 단일 위치의 표고 차이(m)이며 단면적·체적·공사비가 아닙니다. 조사 끝의 사면 미접속이나 절성토 경계 폐합도 판정하지 않습니다. 같은 좌표의 설계면 비교이므로 0.26의 같은 STA 계획고 비교와 기준이 다릅니다.

## 표본과 유효성

횡단 간격은 0.1~50m, 조사 반폭은 5~10,000m입니다. -반폭부터 지정 간격으로 표본을 만들고 양 끝·0·범위 안의 현재 폭/2 좌우 가장자리를 추가합니다. 마지막 간격은 짧을 수 있고 약 10⁻⁷m 이내 중복은 태그를 합칩니다. 현재 도로보다 좁은 범위도 허용하며 완전한 단면을 조사했다는 의미는 아닙니다. 보관 가장자리의 정확한 교차점은 별도로 추출하지 않습니다. 경계 포함 최대 20,000표본을 넘으면 간격/반폭 변경을 안내합니다.

- ok: 원지반과 양쪽 설계면이 유효합니다. 실제 0은 숫자 0입니다.
- nodata: 원지반의 DEM 결측/범위 밖입니다. 유효하지 않은 표고와 그 차이를 NA/빈 셀로 기록합니다.
- invalid_design: 원지반은 있지만 한쪽 설계면이 유효하지 않습니다. 각 표고를 독립적으로 확인하고 유효한 값만 유지합니다.

전체 계산 실패는 표를 만들지 않고 오류를 표시합니다. 별도 스레드에서 불변 설계와 공유 DEM을 사용하며 현재 모델을 바꾸지 않습니다. 현재 STA·설계/DEM·대안 선택·이름/목록·간격/반폭 변경은 결과를 비우고 저장을 막습니다. 완료 시 revision에 현재 STA/선택을 포함하고 설정 세대를 함께 확인하므로 STA가 A→B→A로 되돌아와도 중간의 이전 작업 결과를 사용하지 않습니다.

## 표시와 저장

처음에는 현재 중심 표본 주변을 보여 주고 현재 중심 보기로 돌아갈 수 있습니다. 200행씩 이전/다음 페이지를 제공하며 고정 열 제목은 스크롤해도 남습니다. 행은 같은 고정 횡단선의 다른 위치이므로 선택해도 STA나 설계가 바뀌지 않습니다. CSV는 현재 페이지와 관계없이 전체 표본을 저장합니다. 입력 표시 자릿수나 간격은 원본 SRTM의 물리적 정확도를 높이지 않습니다.

프로젝트 v7·DLL v018을 유지하며 표·설정·페이지/결과는 프로젝트에 저장하지 않습니다. 중첩·수량 결과·undo/revision·지형 메시를 표 조작만으로 변경하지 않습니다.

## CSV 32열

```text
saved_name,comparison_basis,station_m,centre_local_east_m,centre_local_south_m,normal_east,normal_south,half_width_m,lateral_step_m,current_width_m,current_offset_m,current_left_down_pct,current_right_down_pct,current_fill_slope_hv,current_cut_slope_hv,saved_width_m,saved_offset_m,saved_left_down_pct,saved_right_down_pct,saved_fill_slope_hv,saved_cut_slope_hv,offset_m,local_east_m,local_south_m,ground_elevation_m,current_design_elevation_m,saved_design_elevation_m,current_minus_ground_m,saved_minus_ground_m,current_minus_saved_m,status,events
```

UTF-8 BOM, comparison_basis=current_section_world_coordinates입니다. 길이/좌표/표고와 차이는 m, 하향구배는 %, 사면은 H:V입니다. 중심·법선·조사 설정과 양쪽 설계 조건을 모든 행에 반복합니다. normal은 로컬 동/남 방향 성분입니다. 각 행은 해당 오프셋의 표본이며 누계가 아닙니다. events에는 left_bound/right_bound/regular/current_center/current_left_edge/current_right_edge 태그를 |로 합칩니다. 미산출 표고·차이는 빈 셀이고 유효한 0은 숫자 0입니다. 임시 파일을 완성한 뒤 교체하며 현재 유효한 결과만 저장합니다.
