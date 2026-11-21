@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Claude Desktop (Secure Sandbox)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-claude-desktop.ps1"
if %errorlevel% neq 0 (
    pause
)
