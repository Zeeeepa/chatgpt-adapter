# Cursor OpenAI API Endpoint Deployment

This guide explains how to use the `deploy-cursor-endpoint.bat` script to set up a Cursor-compatible OpenAI API endpoint with error handling, fallback mechanisms, and user interaction.

## What is this script?

The `deploy-cursor-endpoint.bat` script is an interactive Windows batch script that helps you:

1. Set up and deploy a Cursor-compatible OpenAI API endpoint
2. Handle errors and provide fallback mechanisms
3. Guide you through the process of obtaining a Cursor API token
4. Test the endpoint to ensure it's working correctly
5. Provide clear instructions for using the endpoint

## Features

- **Interactive Setup**: Guides you through each step with clear instructions
- **Error Handling**: Detects and resolves common issues automatically
- **Fallback Mechanisms**: If one deployment method fails, tries alternative approaches
- **Port Management**: Automatically finds available ports if the default is in use
- **Token Retrieval**: Offers both automatic and manual methods to get your Cursor token
- **Deployment Options**: Supports both Docker and local deployment methods
- **API Testing**: Verifies the endpoint is working correctly before completion
- **Detailed Logging**: Keeps a log of all operations for troubleshooting

## Prerequisites

- Windows operating system
- Internet connection
- A Cursor account (free or paid)
- Optional: Docker Desktop for Windows (recommended)
- Optional: Go programming language (for building from source)

## Usage

1. Download the `deploy-cursor-endpoint.bat` script
2. Open a Command Prompt or PowerShell window
3. Navigate to the directory containing the script
4. Run the script:
   ```
   deploy-cursor-endpoint.bat
   ```
5. Follow the on-screen instructions

## Deployment Methods

The script supports two deployment methods:

### 1. Docker Deployment (Recommended)

If Docker is installed and running, the script will:
- Pull the latest ChatGPT Adapter Docker image
- Configure it with your Cursor token
- Run it as a container
- Map the container's port to your local machine

### 2. Local Deployment

If Docker is not available or fails, the script will:
- Check if the server executable exists
- Build it from source if necessary (requires Go)
- Configure it with your Cursor token
- Run it as a local process

## Getting Your Cursor Token

The script offers two methods to get your Cursor token:

### 1. Automatic Login (Recommended)

The script will:
- Run the cursor login tool
- Open your default browser to the Cursor login page
- Wait for you to log in
- Automatically retrieve and save your token

### 2. Manual Extraction

If automatic login fails, the script will guide you through:
- Opening Chrome and navigating to Cursor
- Using Developer Tools to find your token
- Entering the token manually

## Using the API Endpoint

Once deployed, you can use the endpoint with any application that supports the OpenAI API:

1. Set the API base URL to: `http://localhost:8080` (or the port shown in the script output)
2. Set the API key to your Cursor token
3. Use one of the available Cursor models:
   - `cursor/claude-3.7-sonnet`
   - `cursor/claude-3.7-sonnet-thinking`
   - `cursor/claude-3-opus`
   - `cursor/claude-3.5-haiku`
   - `cursor/claude-3.5-sonnet`
   - `cursor/gpt-4o`
   - `cursor/gpt-4o-mini`
   - `cursor/gpt-4-turbo-2024-04-09`
   - `cursor/gpt-4`
   - `cursor/gpt-3.5-turbo`
   - `cursor/o1-mini`
   - `cursor/o1-preview`

## Example API Request

```bash
curl http://localhost:8080/v1/chat/completions ^
  -H "Content-Type: application/json" ^
  -H "Authorization: YOUR_CURSOR_TOKEN" ^
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
```

## Troubleshooting

If you encounter issues:

1. Check the `cursor-deploy.log` file for detailed logs
2. Ensure your Cursor token is valid and not expired
3. Make sure the required port is not blocked by a firewall
4. If using Docker, ensure Docker Desktop is running
5. Try stopping any existing instances before restarting

## Stopping the Service

- **Docker Deployment**: Run `docker stop chatgpt-adapter`
- **Local Deployment**: Press Ctrl+C in the server window or use Task Manager

## Restarting the Service

Simply run the script again. It will detect existing instances and guide you through the restart process.

## Security Notes

- Your Cursor token provides access to your Cursor account
- The script stores your token in the local config file
- The token is used only for authentication with the Cursor API
- Never share your token with others

## License

This script is provided under the same license as the ChatGPT Adapter project.

