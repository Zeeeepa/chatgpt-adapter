package cursor

import (
	"crypto/sha256"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// Response structure for the auth poll API
type AuthResponse struct {
	AccessToken string `json:"accessToken"`
	AuthId      string `json:"authId"`
}

// Generate a PKCE pair (code verifier and code challenge)
func generatePkcePair() (string, string) {
	// Generate a random verifier
	b := make([]byte, 43)
	_, err := rand.Read(b)
	if err != nil {
		panic(err)
	}
	verifier := base64.RawURLEncoding.EncodeToString(b)

	// Generate the challenge from the verifier
	h := sha256.New()
	h.Write([]byte(verifier))
	challenge := base64.RawURLEncoding.EncodeToString(h.Sum(nil))

	return verifier, challenge
}

// Get the login URL
func getLoginUrl(uuid, challenge string) string {
	return fmt.Sprintf("https://www.cursor.com/loginDeepControl?challenge=%s&uuid=%s&mode=login", challenge, uuid)
}

// Generate a UUID v4
func generateUUID() string {
	b := make([]byte, 16)
	_, err := rand.Read(b)
	if err != nil {
		panic(err)
	}
	
	// Set version (4) and variant bits
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	
	uuid := fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
	return uuid
}

// Open a URL in the default browser
func openBrowser(url string) error {
	var cmd *exec.Cmd
	
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	default:
		return fmt.Errorf("unsupported platform")
	}
	
	return cmd.Start()
}

// Query the auth poll API
func queryAuthPoll(uuid, verifier string) (*AuthResponse, error) {
	authPollUrl := fmt.Sprintf("https://api2.cursor.sh/auth/poll?uuid=%s&verifier=%s", uuid, verifier)
	
	client := &http.Client{
		Timeout: 5 * time.Second,
	}
	
	req, err := http.NewRequest("GET", authPollUrl, nil)
	if err != nil {
		return nil, err
	}
	
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Cursor/0.48.6 Chrome/132.0.6834.210 Electron/34.3.4 Safari/537.36")
	req.Header.Set("Accept", "*/*")
	
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("auth poll failed with status: %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	
	var authResp AuthResponse
	err = json.Unmarshal(body, &authResp)
	if err != nil {
		return nil, err
	}
	
	return &authResp, nil
}

// Format the token from the auth response
func formatToken(authResp *AuthResponse) string {
	accessToken := authResp.AccessToken
	authId := authResp.AuthId
	
	if accessToken == "" {
		return ""
	}
	
	var token string
	if strings.Contains(authId, "|") {
		userId := strings.Split(authId, "|")[1]
		token = fmt.Sprintf("%s%%3A%%3A%s", userId, accessToken)
	} else {
		token = accessToken
	}
	
	return token
}

// Wait for a key press
func waitForKeyPress() {
	fmt.Println("Press Enter to continue...")
	fmt.Scanln()
}

// Login to Cursor and get the session token
func Login() (string, error) {
	verifier, challenge := generatePkcePair()
	uuid := generateUUID()
	loginUrl := getLoginUrl(uuid, challenge)
	
	fmt.Println("=== Cursor Login ===")
	fmt.Println("Please open the following URL in your browser to login:")
	fmt.Println(loginUrl)
	
	// Try to open the browser automatically
	err := openBrowser(loginUrl)
	if err != nil {
		fmt.Println("Could not open browser automatically. Please copy and paste the URL into your browser.")
	}
	
	fmt.Println("\nWaiting for login... Press Enter after you've logged in to save cookies.")
	waitForKeyPress()
	
	// Start polling for auth
	fmt.Println("Checking login status...")
	
	authResp, err := queryAuthPoll(uuid, verifier)
	if err != nil {
		return "", fmt.Errorf("login failed: %v", err)
	}
	
	if authResp.AccessToken == "" {
		return "", fmt.Errorf("login failed: no access token received")
	}
	
	token := formatToken(authResp)
	if token == "" {
		return "", fmt.Errorf("login failed: could not format token")
	}
	
	fmt.Println("Login successful!")
	fmt.Println("Your Cursor cookie (WorkosCursorSessionToken):")
	fmt.Println(token)
	
	// Update config.yaml if it exists
	updateConfig(token)
	
	return token, nil
}

// Update config.yaml with the new token
func updateConfig(token string) {
	configPaths := []string{"./config.yaml", "./config/config.yaml"}
	
	for _, path := range configPaths {
		if _, err := os.Stat(path); err == nil {
			content, err := os.ReadFile(path)
			if err != nil {
				fmt.Printf("Warning: Could not read config file %s: %v\n", path, err)
				continue
			}
			
			// Replace the token in the config file
			newContent := strings.Replace(
				string(content), 
				`cookie: "YOUR_CURSOR_TOKEN_HERE"`, 
				fmt.Sprintf(`cookie: "%s"`, token), 
				-1,
			)
			
			newContent = strings.Replace(
				newContent, 
				`cookie: "your_cursor_session_token_here"`, 
				fmt.Sprintf(`cookie: "%s"`, token), 
				-1,
			)
			
			err = os.WriteFile(path, []byte(newContent), 0644)
			if err != nil {
				fmt.Printf("Warning: Could not update config file %s: %v\n", path, err)
				continue
			}
			
			fmt.Printf("Updated token in %s\n", path)
		}
	}
}

