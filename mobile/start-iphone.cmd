@echo off
setlocal
title Recycli - iPhone Expo Go
cd /d "%~dp0"
where node.exe >nul 2>&1
if errorlevel 1 goto missing_node
if not exist "node_modules\expo\bin\cli" goto missing_dependencies
node.exe "node_modules\expo\bin\cli" whoami
if not errorlevel 1 goto start_tunnel
node.exe "node_modules\expo\bin\cli" login
if errorlevel 1 goto failed
:start_tunnel
echo Sign into Expo Go on your iPhone with the same Expo account.
echo Wait for Tunnel ready and an exp.direct address, then scan the NEW QR code.
echo Keep this window open. Both devices need internet access.
node.exe "node_modules\expo\bin\cli" start --go --tunnel --port 0
if errorlevel 1 goto failed
exit /b 0
:missing_node
echo Install Node.js 24, reopen PowerShell, and run this launcher again.
goto failed
:missing_dependencies
echo Run npm.cmd ci from this mobile folder, then run this launcher again.
:failed
echo Startup stopped. Keep the error above for troubleshooting.
pause
exit /b 1
