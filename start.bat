@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Claude Stealth Sandbox Hub
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0menu.ps1"
if %errorlevel% neq 0 (
    pause
)
