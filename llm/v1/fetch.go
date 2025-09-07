package v1

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/bincooo/ago/kit"
	"github.com/bincooo/ago/model"

	"github.com/go-resty/resty/v2"
)

func fetch(ctx *model.Ctx) (r *resty.Response, err error) {
	var (
		completion = model.JustValue[string, *model.Completion](ctx.Record, "completion")
	)

	completion = kit.Copy(completion)

	splinter := strings.Split(completion.Model, "/")
	mod := strings.Join(splinter[1:], "/")
	prefix := splinter[0]
	reversal := "undefined"

	for _, rec := range schema {
		if rec.ValueEqual("prefix", prefix) {
			reversal = model.JustValue[string, string](rec, "reversal")
			break
		}
	}

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
	completion.Model = strings.Replace(mod, "_", "/", -1)
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
		Post(reversal + "/chat/completions")
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
