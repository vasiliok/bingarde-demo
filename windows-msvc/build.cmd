@echo off
rem Builds every line of variants.txt with MSVC ("project branch build revision config arch").
rem Run from the folder that holds engine.c, engine.h, main_cli.c and variants.txt.
setlocal EnableDelayedExpansion
set "VSDEV="
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDEV=%%i"
if not defined VSDEV (echo MSVC not found & exit /b 1)
call "%VSDEV%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || exit /b 1
for /f "tokens=1-6" %%a in (variants.txt) do call :build %%a %%b %%c %%d %%e %%f || exit /b 1
exit /b 0

:build
set "PROJECT=%~1" & set "BRANCH=%~2" & set "BUILD=%~3" & set "REV=%~4" & set "CONFIG=%~5" & set "ARCH=%~6"
set "DIR=out\%PROJECT%\%BRANCH%\%BUILD%\windows-%CONFIG%-%ARCH%"
if exist "%DIR%" rmdir /s /q "%DIR%"
mkdir "%DIR%\obj"
if "%CONFIG%"=="debug" (set "OPT=/Od /MDd") else (set "OPT=/O2 /MD")
(
  echo $ cl
  cl 2>&1 | findstr /b "Microsoft"
  echo $ cl /nologo /W4 /Zi %OPT% /DPROJECT=... engine.c main_cli.c /link /DEBUG:FULL /INCREMENTAL:NO /PDB:DemoApp.pdb
  cl /nologo /W4 /Zi %OPT% /DPROJECT=\"%PROJECT%\" /DBRANCH=\"%BRANCH%\" /DBUILD_NUMBER=%BUILD% /DREVISION=\"%REV%\" ^
     /Fo"%DIR%\obj\\" /Fd"%DIR%\obj\vc.pdb" engine.c main_cli.c /Fe"%DIR%\DemoApp.exe" ^
     /link /DEBUG:FULL /INCREMENTAL:NO /PDB:"%DIR%\DemoApp.pdb" /PDBALTPATH:%%_PDB%%
  echo build finished
) > "%DIR%\build.log" 2>&1
if not exist "%DIR%\DemoApp.exe" (type "%DIR%\build.log" & exit /b 1)
rem x64 builds run on this PC: real self-test results.
if "%ARCH%"=="x86_64" "%DIR%\DemoApp.exe" --self-test > "%DIR%\tests.junit.xml"
for /f "tokens=*" %%v in ('cl 2^>^&1 ^| findstr /b "Microsoft"') do set "COMPILER=%%v"
> "%DIR%\meta.json" echo {"platform": "windows", "config": "%CONFIG%", "arch": "%ARCH%", "compiler": "!COMPILER!", "triple": "x86_64-pc-windows-msvc"}
rmdir /s /q "%DIR%\obj"
echo windows %CONFIG% %ARCH%: %DIR%
exit /b 0
