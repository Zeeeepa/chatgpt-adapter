package main

import (
	"github.com/bincooo/gptsdk/cobra"

	_ "adapter/llm/v1"
)

func main() {
	cobra.Initialized()
}
