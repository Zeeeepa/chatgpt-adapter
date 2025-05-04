# ChatGPT Adapter Deployment Script for Windows
# This script helps deploy the ChatGPT Adapter on Windows systems

# Configuration variables
$PORT = 8080
$CONFIG_FILE = "config.yaml"
$DOCKER_IMAGE_NAME = "chatgpt-adapter"
$DOCKER_TAG = "latest"

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

# Cursor configuration
cursor:
  # Set to true to enable cursor support
  enabled: true
  # Cursor model options: cursor-fast, cursor-small
  model:
    - cursor-fast
    - cursor-small
  # Your cursor session token (required for authentication)
  # Get this from your browser cookies when logged into cursor.com
  # Look for the WorkosCursorSessionToken cookie
  cookie: ""
  # Optional checksum value (leave empty if not needed)
  checksum: ""
"@ | Out-File -FilePath $CONFIG_FILE -Encoding utf8
    Write-ColoredMessage "Created default configuration file: $CONFIG_FILE" "Green"
    Write-ColoredMessage "IMPORTANT: Please edit $CONFIG_FILE to add your Cursor session token" "Yellow"
} else {
    Write-ColoredMessage "Configuration file already exists: $CONFIG_FILE" "Green"
}

# Check if Docker is installed
$dockerInstalled = Test-Command "docker"
if ($dockerInstalled) {
    Write-ColoredMessage "Docker is installed. You can build and run with Docker." "Green"
    
    # Ask if user wants to build a Docker image
    $buildDocker = Read-Host "Do you want to build a Docker image? (y/n)"
    if ($buildDocker -eq "y" -or $buildDocker -eq "Y") {
        Write-ColoredMessage "Building Docker image..." "Yellow"
        try {
            # Create a temporary Dockerfile for the build
            $dockerfilePath = ".\Dockerfile.tmp"
@"
FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY . .
RUN apk add git make
RUN go install -ldflags="-s -w" -trimpath ./cmd/iocgo
RUN CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build -toolexec iocgo -ldflags="-s -w" -o server -trimpath main.go

FROM alpine:3.19.0
WORKDIR /app
COPY --from=builder /app/server ./server
COPY $CONFIG_FILE ./config.yaml
RUN chmod +x server

ENV ARG "--port $PORT"
CMD ["./server \${ARG}"]
ENTRYPOINT ["sh", "-c"]
"@ | Out-File -FilePath $dockerfilePath -Encoding utf8

            # Build the Docker image
            docker build -t $DOCKER_IMAGE_NAME`:$DOCKER_TAG -f $dockerfilePath .
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to build Docker image"
            }
            
            # Remove the temporary Dockerfile
            Remove-Item $dockerfilePath -Force
            
            Write-ColoredMessage "Successfully built Docker image: $DOCKER_IMAGE_NAME`:$DOCKER_TAG" "Green"
            
            # Ask if user wants to run the Docker container
            $runDocker = Read-Host "Do you want to run the Docker container? (y/n)"
            if ($runDocker -eq "y" -or $runDocker -eq "Y") {
                Write-ColoredMessage "Running Docker container..." "Yellow"
                docker run -d -p $PORT`:$PORT --name chatgpt-adapter $DOCKER_IMAGE_NAME`:$DOCKER_TAG
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to run Docker container"
                }
                Write-ColoredMessage "Docker container is running on port $PORT" "Green"
            }
        } catch {
            Write-ColoredMessage "Error with Docker operations: $_" "Red"
        }
    }
} else {
    Write-ColoredMessage "Docker is not installed. Skipping Docker build options." "Yellow"
    Write-ColoredMessage "To use Docker, install it from https://www.docker.com/products/docker-desktop" "Yellow"
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
Write-ColoredMessage "IMPORTANT: For Cursor support, edit $CONFIG_FILE to add your Cursor session token" "Yellow"
Write-ColoredMessage ""
Write-ColoredMessage "The server will be accessible at:" "Yellow"
Write-ColoredMessage "http://localhost:$PORT" "White"
Write-ColoredMessage ""

if ($dockerInstalled -and ($buildDocker -eq "y" -or $buildDocker -eq "Y") -and ($runDocker -eq "y" -or $runDocker -eq "Y")) {
    Write-ColoredMessage "Docker container is running. To stop it, run:" "Yellow"
    Write-ColoredMessage "docker stop chatgpt-adapter" "White"
    Write-ColoredMessage ""
}

# Ask if user wants to start the server now (if not using Docker)
if (-not ($dockerInstalled -and ($buildDocker -eq "y" -or $buildDocker -eq "Y") -and ($runDocker -eq "y" -or $runDocker -eq "Y"))) {
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
}
