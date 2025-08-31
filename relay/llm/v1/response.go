package v1

import (
	"adapter/module/fiber/model"
	"adapter/module/logger"
	"bufio"
	"encoding/json"

	"github.com/go-resty/resty/v2"
)

type ChunkBody struct {
	Chunk string
	Think string
}

func waitChannel(r *resty.Response) *ChunkBody {
	channel := createChannel(r)
	var chunk ChunkBody
	for {
		bodies, ok := <-channel
		if !ok {
			break
		}
		chunk.Chunk += bodies.Chunk
		chunk.Think = bodies.Think
	}
	return &chunk
}

func createChannel(r *resty.Response) chan *ChunkBody {
	channel := make(chan *ChunkBody)
	go func() {
		defer close(channel)

		response := r.RawResponse
		scanner := bufio.NewScanner(response.Body)
		for {
			if !scanner.Scan() {
				if err := scanner.Err(); err != nil {
					logger.Sugar().Error(err)
				}
				break
			}

			data := scanner.Text()
			logger.Sugar().Debugf("--------- ORIGINAL MESSAGE ---------")
			logger.Sugar().Debugf("%s", data)

			if len(data) < 6 || data[:6] != "data: " {
				continue
			}

			data = data[6:]
			if data == "[DONE]" {
				break
			}

			var chat model.Response
			err := json.Unmarshal([]byte(data), &chat)
			if err != nil {
				logger.Sugar().Error(err)
				continue
			}

			if len(chat.Choices) == 0 {
				continue
			}

			choice := chat.Choices[0]
			if choice.Delta.Role != "" && choice.Delta.Role != "assistant" {
				continue
			}

			if choice.FinishReason != nil && *choice.FinishReason == "stop" {
				continue
			}

			raw := choice.Delta.Content
			logger.Sugar().Debug("----- raw -----")
			logger.Sugar().Debug(raw)

			if len(raw) == 0 {
				continue
			}

			channel <- &ChunkBody{
				Chunk: raw,
			}
		}
	}()

	return channel
}
