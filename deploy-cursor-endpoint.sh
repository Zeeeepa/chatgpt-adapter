#!/bin/bash

# ChatGPT Adapter - Cursor OpenAI API Endpoint Deployment Script for WSL2
# This script helps deploy a Cursor-compatible OpenAI API endpoint
# with error handling, fallback mechanisms, and user interaction

# Set console colors
RESET="\033[0m"
RED="\033[91m"
GREEN="\033[92m"
YELLOW="\033[93m"
BLUE="\033[94m"
MAGENTA="\033[95m"
CYAN="\033[96m"
WHITE="\033[97m"

# Configuration variables
PORT=8080
CONFIG_DIR="config"
CONFIG_FILE="config.yaml"
DOCKER_IMAGE="ghcr.io/bincooo/chatgpt-adapter:latest"
DEFAULT_MODEL="cursor/claude-3.7-sonnet-thinking"
LOG_FILE="cursor-deploy.log"
RETRY_COUNT=3
TIMEOUT_SECONDS=30

# Clear log file
echo "" > "$LOG_FILE"

# Function to log messages
log() {
    echo "$1" >> "$LOG_FILE"
}

# Function to display banner
display_banner() {
    echo -e "${CYAN}=====================================================${RESET}"
    echo -e "${CYAN}    Cursor OpenAI API Endpoint Deployment Script     ${RESET}"
    echo -e "${CYAN}=====================================================${RESET}"
    echo ""
}

# Function to display error message
error() {
    echo -e "${RED}ERROR: $1${RESET}"
    log "ERROR: $1"
}

# Function to display success message
success() {
    echo -e "${GREEN}$1${RESET}"
    log "SUCCESS: $1"
}

# Function to display info message
info() {
    echo -e "${YELLOW}$1${RESET}"
    log "INFO: $1"
}

# Function to check if a command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        COMMAND_EXISTS=1
    else
        COMMAND_EXISTS=0
    fi
}

# Function to check if a file exists
check_file() {
    if [ -f "$1" ]; then
        FILE_EXISTS=1
    else
        FILE_EXISTS=0
    fi
}

# Function to check if a directory exists
check_directory() {
    if [ -d "$1" ]; then
        DIRECTORY_EXISTS=1
    else
        DIRECTORY_EXISTS=0
    fi
}

# Function to create directory if it doesn't exist
create_directory() {
    check_directory "$1"
    if [ $DIRECTORY_EXISTS -eq 0 ]; then
        mkdir -p "$1" 2>/dev/null
        if [ $? -ne 0 ]; then
            error "Failed to create directory: $1"
            exit 1
        fi
        success "Created directory: $1"
    fi
}

# Function to check if Docker is running
check_docker_running() {
    if docker info &>/dev/null; then
        DOCKER_RUNNING=1
    else
        DOCKER_RUNNING=0
    fi
}

# Function to check if a port is in use
check_port_in_use() {
    if netstat -tuln | grep -q ":$1 "; then
        PORT_IN_USE=1
    else
        PORT_IN_USE=0
    fi
}

# Function to find an available port
find_available_port() {
    START_PORT=$1
    CURRENT_PORT=$START_PORT
    
    while [ $CURRENT_PORT -lt 65536 ]; do
        check_port_in_use $CURRENT_PORT
        if [ $PORT_IN_USE -eq 0 ]; then
            AVAILABLE_PORT=$CURRENT_PORT
            return
        fi
        
        CURRENT_PORT=$((CURRENT_PORT + 1))
    done
    
    AVAILABLE_PORT=$START_PORT
    error "Could not find an available port. Using default: $START_PORT"
}

# Function to create config file
create_config_file() {
    CONFIG_PATH="$1/$2"
    
    cat > "$CONFIG_PATH" << EOF
server:
  port: $PORT

cursor:
  enabled: true
  model:
    - $DEFAULT_MODEL
  cookie: "YOUR_CURSOR_TOKEN_HERE"
  checksum: ""
EOF
    
    success "Created config file: $CONFIG_PATH"
}

# Function to check if a process is running on a specific port
check_process_on_port() {
    PID=$(lsof -i :$1 -t 2>/dev/null)
}

# Function to kill a process by PID
kill_process() {
    if [ -n "$1" ]; then
        kill -9 $1 2>/dev/null
        if [ $? -ne 0 ]; then
            error "Failed to kill process with PID: $1"
        else
            success "Killed process with PID: $1"
        fi
    fi
}

