package context

import (
	"fmt"

	"adapter/module/fiber/model"
)

func NewSSEResponse(content string, created int64) *model.Response {
	return &model.Response{
		Model:   "LLM",
		Created: created,
		Id:      fmt.Sprintf("chatcmpl-%d", created),
		Object:  "chat.completion.chunk",
		Choices: []model.Choice{
			{
				Index: 0,
				Delta: &struct {
					Type             string `json:"type,omitempty"`
					Role             string `json:"role,omitempty"`
					Content          string `json:"content,omitempty"`
					ReasoningContent string `json:"reasoning_content,omitempty"`

					ToolCalls []model.ChoiceToolCall `json:"tool_calls,omitempty"`
				}{"text", "assistant", content, "", nil},
			},
		},
	}
}

func NewResponse(content string, created int64) *model.Response {
	stop := "stop"
	return &model.Response{
		Model:   "LLM",
		Created: created,
		Id:      fmt.Sprintf("chatcmpl-%d", created),
		Object:  "chat.completion",
		Choices: []model.Choice{
			{
				Index: 0,
				Message: &struct {
					Role             string `json:"role,omitempty"`
					Content          string `json:"content,omitempty"`
					ReasoningContent string `json:"reasoning_content,omitempty"`

					ToolCalls []model.ChoiceToolCall `json:"tool_calls,omitempty"`
				}{"assistant", content, "", nil},
				FinishReason: &stop,
			},
		},
		//Usage: usage,
	}
}
