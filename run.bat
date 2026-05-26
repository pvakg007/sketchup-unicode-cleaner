@echo off
echo ========================================
echo SketchUp Texture Copier Tool
echo ========================================
echo.
echo Select mode:
echo   1. GUI Mode (Recommended)
echo   2. Analyze SKP file format
echo   3. Exit
echo.
set /p choice="Enter option (1-3): "

if "%choice%"=="1" goto gui
if "%choice%"=="2" goto analyze
if "%choice%"=="3" goto end
echo Invalid option
pause
exit

:gui
echo Starting GUI...
python skp_texture_copier_gui.py
pause
exit

:analyze
echo Analyze SKP file format...
set /p skp_path="Enter SKP file path: "
python analyze_skp.py "%skp_path%"
pause
exit

:end
echo Exit
exit