# Function to wait for a service to be available
wait_for_service() {
    URL=$1
    MAX_ATTEMPTS=$2
    ATTEMPTS=0
    
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
        
        if [ "$STATUS" = "200" ]; then
            success "Service is available at $URL"
            return
        fi
        
        ATTEMPTS=$((ATTEMPTS + 1))
        info "Waiting for service to be available... Attempt $ATTEMPTS/$MAX_ATTEMPTS"
        sleep 2
    done
    
    error "Service did not become available after $MAX_ATTEMPTS attempts"
}

# Function to test the API endpoint
test_api_endpoint() {
    URL=$1
    TOKEN=$2
    MODEL=$3
    
    info "Testing API endpoint at $URL with model $MODEL..."
    
    cat > test_request.json << EOF
{"model":"$MODEL","messages":[{"role":"user","content":"Hello, please respond with a single word: Working"}],"stream":false}
EOF
    
    curl -s -X POST "$URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TOKEN" \
        -d @test_request.json > test_response.json
    
    if grep -q "Working" test_response.json; then
        success "API endpoint test successful!"
        API_TEST_SUCCESS=1
    else
        error "API endpoint test failed. See test_response.json for details."
        API_TEST_SUCCESS=0
    fi
}

# Start of main script
display_banner

# Check for required commands
info "Checking for required tools..."

check_command "curl"
if [ $COMMAND_EXISTS -eq 0 ]; then
    error "curl is not installed. Please install curl and try again."
    info "You can install curl with: sudo apt-get install curl"
    exit 1
fi

# Check if Docker is installed
check_command "docker"
if [ $COMMAND_EXISTS -eq 0 ]; then
    info "Docker is not installed. Will use local deployment method."
    USE_DOCKER=0
else
    check_docker_running
    if [ $DOCKER_RUNNING -eq 0 ]; then
        info "Docker is installed but not running. Will use local deployment method."
        USE_DOCKER=0
    else
        info "Docker is installed and running. Will use Docker deployment method."
        USE_DOCKER=1
    fi
fi

# Check if port is in use
check_port_in_use $PORT
if [ $PORT_IN_USE -eq 1 ]; then
    info "Port $PORT is already in use."
    
    # Check if it's our service
    curl -s "http://localhost:$PORT/v1/models" > port_check.txt 2>&1
    if grep -q "cursor" port_check.txt; then
        info "It appears that the ChatGPT Adapter is already running on port $PORT."
        read -p "Do you want to stop it and restart? (y/n): " choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            check_process_on_port $PORT
            if [ -n "$PID" ]; then
                kill_process $PID
            fi
        else
            find_available_port $PORT
            PORT=$AVAILABLE_PORT
            info "Using alternative port: $PORT"
        fi
    else
        find_available_port $PORT
        PORT=$AVAILABLE_PORT
        info "Using alternative port: $PORT"
    fi
    rm -f port_check.txt
fi

# Create config directory and file
create_directory "$CONFIG_DIR"
check_file "$CONFIG_DIR/$CONFIG_FILE"
if [ $FILE_EXISTS -eq 0 ]; then
    create_config_file "$CONFIG_DIR" "$CONFIG_FILE"
fi

# Get Cursor token
info "You need a Cursor session token to use this service."
echo -e "${CYAN}There are two ways to get your token:${RESET}"
echo -e "${CYAN}1. Automatic login (recommended)${RESET}"
echo -e "${CYAN}2. Manual extraction from browser${RESET}"
echo ""

read -p "Choose an option (1/2): " option
if [ "$option" = "1" ]; then
    # Automatic login
    info "Automatic login selected."
    
    # Check if cursor-login exists
    check_file "bin/linux/cursor-login"
    if [ $FILE_EXISTS -eq 1 ]; then
        info "Running cursor login tool..."
        chmod +x bin/linux/cursor-login
        bin/linux/cursor-login
        if [ $? -ne 0 ]; then
            error "Cursor login failed. Please try manual extraction."
            option=2
        fi
    else
        info "Cursor login tool not found. Checking if we can build it..."
        
        check_command "go"
        if [ $COMMAND_EXISTS -eq 0 ]; then
            error "Go is not installed. Cannot build cursor login tool."
            info "You can install Go with: sudo apt-get install golang-go"
            option=2
        else
            info "Building cursor login tool..."
            mkdir -p bin/linux 2>/dev/null
            go build -o bin/linux/cursor-login cmd/cursor-login/main.go
            
            if [ $? -ne 0 ]; then
                error "Failed to build cursor login tool. Please try manual extraction."
                option=2
            else
                info "Running cursor login tool..."
                chmod +x bin/linux/cursor-login
                bin/linux/cursor-login
                if [ $? -ne 0 ]; then
                    error "Cursor login failed. Please try manual extraction."
                    option=2
                fi
            fi
        fi
    fi
    
    if [ "$option" = "1" ]; then
        # Read token from config file
        CURSOR_TOKEN=$(grep "cookie:" "$CONFIG_DIR/$CONFIG_FILE" | cut -d'"' -f2)
        
        if [ "$CURSOR_TOKEN" = "YOUR_CURSOR_TOKEN_HERE" ]; then
            error "Token was not properly saved to config file."
            option=2
        else
            success "Token retrieved successfully!"
        fi
    fi
