@echo off
title MeoMeoPath Admin API Server
echo =======================================================
echo   FIRE MEOMEOPATH ADMIN WEB SERVER (FREE FIRE HUB)
echo =======================================================
echo.
echo Installing requirements...
pip install -r requirements.txt
echo.
echo Starting Python Admin Web Server...
echo 👉 Web Admin: http://127.0.0.1:5000
echo 👉 iOS API:   http://127.0.0.1:5000/api/patches
echo.
python app.py
pause
