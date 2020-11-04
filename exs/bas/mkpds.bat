@echo off

bcx.exe /o /Lr /fpi /r /e /Fs %1;

link16.exe /stack:1024 /ex /e /noe %1,,nul,bcl71efr+..\..\lib\dsockpds;

if exist %1.exe move /y %1.exe ..\..\bin

if exist %1.obj del %1.obj

