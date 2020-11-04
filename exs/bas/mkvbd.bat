@echo off

bcv.exe /o /fpi /r /e %1;

link16.exe /stack:1024 /ex /e /noe %1,,nul,vbdcl10e+..\..\lib\dsockvbd;

if exist %1.exe move /y %1.exe ..\..\bin

if exist %1.obj del %1.obj

