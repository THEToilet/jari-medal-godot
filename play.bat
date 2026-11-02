@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "MODE=%~1"
set "GODOT_EXE="

call :find_godot
if not defined GODOT_EXE (
  pause
  exit /b 1
)

rem 素材のインポート（新しく追加した画像を毎回取り込む。変更がなければすぐ終わる）
echo 素材を確認しています...
"%GODOT_EXE%" --headless --path "%~dp0." --import --log-file "%~dp0import.log"

if /i "%MODE%"=="edit" (
  start "" "%GODOT_EXE%" --path "%~dp0." -e
) else (
  start "" "%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0godot.log"
)
exit /b 0


rem ---------------------------------------------------------------
rem Godot の実行ファイルを探す
rem  1. 環境変数 GODOT
rem  2. godot_path.txt（前回見つけた場所を保存）
rem  3. PATH 上の godot.exe / godot4.exe
rem  4. よくある置き場所（デスクトップ、ダウンロード、Steam など）
rem  5. 見つからなければドラッグ＆ドロップで指定
rem ---------------------------------------------------------------
:find_godot
if defined GODOT if exist "%GODOT%" (
  set "GODOT_EXE=%GODOT%"
  exit /b
)
if exist "godot_path.txt" set /p GODOT_EXE=<"godot_path.txt"
if defined GODOT_EXE if exist "%GODOT_EXE%" exit /b
set "GODOT_EXE="

for %%n in (godot.exe godot4.exe) do (
  for /f "delims=" %%p in ('where %%n 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%p"
)
if defined GODOT_EXE goto :save

echo Godot を探しています...
call :scan "%USERPROFILE%\Desktop"
call :scan "%USERPROFILE%\Downloads"
call :scan "%LOCALAPPDATA%\Programs"
call :scan "%USERPROFILE%\scoop\apps"
call :scan "C:\Godot"
call :scan "%ProgramFiles%\Godot"
call :scan "%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine"
call :scan "%ProgramFiles%\Steam\steamapps\common\Godot Engine"
call :scan "%USERPROFILE%\Documents"
if defined GODOT_EXE goto :save

echo.
echo Godot の実行ファイルが見つかりませんでした。
echo Godot_v4.x_win64.exe をこのウィンドウにドラッグ＆ドロップして Enter を押してください。
set /p "GODOT_EXE=> "
if not defined GODOT_EXE exit /b
set "GODOT_EXE=%GODOT_EXE:"=%"
if not exist "%GODOT_EXE%" (
  echo 見つかりません: %GODOT_EXE%
  set "GODOT_EXE="
  exit /b
)

:save
> "godot_path.txt" echo %GODOT_EXE%
echo Godot: %GODOT_EXE%
exit /b

:scan
if defined GODOT_EXE exit /b
if not exist "%~1" exit /b
for /r "%~1" %%f in (Godot_v4*_win64.exe godot.windows.opt.tools.64.exe) do (
  if not defined GODOT_EXE if exist "%%f" set "GODOT_EXE=%%f"
)
exit /b
