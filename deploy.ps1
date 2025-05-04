# ChatGPT Adapter Deployment Script for Windows
# This script helps deploy the ChatGPT Adapter on Windows systems

# Configuration variables
$PORT = 8080
$CONFIG_FILE = "config.yaml"

# Function to check if a command exists
function Test-Command {
    param (
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Function to display colored messages
function Write-ColoredMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# Display banner
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage "       ChatGPT Adapter Deployment for Windows       " "Cyan"
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage ""

# Check if Go is installed
if (-not (Test-Command "go")) {
    Write-ColoredMessage "Error: Go is not installed or not in PATH." "Red"
    Write-ColoredMessage "Please install Go from https://golang.org/dl/" "Yellow"
    exit 1
}

# Check Go version
$goVersion = (go version) -replace "go version go([0-9]+\.[0-9]+).*", '$1'
Write-ColoredMessage "Detected Go version: $goVersion" "Green"

# Check if Git is installed
if (-not (Test-Command "git")) {
    Write-ColoredMessage "Error: Git is not installed or not in PATH." "Red"
    Write-ColoredMessage "Please install Git from https://git-scm.com/download/win" "Yellow"
    exit 1
}

# Create directories if they don't exist
if (-not (Test-Path "bin\windows")) {
    New-Item -ItemType Directory -Path "bin\windows" -Force | Out-Null
    Write-ColoredMessage "Created bin\windows directory" "Green"
}

# Install iocgo tool
Write-ColoredMessage "Installing iocgo tool..." "Yellow"
try {
    go install -ldflags="-s -w" -trimpath ./cmd/iocgo
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install iocgo"
    }
    Write-ColoredMessage "Successfully installed iocgo tool" "Green"
} catch {
    Write-ColoredMessage "Error installing iocgo tool: $_" "Red"
    exit 1
}

# Build the application
Write-ColoredMessage "Building the application for Windows..." "Yellow"
try {
    $env:CGO_ENABLED = 0
    $env:GOARCH = "amd64"
    $env:GOOS = "windows"
    go build -toolexec iocgo -ldflags="-s -w" -o bin\windows\server.exe -trimpath main.go
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build application"
    }
    Write-ColoredMessage "Successfully built application" "Green"
} catch {
    Write-ColoredMessage "Error building application: $_" "Red"
    exit 1
}

# Create a basic configuration file if it doesn't exist
if (-not (Test-Path $CONFIG_FILE)) {
    Write-ColoredMessage "Creating default configuration file..." "Yellow"
    @"
server:
  port: $PORT
"@ | Out-File -FilePath $CONFIG_FILE -Encoding utf8
    Write-ColoredMessage "Created default configuration file: $CONFIG_FILE" "Green"
} else {
    Write-ColoredMessage "Configuration file already exists: $CONFIG_FILE" "Green"
}

# Display success message and instructions
Write-ColoredMessage ""
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage "       Deployment Completed Successfully!           " "Green"
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage ""
Write-ColoredMessage "The ChatGPT Adapter has been built and configured." "White"
Write-ColoredMessage ""
Write-ColoredMessage "To start the server, run:" "Yellow"
Write-ColoredMessage ".\bin\windows\server.exe --port $PORT" "White"
Write-ColoredMessage ""
Write-ColoredMessage "You can customize the configuration in $CONFIG_FILE" "Yellow"
Write-ColoredMessage ""
Write-ColoredMessage "The server will be accessible at:" "Yellow"
Write-ColoredMessage "http://localhost:$PORT" "White"
Write-ColoredMessage ""

# Ask if user wants to start the server now
$startServer = Read-Host "Do you want to start the server now? (y/n)"
if ($startServer -eq "y" -or $startServer -eq "Y") {
    Write-ColoredMessage "Starting the server..." "Yellow"
    try {
        Start-Process -FilePath ".\bin\windows\server.exe" -ArgumentList "--port", "$PORT" -NoNewWindow
        Write-ColoredMessage "Server started successfully!" "Green"
        Write-ColoredMessage "Press Ctrl+C to stop the server" "Yellow"
    } catch {
        Write-ColoredMessage "Error starting server: $_" "Red"
        exit 1
    }
}

