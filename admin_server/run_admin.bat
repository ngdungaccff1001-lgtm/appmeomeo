@echo off
title MeoMeoPath Admin API Server
echo =======================================================
echo   FIRE MEOMEOPATH ADMIN WEB SERVER (FREE FIRE HUB)
echo =======================================================
echo.
echo Installing requirements...
pip install -r requirements.txt
echo.
echo =======================================================
echo Starting Python Admin Web Server...
echo [!] TRUY CAP WEB ADMIN TREN PC TAI CAC LINK SAU:
echo  1. http://127.0.0.1:5000
echo  2. http://localhost:5000
echo  3. http://127.0.0.1:5000/nxt2007 (Pass: 222007)
echo =======================================================
echo.
python app.py
pause
