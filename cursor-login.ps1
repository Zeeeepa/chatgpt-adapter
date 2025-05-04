# Cursor Login Script for ChatGPT Adapter
# This script helps users get their Cursor session token for use with ChatGPT Adapter

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
Write-ColoredMessage "       Cursor Login for ChatGPT Adapter             " "Cyan"
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage ""

# Check if cursor-login.exe exists
if (-not (Test-Path ".\bin\windows\cursor-login.exe")) {
    Write-ColoredMessage "Error: cursor-login.exe not found." "Red"
    Write-ColoredMessage "Please run deploy.ps1 first to build the cursor login tool." "Yellow"
    exit 1
}

# Run the cursor login tool
Write-ColoredMessage "Running Cursor login tool..." "Yellow"
try {
    Start-Process -FilePath ".\bin\windows\cursor-login.exe" -NoNewWindow -Wait
    Write-ColoredMessage "Cursor login completed!" "Green"
} catch {
    Write-ColoredMessage "Error running Cursor login tool: $_" "Red"
    exit 1
}

Write-ColoredMessage ""
Write-ColoredMessage "You can now use the ChatGPT Adapter with Cursor." "Green"
Write-ColoredMessage "To start the server, run:" "Yellow"
Write-ColoredMessage ".\bin\windows\server.exe --port 8080" "White"
Write-ColoredMessage ""

