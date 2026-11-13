@echo off
setlocal
if not defined GODOT_BIN set "GODOT_BIN=%~dp0..\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
 echo Set GODOT_BIN to the full path of your Godot 4.7.2 executable.
 pause
 exit /b 1
)
if not exist "%~dp0godot\project\bin\kroad_core_v016.windows.template_debug.x86_64.dll" (
 echo Build the C++ extension first. See README.md.
 pause
 exit /b 1
)
set "APPDATA=%~dp0work\appdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%~dp0godot\project\.godot\extension_list.cfg" "%GODOT_BIN%" --headless --path "%~dp0godot\project" --editor --import --quit
"%GODOT_BIN%" --path "%~dp0godot\project" %*
