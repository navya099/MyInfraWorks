# MyInfraWorks

MyInfraWorks는 infraworks 대체 프레임워크를 개발하는 프로젝트입니다.

대한민국 SRTM 30m DEM을 활용한 Windows용 개략 노선설계 도구를 개발합니다. 목표 범위는 기본계획·예비타당성 검토 수준의 평면·종단선형, 종단·횡단 뷰, 지형 메시, 실시간 절성토 지형 미리보기입니다.

## 현재 상태

- `legacy/wpf`: 작동하는 WPF 시제품 0.2. DEM 열기, 직선 노선 작성, 계획고 변경, 종단·횡단·3D 표시, 단순 사면, 프로젝트 저장·복원을 지원합니다.
- `godot`: Godot + C++로 전환하기 위한 GDExtension 기반입니다. x64 DLL 빌드, Godot 로드, 표고 보간 함수 호출까지 검증했습니다. **Godot 도로 편집기는 아직 구현되지 않았습니다.**
- `tests`: WPF 계산 코어 검사와 합성 GeoTIFF 변환 검사입니다.

## 준비

- Windows x64
- Visual Studio 2022: C++ 데스크톱 개발, MSVC v143, Windows SDK/UCRT
- Python 3.11 이상 / Git
- Godot 4.7.2 표준 Windows 버전
- WPF 시제품에만 .NET 9 SDK 필요

```powershell
git clone --recurse-submodules https://github.com/navya099/MyInfraWorks.git
cd MyInfraWorks
python -m pip install -r requirements-dev.txt
```

이미 복제했다면 `git submodule update --init --recursive`를 실행합니다. Godot 실행 파일은 별도로 설치합니다. `godot-cpp`는 검증한 4.5 API 커밋으로 고정되어 있고, 해당 확장의 Godot 4.7.2 로드를 확인했습니다. 의존성 소스의 라이선스는 해당 서브모듈을 참조하세요.

## WPF 시제품 실행

```powershell
dotnet run --project legacy/wpf/KRoadPrototype.csproj -c Release
```

시작 시 합성 지형이 표시됩니다. `DEM 열기`로 GeoTIFF를 선택합니다.

1. 평면 지형 안을 차례대로 클릭해 노선 점을 추가합니다.
2. 종단에서 클릭하면 측점상 가장 가까운 제어점의 계획고가 바뀝니다.
3. 폭·높이 보정·사면비를 입력하고 적용합니다. 사면비는 H:V입니다.
4. 횡단 슬라이더로 측점을 선택합니다. 초록은 원지반, 주황은 계획입니다.
5. 3D에서 드래그로 회전하고 휠로 확대합니다.
6. `.kroad` 형식으로 저장하고 다시 열 수 있습니다.

실제 DEM 로드는 Python의 rasterio를 사용합니다. EPSG:5179 수평 좌표계로 재투영하고 최대 161×161 격자로 축소합니다. 높이는 미터라고 가정하고 수직 기준 변환은 하지 않습니다. 원본 DEM을 수정하지 않습니다.

제한: DEM 한 타일, 직선 연결 노선·구배, 단순 사면만 지원합니다. 원곡선·완화곡선·종단곡선·편경사·토공량·실행 취소는 아직 없습니다. 축소 격자보다 좁은 도로·사면의 3D 표현은 부정확할 수 있습니다. 복잡한 사면 중첩과 도로 끝단 사면은 처리하지 않습니다.

## Godot C++ 빌드 및 검증

저장소 루트에서 실행합니다.

```powershell
python -m SCons -C godot platform=windows target=template_debug arch=x86_64 build_profile=build_profile.json -j4
```

생성 파일은 `godot/project/bin/kroad_core.windows.template_debug.x86_64.dll`입니다. 아래 `godot` 명령은 설치한 Godot 실행 파일 경로로 바꿔 실행해도 됩니다.

```powershell
godot --headless --path godot/project --editor --import --quit
godot --headless --path godot/project --script verify.gd
```

정상 출력: `PASS: K-ROAD C++ / MSVC x64 / GDExtension / elevation = 125m`

## 검사

```powershell
dotnet run --project tests/CoreTests -c Release
python tests/verify_dem.py
```

합성 DEM 검사는 `work/`에 임시 TIFF를 생성합니다. 사용자 DEM의 정확도를 검증하는 검사는 아닙니다.

## 다음 개발 범위

Godot의 지형 표시와 Orbit 카메라를 구현하고, 선형·사면 계산을 C++ 코어로 이전합니다. 화면 표시와 계산을 분리하며, 노선 편집 시 영향받는 지형 구간만 갱신하는 구조를 목표로 합니다. 이후 평면·종단곡선과 다중 타일을 추가합니다.

## 저장소 관리

DEM 원본, 사용자 프로젝트, Godot 실행 파일, 빌드 결과와 캐시는 커밋하지 않습니다. 기능 단위로 빌드·검사 후 커밋합니다. 현재 코드의 동작 여부와 계획 중인 기능을 구분해 기록합니다.
