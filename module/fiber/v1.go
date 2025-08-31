package fiber

import (
	"fmt"
	"net/http"
	"time"

	"adapter/module"
	"adapter/module/common"
	"adapter/module/fiber/context"
	"adapter/module/fiber/model"
	"adapter/module/logger"
	"adapter/relay/llm/v1"

	"github.com/bincooo/ja3"
	"github.com/gofiber/contrib/fiberzap/v2"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"
	xtls "github.com/refraction-networking/utls"
)

var (
	adapters = make([]module.Adapter, 0)
)

func init() {
	adapters = append(adapters,
		v1.New(),
	)
}

func ModelEach(yield func(index int, model model.Model)) {
	idx := 0
	for _, adapter := range adapters {
		for _, mod := range adapter.Model() {
			yield(idx, mod)
			idx++
		}
	}
}

// 初始化fiber api
func Initialized(addr string) {

	http.DefaultTransport.(*http.Transport).IdleConnTimeout = 120 * time.Second
	http.DefaultTransport = ja3.NewTransport(
		ja3.WithProxy("http://127.0.0.1:7890"),
		ja3.WithClientHelloID(xtls.HelloChrome_133),
		ja3.WithOriginalTransport(http.DefaultTransport.(*http.Transport)),
	)

	app := fiber.New()

	app.Use(recover.New(recover.Config{
		EnableStackTrace: true,
		StackTraceHandler: func(ctx *fiber.Ctx, err interface{}) {
			logger.Sugar().Errorf("panic: %v", err)
		},
	}))

	app.Use(fiberzap.New(fiberzap.Config{
		Logger: logger.Logger(),
	}))

	app.Get("/", index)

	app.Post("v1/chat/completions", completions)
	app.Post("v1/object/completions", completions)
	app.Post("proxies/v1/chat/completions", completions)

	app.Post("/v1/embeddings", embeddings)
	app.Post("proxies/v1/embeddings", embeddings)

	app.Post("v1/images/generations", generations)
	app.Post("v1/object/generations", generations)
	app.Post("proxies/v1/images/generations", generations)

	err := app.Listen(addr)
	if err != nil {
		panic(err)
	}
}

func index(ctx *fiber.Ctx) error {
	ctx.Set("content-type", "text/html")
	return common.JustError(
		ctx.WriteString("<div style='color:green'>success ~</div>"),
	)
}

func completions(ctx *fiber.Ctx) (err error) {
	completion := new(model.Completion)
	if err = ctx.BodyParser(completion); err != nil {
		return
	}

	c := context.New(ctx)
	c.Put("completion", completion)
	for _, adapter := range adapters {
		if !adapter.Support(module.RELAY_TYPE_COMPLETIONS, c, completion.Model) {
			continue
		}
		return adapter.Relay(c)
	}

	err = writeError(ctx, fmt.Sprintf("model [%s] is not found", completion.Model))
	return
}

func embeddings(ctx *fiber.Ctx) (err error) {
	embedding := new(model.Embedding)
	if err = ctx.BodyParser(embedding); err != nil {
		return
	}

	c := context.New(ctx)
	c.Put("embedding", embedding)
	for _, adapter := range adapters {
		if adapter.Support(module.RELAY_TYPE_EMBEDDINGS, c, embedding.Model) {
			err = adapter.Embed(c)
			break
		}
	}

	err = writeError(ctx, fmt.Sprintf("model [%s] is not found", embedding.Model))
	return
}

func generations(ctx *fiber.Ctx) (err error) {
	generation := new(model.Generation)
	if err = ctx.BodyParser(generation); err != nil {
		return
	}

	c := context.New(ctx)
	c.Put("generation", generation)
	for _, adapter := range adapters {
		if adapter.Support(module.RELAY_TYPE_GENERATIONS, c, generation.Model) {
			return adapter.Image(c)
		}
	}

	err = writeError(ctx, fmt.Sprintf("model [%s] is not found", generation.Model))
	return
}

func writeError(ctx *fiber.Ctx, msg string) (err error) {
	return ctx.Status(fiber.StatusInternalServerError).
		JSON(model.Record[string, any]{
			"error": msg,
		})
}
