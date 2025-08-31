package v1

import (
	"adapter/module/common"
	"adapter/module/fiber/context"
	"adapter/module/fiber/model"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/go-resty/resty/v2"
)

func fetch(ctx *context.Ctx) (r *resty.Response, err error) {
	var (
		llm        = model.JustValue[string, model.Record[string, any]](ctx.Record, "custom-llm")
		completion = model.JustValue[string, *model.Completion](ctx.Record, "completion")
	)

	completion = common.Copy(completion)
	if completion.TopP == 0 {
		completion.TopP = 1
	}

	if completion.Temperature == 0 {
		completion.Temperature = 0.7
	}

	if completion.MaxTokens == 0 {
		completion.MaxTokens = 1024
	}

	completion.Stream = true
	completion.Model = model.JustValue[string, string](ctx.Record, "original-model")
	obj, err := toMap(completion)
	if err != nil {
		return nil, err
	}

	if completion.TopK == 0 {
		delete(obj, "top_k")
	}

	client := resty.New().SetTransport(http.DefaultTransport)
	r, err = client.R().
		SetHeader("Content-Type", "application/json").
		SetHeader("Authorization", "Bearer "+ctx.Token).
		SetDoNotParseResponse(true).
		SetBody(obj).
		Post(model.JustValue[string, string](llm, "reversal") + "/chat/completions")
	if err != nil {
		return
	}

	if !r.IsSuccess() {
		chunk, ioerr := io.ReadAll(r.RawResponse.Body)
		if ioerr != nil {
			err = errors.New(r.RawResponse.Status)
			return
		}
		err = errors.New(string(chunk))
	}

	return
}

func toMap(obj interface{}) (mo map[string]interface{}, err error) {
	if obj == nil {
		return
	}

	bytes, err := json.Marshal(obj)
	if err != nil {
		return
	}

	err = json.Unmarshal(bytes, &mo)
	return
}
