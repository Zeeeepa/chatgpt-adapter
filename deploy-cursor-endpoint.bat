@echo off
setlocal enabledelayedexpansion

:: ChatGPT Adapter - Cursor OpenAI API Endpoint Deployment Script
:: This script helps deploy a Cursor-compatible OpenAI API endpoint
:: with error handling, fallback mechanisms, and user interaction

:: Set console colors
set "RESET=[0m"
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "MAGENTA=[95m"
set "CYAN=[96m"
set "WHITE=[97m"

:: Configuration variables
set "PORT=8080"
set "CONFIG_DIR=config"
set "CONFIG_FILE=config.yaml"
set "DOCKER_IMAGE=ghcr.io/bincooo/chatgpt-adapter:latest"
set "DEFAULT_MODEL=cursor/claude-3.7-sonnet-thinking"
set "LOG_FILE=cursor-deploy.log"
set "RETRY_COUNT=3"
set "TIMEOUT_SECONDS=30"

:: Clear log file
echo. > "%LOG_FILE%"

:: Function to log messages
:log
    echo %~1 >> "%LOG_FILE%"
    goto :eof

:: Function to display banner
:display_banner
    echo %CYAN%=====================================================%RESET%
    echo %CYAN%    Cursor OpenAI API Endpoint Deployment Script     %RESET%
    echo %CYAN%=====================================================%RESET%
    echo.
    goto :eof

:: Function to display error message
:error
    echo %RED%ERROR: %~1%RESET%
    call :log "ERROR: %~1"
    goto :eof

:: Function to display success message
:success
    echo %GREEN%%~1%RESET%
    call :log "SUCCESS: %~1"
    goto :eof

:: Function to display info message
:info
    echo %YELLOW%%~1%RESET%
    call :log "INFO: %~1"
    goto :eof

:: Function to check if a command exists
:check_command
    where %~1 >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        set "COMMAND_EXISTS=0"
    ) else (
        set "COMMAND_EXISTS=1"
    )
    goto :eof

:: Function to check if a file exists
:check_file
    if exist "%~1" (
        set "FILE_EXISTS=1"
    ) else (
        set "FILE_EXISTS=0"
    )
    goto :eof

:: Function to check if a directory exists
:check_directory
    if exist "%~1\" (
        set "DIRECTORY_EXISTS=1"
    ) else (
        set "DIRECTORY_EXISTS=0"
    )
    goto :eof

:: Function to create directory if it doesn't exist
:create_directory
    call :check_directory "%~1"
    if !DIRECTORY_EXISTS! equ 0 (
        mkdir "%~1" 2>nul
        if !ERRORLEVEL! neq 0 (
            call :error "Failed to create directory: %~1"
            exit /b 1
        )
        call :success "Created directory: %~1"
    )
    goto :eof

:: Function to check if Docker is running
:check_docker_running
    docker info >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        set "DOCKER_RUNNING=0"
    ) else (
        set "DOCKER_RUNNING=1"
    )
    goto :eof

:: Function to check if a port is in use
:check_port_in_use
    netstat -ano | findstr ":%~1 " >nul
    if %ERRORLEVEL% equ 0 (
        set "PORT_IN_USE=1"
    ) else (
        set "PORT_IN_USE=0"
    )
    goto :eof

:: Function to find an available port
:find_available_port
    set "START_PORT=%~1"
    set "CURRENT_PORT=%START_PORT%"
    
    :port_loop
    call :check_port_in_use !CURRENT_PORT!
    if !PORT_IN_USE! equ 0 (
        set "AVAILABLE_PORT=!CURRENT_PORT!"
        goto :port_found
    )
    
    set /a "CURRENT_PORT+=1"
    if !CURRENT_PORT! lss 65536 (
        goto :port_loop
    )
    
    set "AVAILABLE_PORT=%START_PORT%"
    call :error "Could not find an available port. Using default: %START_PORT%"
    
    :port_found
    goto :eof