fi

if [ "$option" = "2" ]; then
    # Manual extraction
    info "Manual extraction selected."
    echo -e "${CYAN}Please follow these steps to get your Cursor token:${RESET}"
    echo -e "${CYAN}1. Open Chrome and go to https://cursor.com (make sure you're logged in)${RESET}"
    echo -e "${CYAN}2. Press F12 to open Developer Tools${RESET}"
    echo -e "${CYAN}3. Go to the \"Application\" tab${RESET}"
    echo -e "${CYAN}4. In the left sidebar, click on \"Cookies\" under \"Storage\"${RESET}"
    echo -e "${CYAN}5. Find the WorkosCursorSessionToken cookie and copy its value${RESET}"
    echo ""
    
    read -p "Enter your Cursor token: " CURSOR_TOKEN
    
    # Update config file with token
    sed -i "s/cookie: \".*\"/cookie: \"$CURSOR_TOKEN\"/" "$CONFIG_DIR/$CONFIG_FILE"
    
    success "Token saved to config file!"
fi

# Deploy the service
if [ $USE_DOCKER -eq 1 ]; then
    # Docker deployment
    info "Deploying with Docker..."
    
    # Check if container is already running
    if docker ps | grep -q "chatgpt-adapter"; then
        info "ChatGPT Adapter container is already running."
        read -p "Do you want to stop it and restart? (y/n): " choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            info "Stopping existing container..."
            docker stop chatgpt-adapter >/dev/null 2>&1
            docker rm chatgpt-adapter >/dev/null 2>&1
        else
            info "Keeping existing container running."
            goto_deployment_complete=1
        fi
    fi
    
    if [ -z "$goto_deployment_complete" ]; then
        # Pull the latest image
        info "Pulling the latest Docker image..."
        docker pull $DOCKER_IMAGE
        
        # Run the container
        info "Starting Docker container..."
        docker run -d --name chatgpt-adapter -p $PORT:8080 -v "$(pwd)/$CONFIG_DIR/$CONFIG_FILE:/app/config.yaml" $DOCKER_IMAGE
        
        if [ $? -ne 0 ]; then
            error "Failed to start Docker container."
            info "Falling back to local deployment..."
            USE_DOCKER=0
        else
            success "Docker container started successfully!"
        fi
    fi
fi

if [ $USE_DOCKER -eq 0 ]; then
    # Local deployment
    info "Deploying locally..."
    
    # Check if server exists
    check_file "bin/linux/server"
    if [ $FILE_EXISTS -eq 0 ]; then
        info "Server executable not found. Checking if we can build it..."
        
        check_command "go"
        if [ $COMMAND_EXISTS -eq 0 ]; then
            error "Go is not installed. Cannot build server."
            info "You can install Go with: sudo apt-get install golang-go"
            exit 1
        fi
        
        info "Building server..."
        mkdir -p bin/linux 2>/dev/null
        
        # Check if iocgo is installed
        check_command "iocgo"
        if [ $COMMAND_EXISTS -eq 0 ]; then
            info "Installing iocgo tool..."
            go install -ldflags="-s -w" -trimpath ./cmd/iocgo
            if [ $? -ne 0 ]; then
                error "Failed to install iocgo tool."
                exit 1
            fi
        fi
        
        # Build the server
        export CGO_ENABLED=0
        export GOARCH=amd64
        export GOOS=linux
        go build -toolexec iocgo -ldflags="-s -w" -o bin/linux/server -trimpath main.go
        
        if [ $? -ne 0 ]; then
            error "Failed to build server."
            exit 1
        fi
        
        success "Server built successfully!"
    fi
    
    # Start the server
    info "Starting server on port $PORT..."
    chmod +x bin/linux/server
    nohup bin/linux/server --port $PORT > server.log 2>&1 &
    SERVER_PID=$!
    
    if [ $? -ne 0 ]; then
        error "Failed to start server."
        exit 1
    fi
    
    success "Server started successfully with PID: $SERVER_PID!"
fi

# Wait for service to be available
wait_for_service "http://localhost:$PORT/v1/models" $RETRY_COUNT

# Test the API endpoint
test_api_endpoint "http://localhost:$PORT" "$CURSOR_TOKEN" "$DEFAULT_MODEL"

