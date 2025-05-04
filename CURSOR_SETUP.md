# Setting Up ChatGPT Adapter with Cursor Support

This guide explains how to set up and use the ChatGPT Adapter with Cursor implementation.

## Prerequisites

- Windows operating system
- Go installed (version 1.21 or higher recommended)
- Git installed
- Docker installed (optional, for Docker deployment)
- A valid Cursor account with session token

## Getting Your Cursor Session Token

To use the Cursor implementation, you need to obtain your Cursor session token:

1. Log in to [Cursor](https://www.cursor.com) in your web browser
2. Open your browser's developer tools (F12 or right-click and select "Inspect")
3. Go to the "Application" tab (Chrome) or "Storage" tab (Firefox)
4. In the left sidebar, expand "Cookies" and select the Cursor website
5. Look for the cookie named `WorkosCursorSessionToken`
6. Copy the value of this cookie - this is your session token

## Deployment Options

### Option 1: Using the PowerShell Script (Recommended)

1. Open PowerShell in the project directory
2. Run the deployment script:
   ```powershell
   .\deploy.ps1
   ```
3. The script will:
   - Check for required dependencies
   - Install the iocgo tool
   - Build the application for Windows
   - Create a default configuration file (config.yaml) if it doesn't exist
   - Offer to build and run a Docker container (if Docker is installed)

4. After running the script, edit the `config.yaml` file to add your Cursor session token:
   ```yaml
   cursor:
     enabled: true
     model:
       - cursor-fast
       - cursor-small
     cookie: "your_cursor_session_token_here"
     checksum: ""
   ```

5. Start the server using one of the methods provided by the script

### Option 2: Manual Docker Setup

If you prefer to manually set up Docker:

1. Create a `config.yaml` file with your Cursor configuration (see example in `config.yaml.sample`)
2. Build the Docker image:
   ```bash
   docker build -t chatgpt-adapter:latest -f deploy/Dockerfile .
   ```
3. Run the Docker container:
   ```bash
   docker run -p 8080:8080 -v ./config.yaml:/app/config.yaml chatgpt-adapter:latest
   ```

## Using the Adapter

Once the server is running, you can use it as an OpenAI API-compatible endpoint:

- API Endpoint: `http://localhost:8080/v1/chat/completions`
- Model names: `cursor-fast` or `cursor-small`

Example curl request:
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "cursor-fast",
    "messages": [
      {
        "role": "user",
        "content": "Hello, can you help me with some code?"
      }
    ],
    "stream": true
  }'
```

## Troubleshooting

- **Authentication Issues**: If you receive authentication errors, make sure your Cursor session token is valid and correctly entered in the config.yaml file.
- **Build Errors**: If you encounter build errors, try running `go clean -cache` and then rebuild.
- **Docker Issues**: If Docker fails to build or run, check that your Docker installation is working correctly and that you have sufficient permissions.

## Additional Resources

- [Cursor Website](https://www.cursor.com)
- [ChatGPT Adapter Documentation](https://bincooo.github.io/chatgpt-adapter)

