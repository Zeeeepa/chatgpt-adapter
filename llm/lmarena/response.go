package lmarena

import (
	"bufio"
	"encoding/json"
	"strings"

	"github.com/bincooo/ago/logger"
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

			raw := ""
			if strings.HasPrefix(data, "a0:") {
				err := json.Unmarshal([]byte(data)[3:], &raw)
				if err != nil {
					logger.Sugar().Error(err)
					return
				}
			}

			if strings.HasPrefix(data, "ad:") {
				var obj map[string]interface{}
				err := json.Unmarshal([]byte(data)[3:], &obj)
				if err != nil {
					logger.Sugar().Error(err)
					return
				}

				finishReason, ok := obj["finishReason"]
				if ok && finishReason == "stop" {
					break
				}
			}

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
