@echo off
setlocal

rem Get current dir name
for %%D in ("%CD%") do set "dirname=%%~nxD"

if "%1" == "-r" del %dirname%.sms *.lst *.sym >NUL

rem Back up previous build
set n=1

:check
if not exist "old\%dirname%_%n%.sms" goto :dobackup
set /A n+=1
goto check

:dobackup
if not exist %dirname%.sms goto run
if not exist "old/" mkdir "old"
move %dirname%.sms "old\%dirname%_%n%.sms" > NUL

:run
rem Vars so as not to clog PATH
set wla_cpu=%~d0/bin/wladx/wla-z80
set wlalink=%~d0/bin/wladx/wlalink

rem Create object file
echo Creating object file...
%wla_cpu% -o %dirname%.o main.asm

rem Stop if that failed
if not "%ERRORLEVEL%" == "0" exit %ERRORLEVEL%

rem Generate linker script
echo [objects]>linkfile
echo %dirname%.o>>linkfile

rem Link everything
echo Linking...
%wlalink% -S -v linkfile %dirname%.sms

rem Clean up
del %dirname%.o linkfile
endlocal
