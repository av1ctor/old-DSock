@echo off
set TPPATH=c:\prg\cmp\tp

tpc.exe -T%TPPATH% -U%TPPATH%\units;..\..\lib -$E- -$D+ -$G+ -$L+ -$N+ -$S- %1

if exist %1.exe move /y %1.exe ..\..\bin

set TPPATH=
