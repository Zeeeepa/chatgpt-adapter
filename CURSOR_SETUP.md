# Setting Up ChatGPT Adapter with Cursor

This guide explains how to set up and use the ChatGPT Adapter with Cursor AI models.

## What is Cursor?

[Cursor](https://www.cursor.com/) is an AI-powered code editor that provides access to various AI models including Claude and GPT models. The ChatGPT Adapter allows you to use these models through a standard OpenAI API interface.

## Docker Setup (Recommended)

The easiest way to get started is using Docker:

1. Run the `deploy-docker.ps1` script:
   ```powershell
   .\deploy-docker.ps1
   ```

2. The script will:
   - Create a config directory and config.yaml file
   - Prompt you to edit the config file to add your Cursor token
   - Run the Docker container if you choose to

## Getting Your Cursor Token

To get your Cursor session token:

1. Open Chrome and go to https://cursor.com (make sure you're logged in)
2. Press F12 to open Developer Tools
3. Go to the "Application" tab
4. In the left sidebar, click on "Cookies" under "Storage"
5. Find the `WorkosCursorSessionToken` cookie and copy its value
6. Replace "YOUR_CURSOR_TOKEN_HERE" in the config.yaml file with this value

## Manual Docker Setup

If you prefer to set up manually:

1. Create a config.yaml file:
   ```yaml
   server:
     port: 8080

   cursor:
     enabled: true
     model:
       - cursor/claude-3.7-sonnet-thinking
     cookie: "YOUR_CURSOR_TOKEN_HERE"
     checksum: ""  # Will be auto-generated if empty
   ```

2. Run the Docker container:
   ```powershell
   docker run -p 8080:8080 -v ${PWD}/config.yaml:/app/config.yaml ghcr.io/bincooo/chatgpt-adapter:latest
   ```

## Testing Your Setup

Once the container is running, you can test it with:

```powershell
curl http://localhost:8080/v1/chat/completions `
  -H "Content-Type: application/json" `
  -H "Authorization: YOUR_CURSOR_TOKEN_HERE" `
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

## Available Cursor Models

The following models are available through the Cursor adapter:

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

## Troubleshooting

- **Authentication Error**: Make sure your Cursor token is valid and correctly formatted in both the config.yaml file and your API requests.
- **Connection Issues**: Ensure port 8080 is not being used by another application.
- **Docker Issues**: Make sure Docker is running and you have sufficient permissions.

## Advanced Configuration

For advanced configuration options, refer to the [official documentation](https://bincooo.github.io/chatgpt-adapter/#/cursor).

