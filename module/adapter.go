package module

import (
	"adapter/module/fiber/context"
	"adapter/module/fiber/model"
)

type RelayType byte

const (
	RELAY_TYPE_COMPLETIONS RelayType = iota
	RELAY_TYPE_EMBEDDINGS
	RELAY_TYPE_GENERATIONS
)

type Adapter interface {
	// 判定函数
	Support(rt RelayType, ctx *context.Ctx, model string) bool
	// 上下文对话
	Relay(ctx *context.Ctx) error
	// 向量查询
	Embed(ctx *context.Ctx) error
	// 文生图
	Image(ctx *context.Ctx) error
	// 模型列表
	Model() []model.Model
}

type BasicAdapter struct {
}

func (BasicAdapter) Relay(*context.Ctx) error {
	return nil
}

func (BasicAdapter) Embed(*context.Ctx) error {
	return nil
}

func (BasicAdapter) Image(*context.Ctx) error {
	return nil
}
