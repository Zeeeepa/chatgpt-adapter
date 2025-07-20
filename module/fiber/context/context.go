package context

import (
	"bufio"
	"encoding/json"
	"fmt"
	"strings"

	"adapter/module/fiber/model"
	"adapter/module/logger"
	"github.com/gofiber/fiber/v2"
)

const (
	SSE_EOF = "EOF"

	SSE_DATA SSEEvent = iota
	SSE_ERROR
	SSE_EVENT
)

type SSEEvent = byte

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

func (ctx *Ctx) FiberCtx() *fiber.Ctx {
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
			return write(w, SSE_DATA, msg)
		})
	})
	return
}

func token(ctx *fiber.Ctx) (token string) {
	token = ctx.Get("X-Api-Key")
	if token == "" {
		token = strings.TrimPrefix(ctx.Get("Authorization"), "Bearer ")
	}
	return
}

func write(w *bufio.Writer, event SSEEvent, msg interface{}) error {

	if err, ok := msg.(error); ok {
		msg = err.Error()
	} else if obj, ok := msg.(interface{ String() string }); ok {
		msg = obj.String()
	} else if chunk, ok := msg.([]byte); ok {
		msg = string(chunk)
	} else if _, ok = msg.(string); !ok {
		msg, err = json.Marshal(msg)
		if err != nil {
			msg = err.Error()
		}
	}

	var err error
	switch event {
	case SSE_DATA:
		separator := "\n\n"
		if msg == SSE_EOF {
			msg = "[done]"
			separator = ""
		}
		_, err = w.WriteString(fmt.Sprintf("data: %v%s", msg, separator))
	case SSE_ERROR:
		_, err = w.WriteString(fmt.Sprintf("error: %v\n\n", msg))
	default:
		_, err = w.WriteString(fmt.Sprintf("event: %v\n\n", msg))
	}

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
