# ChatGPT Adapter Docker Deployment Script
# This script creates a Docker-based deployment for chatgpt-adapter with Cursor support

# Create config directory if it doesn't exist
$configDir = "$PSScriptRoot\config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
    Write-Host "Created config directory at $configDir"
}

# Create or update config.yaml
$configPath = "$configDir\config.yaml"
$configContent = @"
server:
  port: 8080

cursor:
  enabled: true
  model:
    - cursor/claude-3.7-sonnet-thinking
  cookie: "YOUR_CURSOR_TOKEN_HERE"
  checksum: ""  # Will be auto-generated if empty
"@

Set-Content -Path $configPath -Value $configContent

Write-Host "====================================================
       ChatGPT Adapter Docker Deployment
===================================================="

Write-Host "Config file created at: $configPath"
Write-Host "Please edit this file to add your Cursor token before running the container."
Write-Host "You can get your token from Chrome Developer Tools > Application > Cookies > WorkosCursorSessionToken"

# Check if Docker is installed
try {
    $dockerVersion = docker --version
    Write-Host "Docker detected: $dockerVersion"
} catch {
    Write-Host "Docker not found. Please install Docker Desktop for Windows before continuing."
    Write-Host "Download from: https://www.docker.com/products/docker-desktop/"
    exit 1
}

# Prompt user to edit the config file
Write-Host "`nWould you like to edit the config file now? (y/n)"
$editConfig = Read-Host
if ($editConfig -eq "y" -or $editConfig -eq "Y") {
    # Try to open with notepad
    Start-Process notepad $configPath
    Write-Host "Please update the token in the config file and save it."
    Write-Host "Press any key to continue after saving..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Prompt user to run the container
Write-Host "`nWould you like to run the container now? (y/n)"
$runContainer = Read-Host
if ($runContainer -eq "y" -or $runContainer -eq "Y") {
    Write-Host "Running Docker container..."
    docker run -p 8080:8080 -v ${configPath}:/app/config.yaml ghcr.io/bincooo/chatgpt-adapter:latest
} else {
    Write-Host "`nTo run the container later, use this command:"
    Write-Host "docker run -p 8080:8080 -v `"$configPath`":/app/config.yaml ghcr.io/bincooo/chatgpt-adapter:latest"
}

Write-Host "`n====================================================
       Testing Your Setup
===================================================="
Write-Host "Once the container is running, you can test it with this curl command:"
Write-Host @"
curl http://localhost:8080/v1/chat/completions ``
  -H "Content-Type: application/json" ``
  -H "Authorization: YOUR_CURSOR_TOKEN_HERE" ``
  -d '{
    "model": "cursor/claude-3.7-sonnet-thinking",
    "messages": [
      {
        "role": "user",
        "content": "Hello, can you help me with some code?"
      }
    ],
    "stream": true
  }'
"@

Write-Host "`nAvailable Cursor models:"
Write-Host "- cursor/claude-3.7-sonnet"
Write-Host "- cursor/claude-3.7-sonnet-thinking"
Write-Host "- cursor/claude-3-opus"
Write-Host "- cursor/claude-3.5-haiku"
Write-Host "- cursor/claude-3.5-sonnet"
Write-Host "- cursor/gpt-4o"
Write-Host "- cursor/gpt-4o-mini"
Write-Host "- cursor/gpt-4-turbo-2024-04-09"
Write-Host "- cursor/gpt-4"
Write-Host "- cursor/gpt-3.5-turbo"
Write-Host "- cursor/o1-mini"
Write-Host "- cursor/o1-preview"