:: Function to create config file
:create_config_file
    set "CONFIG_PATH=%~1\%~2"
    
    echo server: > "%CONFIG_PATH%"
    echo   port: %PORT% >> "%CONFIG_PATH%"
    echo. >> "%CONFIG_PATH%"
    echo cursor: >> "%CONFIG_PATH%"
    echo   enabled: true >> "%CONFIG_PATH%"
    echo   model: >> "%CONFIG_PATH%"
    echo     - %DEFAULT_MODEL% >> "%CONFIG_PATH%"
    echo   cookie: "YOUR_CURSOR_TOKEN_HERE" >> "%CONFIG_PATH%"
    echo   checksum: "" >> "%CONFIG_PATH%"
    
    call :success "Created config file: %CONFIG_PATH%"
    goto :eof

:: Function to check if a process is running on a specific port
:check_process_on_port
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%~1 "') do (
        set "PID=%%a"
        goto :process_found
    )
    set "PID="
    
    :process_found
    goto :eof

:: Function to kill a process by PID
:kill_process
    taskkill /F /PID %~1 >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        call :error "Failed to kill process with PID: %~1"
    ) else (
        call :success "Killed process with PID: %~1"
    )
    goto :eof

:: Function to wait for a service to be available
:wait_for_service
    set "URL=%~1"
    set "ATTEMPTS=0"
    set "MAX_ATTEMPTS=%~2"
    
    :wait_loop
    curl -s -o nul -w "%%{http_code}" "%URL%" > temp_status.txt 2>nul
    set /p STATUS=<temp_status.txt
    del temp_status.txt
    
    if "%STATUS%"=="200" (
        call :success "Service is available at %URL%"
        goto :wait_done
    )
    
    set /a "ATTEMPTS+=1"
    if %ATTEMPTS% lss %MAX_ATTEMPTS% (
        call :info "Waiting for service to be available... Attempt %ATTEMPTS%/%MAX_ATTEMPTS%"
        timeout /t 2 >nul
        goto :wait_loop
    )
    
    call :error "Service did not become available after %MAX_ATTEMPTS% attempts"
    
    :wait_done
    goto :eof

:: Function to test the API endpoint
:test_api_endpoint
    set "URL=%~1"
    set "TOKEN=%~2"
    set "MODEL=%~3"
    
    call :info "Testing API endpoint at %URL% with model %MODEL%..."
    
    echo {"model":"%MODEL%","messages":[{"role":"user","content":"Hello, please respond with a single word: Working"}],"stream":false} > test_request.json
    
    curl -s -X POST "%URL%/v1/chat/completions" ^
        -H "Content-Type: application/json" ^
        -H "Authorization: %TOKEN%" ^
        -d @test_request.json > test_response.json
    
    findstr /C:"Working" test_response.json >nul
    if %ERRORLEVEL% equ 0 (
        call :success "API endpoint test successful!"
        set "API_TEST_SUCCESS=1"
    ) else (
        call :error "API endpoint test failed. See test_response.json for details."
        set "API_TEST_SUCCESS=0"
    )
    
    goto :eof

:: Start of main script
call :display_banner

:: Check for required commands
call :info "Checking for required tools..."

call :check_command "curl"
if %COMMAND_EXISTS% equ 0 (
    call :error "curl is not installed or not in PATH. Please install curl and try again."
    call :info "You can download curl from: https://curl.se/windows/"
    exit /b 1
)

:: Check if Docker is installed
call :check_command "docker"
if %COMMAND_EXISTS% equ 0 (
    call :info "Docker is not installed. Will use local deployment method."
    set "USE_DOCKER=0"
) else (
    call :check_docker_running
    if %DOCKER_RUNNING% equ 0 (
        call :info "Docker is installed but not running. Will use local deployment method."
        set "USE_DOCKER=0"
    ) else (
        call :info "Docker is installed and running. Will use Docker deployment method."
        set "USE_DOCKER=1"
    )
)

