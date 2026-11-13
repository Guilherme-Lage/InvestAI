@echo off
rem Sobe o InvestAI para ser aberto pelo navegador do celular na mesma rede.
cd /d "%~dp0"

start "InvestAI - API" cmd /k "cd backend && set INVESTAI_HOST=0.0.0.0&& python app.py"
start "InvestAI - n8n" cmd /k "cd /d %USERPROFILE% && n8n start"

if not exist frontend_flutter\build\web\index.html (
    echo Compilando o app, leva uns minutos...
    pushd frontend_flutter
    call flutter build web
    popd
)
start "InvestAI - App" cmd /k "python -m http.server 8080 --bind 0.0.0.0 --directory frontend_flutter\build\web"

echo.
echo Abra no navegador do celular:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=*" %%b in ("%%a") do echo     http://%%b:8080
)
echo.
pause
