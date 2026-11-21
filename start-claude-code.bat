@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Claude Code (Secure Sandbox)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-claude-safe.ps1" %*
if %errorlevel% neq 0 (
    pause
)
