package v1

import (
	"adapter/module"
	"adapter/module/common"
	"adapter/module/env"
	"adapter/module/fiber/context"
	"adapter/module/fiber/model"
	"io"
	"strings"
	"time"
)

var (
	_ module.Adapter = (*ada)(nil)

	schema = make([]model.Record[string, any], 0)
)

func init() {
	common.AddInitialized(func(env *env.Environ) {
		llm := env.Get("custom-llm")
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
			}
		}
	})
}

type ada struct {
	module.BasicAdapter
}

func New() module.Adapter { return &ada{} }

func (api *ada) Model() []model.Model {
	return []model.Model{
		{
			Id:      "custom/llm ???",
			Object:  "model",
			Created: 1686935002,
			By:      "custom-adapter",
		},
	}
}

// 模型匹配，当命中时执行模型函数
func (api *ada) Support(rt module.RelayType, ctx *context.Ctx, mod string) (ret bool) {
	for _, rec := range schema {
		if prefix, ok := model.GetValue[string, string](rec, "prefix"); ok && strings.HasPrefix(mod, prefix+"/") {
			ctx.Put("custom-llm", rec)
			ctx.Put("original-model", mod[len(prefix)+1:])
			ret = true
			return
		}
	}
	return
}

func (api *ada) Relay(ctx *context.Ctx) (err error) {
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

				err = writer(context.NewSSEResponse(bodies.Chunk, unix))
			}
		})
		return
	}

	chunkBodies := waitChannel(response)
	return ctx.JSON(context.NewResponse(chunkBodies.Chunk, unix))
}
