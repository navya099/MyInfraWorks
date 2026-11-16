# 0.40 지정 STA만 횡단 DXF 출력

## 사용

1. 횡단 뷰에서 검토 위치를 선택한 후 `DXF → 횡단 DXF`를 엽니다.
2. `현재 STA 추가`를 누르거나 추가 STA 칸에 `123.45, 567.89`처럼 입력합니다.
3. `추가 STA만 출력`을 켜고 산출 결과의 횡단 수와 STA를 확인합니다.
4. 저장하면 입력한 위치만 포함한 R12 ASCII DXF가 생성됩니다. 한 위치를 입력하면 한 횡단입니다.

시작·끝 STA는 유효 범위 검사에 사용합니다. 노선 안에서 길이 1m 이상의 범위를 지정해야 합니다. 지정 STA는 이 범위 안에 있어야 하며 양 끝은 허용합니다. 범위 양 끝, 정규 측점, PI/PVI/곡선 경계는 자동 추가하지 않습니다. 기본값은 꺼짐이며 기존 일괄 출력 동작을 유지합니다.

## 처리와 제한

- 최대 100개 입력, 오름차순 정렬, 1e-7m 이내 중복 병합입니다. 빈 목록·빈 토큰·유한하지 않은 값·구간 밖 STA는 실패합니다.
- 정규 측점 간격과 주요 경계 선택은 비활성화되지만 값은 보존됩니다. 선택 모드를 끄면 다시 적용됩니다.
- 선택 모드는 정규 측점을 만들지 않으므로 장거리 노선에서 정규 측점 수 제한에 걸리지 않습니다. 전체 100000표본 및 격자 개수 제한은 유지합니다.
- 조사 반폭, 횡단 간격, 배치 열 수와 격자 옵션을 적용합니다. H:V=1:1, 미터 단위, Z=0, 원래 STA, 결측 선 끊기 및 각 횡단의 DATUM을 유지합니다.
- DXF 999 주석 `SECTION_STATION_MODE=EXPLICIT_ONLY`로 출력 모드를 기록합니다.
- 옵션/입력/설계/DEM 변경 시 이전 결과를 폐기합니다. 설계·현재 STA·Undo 이력은 변경하지 않습니다.
- 네이티브 DLL v018 및 프로젝트 형식 v7은 그대로 사용합니다.

## 검증

`verify_section_selected.gd`: 단일/여러 위치/양 끝, 중복 정렬, 빈 입력과 잘못된 범위, 자동 측점 제외, 100km 노선, 표본 제한, 기본 출력 동일성을 검사합니다.

`verify_section_selected_ui.gd`: 현재 STA 한 장 저장, 비활성화/복원, 빈 목록 오류, 작업 중 변경 및 오래된 결과 저장 차단, 설계·이력 불변을 검사합니다.

`tests/verify_section_selected_export.py`: ezdxf로 실제 저장물을 다시 읽고 감사 오류/수정 0건, 정확한 STA, 단일/여러 횡단, 해석 가능한 원지반/설계 표고와 격자를 검사합니다.


```powershell
$env:APPDATA="$PWD\work\godot-appdata"
& ..\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path godot/project --script res://verify_section_selected.gd
& ..\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path godot/project --script res://verify_section_selected_ui.gd
python tests/verify_section_selected_export.py
```
