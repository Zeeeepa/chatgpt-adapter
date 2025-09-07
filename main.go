package main

import (
	"github.com/bincooo/ago"

	_ "adapter/llm/lmarena"
	_ "adapter/llm/v1"
)

func main() {
	ago.Execute()
}
