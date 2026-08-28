@echo off
setlocal EnableExtensions
title MindSet Launcher

cd /d "%~dp0"
set "ROOT=%CD%"
set "API_DIR=%ROOT%\understanding_ai"
set "APP_DIR=%ROOT%\mindset"
set "VENV=%API_DIR%\.venv"
set "VENV_PYTHON=%VENV%\Scripts\python.exe"
set "DEPS_MARKER=%VENV%\.mindset_dependencies_installed"

echo ============================================================
echo                  MindSet Application Launcher
echo ============================================================
echo.

rem ------------------------------------------------------------
rem Basic project checks
rem ------------------------------------------------------------
if not exist "%API_DIR%\api.py" (
    echo [ERROR] understanding_ai\api.py was not found.
    echo Place this BAT file in the root of the MindSet repository.
    pause
    exit /b 1
)

if not exist "%APP_DIR%\pubspec.yaml" (
    echo [ERROR] mindset\pubspec.yaml was not found.
    echo Place this BAT file in the root of the MindSet repository.
    pause
    exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python was not found on PATH.
    echo Install Python and make sure "python" works in Command Prompt.
    pause
    exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter was not found on PATH.
    echo Install Flutter and run "flutter doctor" before using this launcher.
    pause
    exit /b 1
)

echo [1/6] Checking Git LFS model files...
where git >nul 2>&1
if not errorlevel 1 (
    git lfs version >nul 2>&1
    if not errorlevel 1 (
        git lfs pull
        if errorlevel 1 (
            echo [WARNING] Git LFS could not complete.
            echo If model files are missing, run: git lfs pull
        )
    ) else (
        echo [WARNING] Git LFS is not installed.
        echo Large AI model files may be unavailable.
    )
) else (
    echo [WARNING] Git was not found. Skipping Git LFS check.
)

echo.
echo [2/6] Preparing Python virtual environment...
if not exist "%VENV_PYTHON%" (
    echo Creating .venv...
    python -m venv "%VENV%"
    if errorlevel 1 (
        echo [ERROR] Failed to create the Python virtual environment.
        pause
        exit /b 1
    )
)

if not exist "%DEPS_MARKER%" (
    echo.
    echo Installing Python dependencies for the first run...
    echo This can take some time because PyTorch and AI packages are large.
    "%VENV_PYTHON%" -m pip install --upgrade pip
    if errorlevel 1 goto :pip_error

    if exist "%API_DIR%\requirements_api.txt" (
        "%VENV_PYTHON%" -m pip install -r "%API_DIR%\requirements_api.txt"
        if errorlevel 1 goto :pip_error
    )

    if exist "%API_DIR%\audio_emotion\requirements_audio.txt" (
        "%VENV_PYTHON%" -m pip install -r "%API_DIR%\audio_emotion\requirements_audio.txt"
        if errorlevel 1 goto :pip_error
    )

    if exist "%API_DIR%\requirements_stt.txt" (
        "%VENV_PYTHON%" -m pip install -r "%API_DIR%\requirements_stt.txt"
        if errorlevel 1 goto :pip_error
    )

    >"%DEPS_MARKER%" echo MindSet Python dependencies installed.
) else (
    echo Python environment already prepared.
)

echo.
echo [3/6] Installing Flutter packages...
pushd "%APP_DIR%"
flutter pub get
if errorlevel 1 (
    popd
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)
popd

echo.
echo [4/6] Starting MindSet FastAPI backend...
start "MindSet AI API" cmd /k "cd /d ""%API_DIR%"" && ""%VENV_PYTHON%"" -m uvicorn api:app --host 0.0.0.0 --port 8000"

echo.
echo [5/6] Waiting for the API health check...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ready=$false; for($i=0; $i -lt 90; $i++){ try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8000/health' -TimeoutSec 2; if($r.StatusCode -eq 200){$ready=$true; break} } catch {} ; Start-Sleep -Seconds 2 }; if(-not $ready){exit 1}"

if errorlevel 1 (
    echo.
    echo [WARNING] The API did not become ready automatically.
    echo Check the "MindSet AI API" window for model-loading errors.
    echo You may still continue once the API is ready.
    echo.
    pause
) else (
    echo API is ready at http://127.0.0.1:8000
)

echo.
echo Optional physical-phone note:
echo - Android emulator default API: http://10.0.2.2:8000/predict
echo - Physical phone: use the PC LAN IP or a Cloudflare tunnel
echo   and update the API endpoint in the MindSet Settings page.
echo.

echo [6/6] Starting Flutter application...
echo.
echo Available devices:
flutter devices
echo.

pushd "%APP_DIR%"
flutter run
set "FLUTTER_EXIT=%ERRORLEVEL%"
popd

echo.
if not "%FLUTTER_EXIT%"=="0" (
    echo Flutter exited with code %FLUTTER_EXIT%.
) else (
    echo MindSet Flutter session ended.
)

echo The FastAPI window may still be open and can be closed manually.
pause
exit /b %FLUTTER_EXIT%

:pip_error
echo.
echo [ERROR] Python dependency installation failed.
echo Check the messages above, then run the installation commands
echo manually from the understanding_ai folder.
pause
exit /b 1
