package context

import (
	"adapter/module/fiber/model"
	"adapter/module/logger"
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/gofiber/fiber/v2"
)

type Ctx struct {
	ctx *fiber.Ctx
	model.Record[string, any]

	Token string
}

func New(ctx *fiber.Ctx) *Ctx {
	return &Ctx{
		ctx:    ctx,
		Record: make(model.Record[string, any]),

		Token: token(ctx),
	}
}

func (ctx *Ctx) Ctx() *fiber.Ctx {
	return ctx.ctx
}

func (ctx *Ctx) SSE(yield func(writer func(interface{}) error)) {
	ctx.ctx.Set("content-type", "text/event-stream")
	ctx.ctx.Set("cache-control", "no-cache")
	ctx.ctx.Set("x-accel-buffering", "no")
	ctx.ctx.Set("x-accept-encoding", "gzip, deflate, br")
	ctx.ctx.Set("connection", "keep-alive")
	ctx.ctx.Set("transfer-encoding", "chunked")

	ctx.ctx.Status(fiber.StatusOK).Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		yield(func(msg interface{}) error {
			return write(w, msg)
		})
	})
	return
}

func (ctx *Ctx) JSON(msg interface{}) error {
	return ctx.ctx.JSON(msg)
}

func token(ctx *fiber.Ctx) (token string) {
	token = ctx.Get("X-Api-Key")
	if token == "" {
		token = strings.TrimPrefix(ctx.Get("Authorization"), "Bearer ")
	}
	return
}

func write(w *bufio.Writer, msg interface{}) error {
	event := "data"
	var data string

	switch v := msg.(type) {
	case interface{ String() string }:
		data = v.String()
	case []byte:
		data = string(v)
	case string:
		data = v
	case error:
		if v == io.EOF {
			data = "[done]"
		} else {
			event = "error"
			data = v.Error()
		}
	default:
		chunk, err := json.Marshal(v)
		if err != nil {
			event = "error"
			data = err.Error()
		} else {
			data = string(chunk)
		}
	}

	_, err := fmt.Fprintf(w, "%s: %s\n\n", event, data)
	if err != nil {
		logger.Sugar().Errorf("write sse data error: %v", err)
		return err
	}
	return flush(w)
}

func flush(w *bufio.Writer) error {
	if err := w.Flush(); err != nil {
		logger.Sugar().Errorf("write sse data error: %v", err)
		return err
	}
	return nil
}
