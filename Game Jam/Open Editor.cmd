@echo off
setlocal

rem Prefer a private engine when a distribution includes one, but do not require it.
set "GODOT=%~dp0.runtime\Godot.exe"
if exist "%GODOT%" goto run

where Godot.exe >nul 2>nul && set "GODOT=Godot.exe" && goto run
where godot.exe >nul 2>nul && set "GODOT=godot.exe" && goto run

echo.
echo No se encontro Godot 4.7 en .runtime ni en PATH.
echo Instala Godot 4.7.x y abre project.godot desde Godot.
pause
exit /b 1

:run
start "Godot Level Designer" "%GODOT%" --editor --path "%~dp0." res://rooms/room_01.tscn
