package lmarena

import (
	"io"
	"time"

	"github.com/bincooo/ago"
	"github.com/bincooo/ago/model"
)

var (
	Sdk = ago.Sdk()

	modelMap = map[string]string{
		"gpt-4.1-2025-04-14":                      "14e9311c-94d2-40c2-8c54-273947e208b0",
		"gemini-2.5-pro":                          "e2d9d353-6dbe-4414-bf87-bd289d523726",
		"claude-opus-4-20250514":                  "ee116d12-64d6-48a8-88e5-b2d06325cdd2",
		"claude-3-7-sonnet-20250219-thinking-32k": "be98fcfd-345c-4ae1-9a82-a19123ebf1d2",
	}
)

func init() {
	Sdk.OnInitialized(func() {
		Sdk.Plugin(
			"lmarena/gpt-4.1-2025-04-14",
			"lmarena/gemini-2.5-pro",
			"lmarena/claude-opus-4-20250514",
			"lmarena/claude-3-7-sonnet-20250219-thinking-32k",
		).Relay(func(ctx *model.Ctx) (err error) {
			completion := model.JustValue[string, *model.Completion](ctx.Record, "completion")
			unix := time.Now().Unix()

			response, err := fetch(ctx)
			if err != nil {
				return err
			}

			if completion.Stream {
				ctx.SSE(func(writer func(interface{}) error) {
					chunkBodies := createChannel(response)
					for {
						bodies, ok := <-chunkBodies
						if !ok {
							err = writer(io.EOF)
							return
						}

						err = writer(model.MakeSSEResponse(bodies.Chunk, unix))
					}
				})
				return
			}

			chunkBodies := waitChannel(response)
			return ctx.JSON(model.MakeResponse(chunkBodies.Chunk, unix))
		}).Append()
	})
}