:: Check if port is in use
call :check_port_in_use %PORT%
if %PORT_IN_USE% equ 1 (
    call :info "Port %PORT% is already in use."
    
    :: Check if it's our service
    curl -s "http://localhost:%PORT%/v1/models" > port_check.txt 2>&1
    findstr /C:"cursor" port_check.txt >nul
    if %ERRORLEVEL% equ 0 (
        call :info "It appears that the ChatGPT Adapter is already running on port %PORT%."
        choice /C YN /M "Do you want to stop it and restart?"
        if !ERRORLEVEL! equ 1 (
            call :check_process_on_port %PORT%
            if defined PID (
                call :kill_process !PID!
            )
        ) else (
            call :find_available_port %PORT%
            set "PORT=!AVAILABLE_PORT!"
            call :info "Using alternative port: %PORT%"
        )
    ) else (
        call :find_available_port %PORT%
        set "PORT=!AVAILABLE_PORT!"
        call :info "Using alternative port: %PORT%"
    )
    del port_check.txt
)

:: Create config directory and file
call :create_directory "%CONFIG_DIR%"
call :check_file "%CONFIG_DIR%\%CONFIG_FILE%"
if %FILE_EXISTS% equ 0 (
    call :create_config_file "%CONFIG_DIR%" "%CONFIG_FILE%"
)

:: Get Cursor token
call :info "You need a Cursor session token to use this service."
echo %CYAN%There are two ways to get your token:%RESET%
echo %CYAN%1. Automatic login (recommended)%RESET%
echo %CYAN%2. Manual extraction from browser%RESET%
echo.

choice /C 12 /M "Choose an option"
if %ERRORLEVEL% equ 1 (
    :: Automatic login
    call :info "Automatic login selected."
    
    :: Check if cursor-login.exe exists
    call :check_file "bin\windows\cursor-login.exe"
    if %FILE_EXISTS% equ 1 (
        call :info "Running cursor login tool..."
        bin\windows\cursor-login.exe
        if %ERRORLEVEL% neq 0 (
            call :error "Cursor login failed. Please try manual extraction."
            goto :manual_token
        )
    ) else (
        call :info "Cursor login tool not found. Checking if we can build it..."
        
        call :check_command "go"
        if %COMMAND_EXISTS% equ 0 (
            call :error "Go is not installed. Cannot build cursor login tool."
            goto :manual_token
        )
        
        call :info "Building cursor login tool..."
        mkdir bin\windows 2>nul
        go build -o bin\windows\cursor-login.exe cmd\cursor-login\main.go
        
        if %ERRORLEVEL% neq 0 (
            call :error "Failed to build cursor login tool. Please try manual extraction."
            goto :manual_token
        )
        
        call :info "Running cursor login tool..."
        bin\windows\cursor-login.exe
        if %ERRORLEVEL% neq 0 (
            call :error "Cursor login failed. Please try manual extraction."
            goto :manual_token
        )
    )
    
    :: Read token from config file
    for /f "tokens=2 delims=:" %%a in ('findstr /C:"cookie:" "%CONFIG_DIR%\%CONFIG_FILE%"') do (
        set "CURSOR_TOKEN=%%a"
    )
    
    :: Clean up token (remove quotes and spaces)
    set "CURSOR_TOKEN=!CURSOR_TOKEN:"=!"
    set "CURSOR_TOKEN=!CURSOR_TOKEN: =!"
    
    if "!CURSOR_TOKEN!"=="YOUR_CURSOR_TOKEN_HERE" (
        call :error "Token was not properly saved to config file."
        goto :manual_token
    )
    
    call :success "Token retrieved successfully!"
) else (
    :: Manual extraction
    :manual_token
    call :info "Manual extraction selected."
    echo %CYAN%Please follow these steps to get your Cursor token:%RESET%
    echo %CYAN%1. Open Chrome and go to https://cursor.com (make sure you're logged in)%RESET%
    echo %CYAN%2. Press F12 to open Developer Tools%RESET%
    echo %CYAN%3. Go to the "Application" tab%RESET%
    echo %CYAN%4. In the left sidebar, click on "Cookies" under "Storage"%RESET%
    echo %CYAN%5. Find the WorkosCursorSessionToken cookie and copy its value%RESET%
    echo.
    
    set /p CURSOR_TOKEN="Enter your Cursor token: "
    
    :: Update config file with token
    powershell -Command "(Get-Content '%CONFIG_DIR%\%CONFIG_FILE%') -replace 'cookie: \".*\"', 'cookie: \"%CURSOR_TOKEN%\"' | Set-Content '%CONFIG_DIR%\%CONFIG_FILE%'"
    
    call :success "Token saved to config file!"
)

