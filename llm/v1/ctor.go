package v1

import (
	"io"
	"time"

	"github.com/bincooo/ago"
	"github.com/bincooo/ago/model"
)

var (
	schema = make([]model.Record[string, any], 0)
	Sdk    = ago.Sdk()
)

func init() {
	Sdk.OnInitialized(func() {
		environ := Sdk.Env()
		llm := environ.Get("custom-llm")
		var regex []string
		if slice, ok := llm.([]interface{}); ok {
			for _, it := range slice {
				var rec model.Record[string, any]
				rec, ok = it.(map[string]interface{})
				if !ok {
					continue
				}

				// validate
				_, ok = model.GetValue[string, string](rec, "reversal")
				if !ok {
					panic("`reversal` not found in config.yaml ==> custom-llm")
				}
				schema = append(schema, rec)
				regex = append(regex, model.JustValue[string, string](rec, "prefix")+"/*")
			}
		}

		Sdk.Plugin(regex...).
			Relay(func(ctx *model.Ctx) (err error) {
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
