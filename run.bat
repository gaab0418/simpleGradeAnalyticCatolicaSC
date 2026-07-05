@echo off
title TOTVS RM Central de Notas
echo ===================================================
echo   TOTVS RM - Central de Notas (Porta 8080)
echo ===================================================
echo.
echo [*] Iniciando o servidor Python local...
python server.py
if %errorlevel% neq 0 (
    echo.
    echo [!] Ocorreu um erro ao iniciar o servidor. Verifique se o Python esta no PATH.
)
pause
