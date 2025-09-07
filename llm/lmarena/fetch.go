package lmarena

import (
	"context"
	"errors"
	"io"
	"strings"
	"time"

	"github.com/bincooo/ago/kit/chromium"
	"github.com/bincooo/ago/logger"
	"github.com/bincooo/ago/model"
	"github.com/go-resty/resty/v2"
	"github.com/google/uuid"
)

const (
	baseUrl = "https://lmarena.ai/nextjs-api"
)

var (
	token     = ""
	userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0"
	lang      = "en-US,en;q=0.5"
)

type Request struct {
	Id              string `json:"id"`
	Mode            string `json:"mode"`
	ModelAId        string `json:"modelAId"`
	UserMessageId   string `json:"userMessageId"`
	ModelAMessageId string `json:"modelAMessageId"`
	Modality        string `json:"modality"`

	Messages []ChatMessage `json:"messages"`
}

type ChatMessage struct {
	Id                      string        `json:"id"`
	Role                    string        `json:"role"`
	Content                 string        `json:"content"`
	ExperimentalAttachments []interface{} `json:"experimental_attachments"`
	ParentMessageIds        []string      `json:"parentMessageIds"`
	ParticipantPosition     string        `json:"participantPosition"`
	ModelId                 *string       `json:"modelId"`
	EvaluationSessionId     string        `json:"evaluationSessionId"`
	Status                  string        `json:"status"`
	FailureReason           interface{}   `json:"failureReason"`
}

func fetch(ctx *model.Ctx) (response *resty.Response, err error) {

	if ctx.Token == "" {
		ctx.Token = getToken()
	}

	sessionId := uuid.NewString()
	messageId := uuid.NewString()
	modelMessageId := uuid.NewString()

	completion := model.JustValue[string, *model.Completion](ctx.Record, "completion")
	modelId := modelMap[strings.Split(completion.Model, "/")[1]]
	messages, err := mergeMessages(completion)
	if err != nil {
		return
	}

	req := Request{
		Id:              uuid.NewString(),
		Mode:            "direct",
		ModelAId:        modelId,
		UserMessageId:   messageId,
		ModelAMessageId: modelMessageId,
		Messages: []ChatMessage{
			{
				Id:                      messageId,
				Role:                    "user",
				Content:                 messages,
				ExperimentalAttachments: make([]interface{}, 0),
				ParentMessageIds:        make([]string, 0),
				ParticipantPosition:     "a",
				ModelId:                 nil,
				EvaluationSessionId:     sessionId,
				Status:                  "pending",
				FailureReason:           nil,
			},
			{
				Id:                      modelMessageId,
				Role:                    "assistant",
				Content:                 "",
				ExperimentalAttachments: make([]interface{}, 0),
				ParentMessageIds: []string{
					messageId,
				},
				ParticipantPosition: "a",
				ModelId:             &modelId,
				EvaluationSessionId: sessionId,
				Status:              "pending",
				FailureReason:       nil,
			},
		},
		Modality: "chat",
	}

	client := resty.New().SetTransport(Sdk.Transport(Sdk.Env().GetString("server.proxied")))
	response, err = client.R().
		SetContext(ctx.Ctx().Context()).
		SetHeader("User-Agent", userAgent).
		SetHeader("Accept-Language", lang).
		SetHeader("Cache-Control", "no-cache").
		//SetHeader("Accept-Encoding", "gzip, deflate, br, zstd").
		SetHeader("Origin", baseUrl).
		SetHeader("Content-Type", "application/json").
		SetHeader("Cookie", ctx.Token).
		SetDoNotParseResponse(true).
		SetBody(req).
		Post(baseUrl + "/stream/create-evaluation")
	if err != nil {
		return
	}

	if !response.IsSuccess() {
		if response.StatusCode() == 403 {
			token = ""
		}

		chunk, ioerr := io.ReadAll(response.RawResponse.Body)
		if ioerr != nil {
			err = errors.New(response.RawResponse.Status)
			return
		}

		err = errors.New(string(chunk))
	}

	return
}

func getToken() string {
	if token != "" {
		return token
	}

	timeout, cancel := context.WithTimeout(context.Background(), time.Second*150)
	defer cancel()

	chrome, chromeFunc := Sdk.Chrome(timeout, Sdk.Env().GetString("server.proxied"), "rand", "")
	defer chromeFunc()

	err := chromium.Run(chrome,
		chromium.EvaluateHook2(),
		chromium.TaskLogger("进入网页: https://lmarena.ai"),
		chromium.Goto("https://lmarena.ai"),
		chromium.TaskLogger("开始过盾..."),
		chromium.WaitCLickXY("div.shadow-root", 30*time.Second,
			chromium.Assert(func(ctx context.Context) bool {
				title := chromium.Title(ctx)
				return !strings.Contains(title, "Just a moment")
			}, "点击节点失败")),

		chromium.WhileTimeout(30*time.Second, 5*time.Second, false,
			chromium.WaitVisible("textarea[rows='1']"),
		),

		chromium.Sleep(5*time.Second),
		chromium.TaskLogger("发送一条消息1"),
		chromium.Input("textarea[rows='1']", "hi"),
		chromium.Sleep(3*time.Second),
		chromium.Input("textarea[rows='1']", "\n"),

		chromium.Sleep(3*time.Second),
		chromium.TaskLogger("发送一条消息2"),
		chromium.Click("div[data-sentry-component='DialogFooter'] button[type='submit']"),

		chromium.TaskLogger("再次过盾..."),
		chromium.WhileTimeout(30*time.Second, 5*time.Second, false,
			chromium.WaitVisible("div.shadow-root"),
		),
		chromium.WaitCLickXY("div.shadow-root", 60*time.Second,
			chromium.Assert(func(ctx context.Context) bool {
				token, lang, userAgent, _ = chromium.GetCookies(ctx)
				return strings.Contains(token, "arena-auth-prod-v1")
			}, "点击节点失败")),
	)
	if err != nil {
		logger.Sugar().Error(err)
		token = ""
	}

	return token
}

func mergeMessages(completion *model.Completion) (newMessages string, err error) {
	var (
		messages = completion.Messages
	)

	messageL := len(messages)
	if messageL == 1 {
		newMessages = model.JustValue[string, string](messages[0], "content")
		return
	}

	var (
		pos      = 0
		contents []string
	)

	for {
		if pos > messageL-1 {
			break
		}

		message := messages[pos]
		role := convertRole(model.JustValue[string, string](message, "role"))
		contents = append(contents, role+model.JustValue[string, string](message, "content"))
		pos++
	}

	newMessages = strings.Join(contents, "\n\n")
	return
}

func convertRole(role string) string {
	switch role {
	case "user":
		return "Human: "
	case "assistant":
		return "Assistant: "
	default:
		return "SYSTEM: "
	}
}