:: Deploy the service
if %USE_DOCKER% equ 1 (
    :: Docker deployment
    call :info "Deploying with Docker..."
    
    :: Check if container is already running
    docker ps | findstr "chatgpt-adapter" >nul
    if %ERRORLEVEL% equ 0 (
        call :info "ChatGPT Adapter container is already running."
        choice /C YN /M "Do you want to stop it and restart?"
        if !ERRORLEVEL! equ 1 (
            call :info "Stopping existing container..."
            docker stop chatgpt-adapter >nul 2>&1
            docker rm chatgpt-adapter >nul 2>&1
        ) else (
            call :info "Keeping existing container running."
            goto :deployment_complete
        )
    )
    
    :: Pull the latest image
    call :info "Pulling the latest Docker image..."
    docker pull %DOCKER_IMAGE%
    
    :: Run the container
    call :info "Starting Docker container..."
    docker run -d --name chatgpt-adapter -p %PORT%:8080 -v "%cd%\%CONFIG_DIR%\%CONFIG_FILE%:/app/config.yaml" %DOCKER_IMAGE%
    
    if %ERRORLEVEL% neq 0 (
        call :error "Failed to start Docker container."
        call :info "Falling back to local deployment..."
        goto :local_deployment
    )
    
    call :success "Docker container started successfully!"
) else (
    :: Local deployment
    :local_deployment
    call :info "Deploying locally..."
    
    :: Check if server.exe exists
    call :check_file "bin\windows\server.exe"
    if %FILE_EXISTS% equ 0 (
        call :info "Server executable not found. Checking if we can build it..."
        
        call :check_command "go"
        if %COMMAND_EXISTS% equ 0 (
            call :error "Go is not installed. Cannot build server."
            call :info "Please install Go from https://golang.org/dl/"
            exit /b 1
        )
        
        call :info "Building server..."
        mkdir bin\windows 2>nul
        
        :: Check if iocgo is installed
        call :check_command "iocgo"
        if %COMMAND_EXISTS% equ 0 (
            call :info "Installing iocgo tool..."
            go install -ldflags="-s -w" -trimpath ./cmd/iocgo
            if %ERRORLEVEL% neq 0 (
                call :error "Failed to install iocgo tool."
                exit /b 1
            )
        )
        
        :: Build the server
        set "CGO_ENABLED=0"
        set "GOARCH=amd64"
        set "GOOS=windows"
        go build -toolexec iocgo -ldflags="-s -w" -o bin\windows\server.exe -trimpath main.go
        
        if %ERRORLEVEL% neq 0 (
            call :error "Failed to build server."
            exit /b 1
        )
        
        call :success "Server built successfully!"
    )
    
    :: Start the server
    call :info "Starting server on port %PORT%..."
    start "ChatGPT Adapter" /B bin\windows\server.exe --port %PORT%
    
    if %ERRORLEVEL% neq 0 (
        call :error "Failed to start server."
        exit /b 1
    )
    
    call :success "Server started successfully!"
)

:deployment_complete
:: Wait for service to be available
call :wait_for_service "http://localhost:%PORT%/v1/models" %RETRY_COUNT%

:: Test the API endpoint
call :test_api_endpoint "http://localhost:%PORT%" "%CURSOR_TOKEN%" "%DEFAULT_MODEL%"