if [ $API_TEST_SUCCESS -eq 1 ]; then
    # Display success message
    echo ""
    echo -e "${GREEN}=====================================================${RESET}"
    echo -e "${GREEN}       Deployment Completed Successfully!            ${RESET}"
    echo -e "${GREEN}=====================================================${RESET}"
    echo ""
    echo -e "${CYAN}The Cursor OpenAI API endpoint is now running at:${RESET}"
    echo -e "${CYAN}http://localhost:$PORT${RESET}"
    echo ""
    echo -e "${CYAN}Available models:${RESET}"
    echo -e "${CYAN}- cursor/claude-3.7-sonnet${RESET}"
    echo -e "${CYAN}- cursor/claude-3.7-sonnet-thinking${RESET}"
    echo -e "${CYAN}- cursor/claude-3-opus${RESET}"
    echo -e "${CYAN}- cursor/claude-3.5-haiku${RESET}"
    echo -e "${CYAN}- cursor/claude-3.5-sonnet${RESET}"
    echo -e "${CYAN}- cursor/gpt-4o${RESET}"
    echo -e "${CYAN}- cursor/gpt-4o-mini${RESET}"
    echo -e "${CYAN}- cursor/gpt-4-turbo-2024-04-09${RESET}"
    echo -e "${CYAN}- cursor/gpt-4${RESET}"
    echo -e "${CYAN}- cursor/gpt-3.5-turbo${RESET}"
    echo -e "${CYAN}- cursor/o1-mini${RESET}"
    echo -e "${CYAN}- cursor/o1-preview${RESET}"
    echo ""
    echo -e "${CYAN}Example curl request:${RESET}"
    echo -e "${CYAN}curl http://localhost:$PORT/v1/chat/completions \\${RESET}"
    echo -e "${CYAN}  -H \"Content-Type: application/json\" \\${RESET}"
    echo -e "${CYAN}  -H \"Authorization: $CURSOR_TOKEN\" \\${RESET}"
    echo -e "${CYAN}  -d '{${RESET}"
    echo -e "${CYAN}    \"model\": \"$DEFAULT_MODEL\",${RESET}"
    echo -e "${CYAN}    \"messages\": [${RESET}"
    echo -e "${CYAN}      {${RESET}"
    echo -e "${CYAN}        \"role\": \"user\",${RESET}"
    echo -e "${CYAN}        \"content\": \"Hello, can you help me with some code?\"${RESET}"
    echo -e "${CYAN}      }${RESET}"
    echo -e "${CYAN}    ],${RESET}"
    echo -e "${CYAN}    \"stream\": true${RESET}"
    echo -e "${CYAN}  }'${RESET}"
    echo ""
    echo -e "${CYAN}To use this endpoint with applications that support OpenAI API:${RESET}"
    echo -e "${CYAN}1. Set the API base URL to: http://localhost:$PORT${RESET}"
    echo -e "${CYAN}2. Set the API key to your Cursor token${RESET}"
    echo -e "${CYAN}3. Select one of the cursor models listed above${RESET}"
    echo ""
    
    if [ $USE_DOCKER -eq 1 ]; then
        echo -e "${CYAN}To stop the Docker container:${RESET}"
        echo -e "${CYAN}docker stop chatgpt-adapter${RESET}"
        echo ""
        echo -e "${CYAN}To restart the Docker container:${RESET}"
        echo -e "${CYAN}docker start chatgpt-adapter${RESET}"
    else
        echo -e "${CYAN}To stop the server:${RESET}"
        echo -e "${CYAN}kill -9 $SERVER_PID${RESET}"
    fi
    echo ""
    echo -e "${CYAN}Logs are available in: $LOG_FILE${RESET}"
else
    # Display error message
    echo ""
    echo -e "${RED}=====================================================${RESET}"
    echo -e "${RED}       Deployment Completed With Errors!            ${RESET}"
    echo -e "${RED}=====================================================${RESET}"
    echo ""
    echo -e "${YELLOW}The service is running but the API test failed.${RESET}"
    echo -e "${YELLOW}Please check the following:${RESET}"
    echo -e "${YELLOW}1. Your Cursor token may be invalid or expired${RESET}"
    echo -e "${YELLOW}2. The service may not be fully initialized yet${RESET}"
    echo -e "${YELLOW}3. There might be network connectivity issues${RESET}"
    echo ""
    echo -e "${YELLOW}You can try again by:${RESET}"
    echo -e "${YELLOW}1. Stopping the current service${RESET}"
    echo -e "${YELLOW}2. Getting a fresh Cursor token${RESET}"
    echo -e "${YELLOW}3. Running this script again${RESET}"
    echo ""
    echo -e "${YELLOW}Logs are available in: $LOG_FILE${RESET}"
fi

echo ""
echo -e "${CYAN}Press Enter to exit...${RESET}"
read

