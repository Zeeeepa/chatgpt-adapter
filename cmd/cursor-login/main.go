package main

import (
	"fmt"
	"os"
	"chatgpt-adapter/tools/cursor"
)

func main() {
	fmt.Println("=== Cursor Login Tool for ChatGPT Adapter ===")
	
	token, err := cursor.Login()
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Println("\nLogin successful! You can now use the ChatGPT Adapter with Cursor.")
	fmt.Println("Your token has been saved to config.yaml (if it exists).")
	fmt.Println("\nTo use this token in API requests, include it in the Authorization header:")
	fmt.Printf("Authorization: %s\n", token)
}