if %API_TEST_SUCCESS% equ 1 (
    :: Display success message
    echo.
    echo %GREEN%=====================================================%RESET%
    echo %GREEN%       Deployment Completed Successfully!            %RESET%
    echo %GREEN%=====================================================%RESET%
    echo.
    echo %CYAN%The Cursor OpenAI API endpoint is now running at:%RESET%
    echo %CYAN%http://localhost:%PORT%%RESET%
    echo.
    echo %CYAN%Available models:%RESET%
    echo %CYAN%- cursor/claude-3.7-sonnet%RESET%
    echo %CYAN%- cursor/claude-3.7-sonnet-thinking%RESET%
    echo %CYAN%- cursor/claude-3-opus%RESET%
    echo %CYAN%- cursor/claude-3.5-haiku%RESET%
    echo %CYAN%- cursor/claude-3.5-sonnet%RESET%
    echo %CYAN%- cursor/gpt-4o%RESET%
    echo %CYAN%- cursor/gpt-4o-mini%RESET%
    echo %CYAN%- cursor/gpt-4-turbo-2024-04-09%RESET%
    echo %CYAN%- cursor/gpt-4%RESET%
    echo %CYAN%- cursor/gpt-3.5-turbo%RESET%
    echo %CYAN%- cursor/o1-mini%RESET%
    echo %CYAN%- cursor/o1-preview%RESET%
    echo.
    echo %CYAN%Example curl request:%RESET%
    echo %CYAN%curl http://localhost:%PORT%/v1/chat/completions ^%RESET%
    echo %CYAN%  -H "Content-Type: application/json" ^%RESET%
    echo %CYAN%  -H "Authorization: %CURSOR_TOKEN%" ^%RESET%
    echo %CYAN%  -d '{%RESET%
    echo %CYAN%    "model": "%DEFAULT_MODEL%",%RESET%
    echo %CYAN%    "messages": [%RESET%
    echo %CYAN%      {%RESET%
    echo %CYAN%        "role": "user",%RESET%
    echo %CYAN%        "content": "Hello, can you help me with some code?"%RESET%
    echo %CYAN%      }%RESET%
    echo %CYAN%    ],%RESET%
    echo %CYAN%    "stream": true%RESET%
    echo %CYAN%  }'%RESET%
    echo.
    echo %CYAN%To use this endpoint with applications that support OpenAI API:%RESET%
    echo %CYAN%1. Set the API base URL to: http://localhost:%PORT%%RESET%
    echo %CYAN%2. Set the API key to your Cursor token%RESET%
    echo %CYAN%3. Select one of the cursor models listed above%RESET%
    echo.
    
    if %USE_DOCKER% equ 1 (
        echo %CYAN%To stop the Docker container:%RESET%
        echo %CYAN%docker stop chatgpt-adapter%RESET%
        echo.
        echo %CYAN%To restart the Docker container:%RESET%
        echo %CYAN%docker start chatgpt-adapter%RESET%
    ) else (
        echo %CYAN%To stop the server, press Ctrl+C in the server window or use Task Manager%RESET%
    )
    echo.
    echo %CYAN%Logs are available in: %LOG_FILE%%RESET%
) else (
    :: Display error message
    echo.
    echo %RED%=====================================================%RESET%
    echo %RED%       Deployment Completed With Errors!            %RESET%
    echo %RED%=====================================================%RESET%
    echo.
    echo %YELLOW%The service is running but the API test failed.%RESET%
    echo %YELLOW%Please check the following:%RESET%
    echo %YELLOW%1. Your Cursor token may be invalid or expired%RESET%
    echo %YELLOW%2. The service may not be fully initialized yet%RESET%
    echo %YELLOW%3. There might be network connectivity issues%RESET%
    echo.
    echo %YELLOW%You can try again by:%RESET%
    echo %YELLOW%1. Stopping the current service%RESET%
    echo %YELLOW%2. Getting a fresh Cursor token%RESET%
    echo %YELLOW%3. Running this script again%RESET%
    echo.
    echo %YELLOW%Logs are available in: %LOG_FILE%%RESET%
)

echo.
echo %CYAN%Press any key to exit...%RESET%
pause >nul

endlocal

