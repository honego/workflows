package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	// Google翻译公共API
	googleTranslateAPIURL = "https://translate.googleapis.com/translate_a/single"
	// 每次请求的最大字符长度限制
	maxChunkSize = 1500
)

func main() {
	// 设置日志格式
	log.SetFlags(log.LstdFlags)

	if len(os.Args) < 2 {
		log.Fatal("Usage: trans <filename>")
	}

	inputFilePath := os.Args[1]
	if _, err := os.Stat(inputFilePath); os.IsNotExist(err) {
		log.Fatalf("File '%s' not found", inputFilePath)
	}

	outputFilePath := generateOutputFilename(inputFilePath)
	log.Printf("Task: %s -> %s", inputFilePath, outputFilePath)

	fileContentBytes, err := os.ReadFile(inputFilePath)
	if err != nil {
		log.Fatalf("Failed to read file: %v", err)
	}

	fileContentString := string(fileContentBytes)
	if len(strings.TrimSpace(fileContentString)) == 0 {
		log.Println("Warning: File is empty")
		return
	}

	// 分块翻译
	finalTranslatedText := translateLongTextInChunks(fileContentString)

	err = os.WriteFile(outputFilePath, []byte(finalTranslatedText), 0644)
	if err != nil {
		log.Fatalf("Failed to write file: %v", err)
	}

	log.Printf("Success! Saved to: %s", outputFilePath)
}

func translateLongTextInChunks(sourceText string) string {
	var translationBuilder strings.Builder
	sourceRunes := []rune(sourceText)
	totalRunesCount := len(sourceRunes)

	for currentIndex := 0; currentIndex < totalRunesCount; currentIndex += maxChunkSize {
		chunkEndIndex := currentIndex + maxChunkSize
		if chunkEndIndex > totalRunesCount {
			chunkEndIndex = totalRunesCount
		}

		currentTextChunk := string(sourceRunes[currentIndex:chunkEndIndex])
		log.Printf("Processing chunk... (%d/%d chars)", chunkEndIndex, totalRunesCount)

		translatedChunkText, err := executeGoogleTranslateRequest(currentTextChunk)
		if err != nil {
			log.Printf("Translation failed for a chunk: %v", err)
			// 失败保留原文
			translationBuilder.WriteString(currentTextChunk)
		} else {
			translationBuilder.WriteString(translatedChunkText)
		}

		// 延迟防止封禁
		time.Sleep(200 * time.Millisecond)
	}
	return translationBuilder.String()
}

func executeGoogleTranslateRequest(textToTranslate string) (string, error) {
	queryParameters := url.Values{}
	queryParameters.Add("client", "gtx")
	queryParameters.Add("sl", "auto") // Source Language
	queryParameters.Add("tl", "en")   // Target Language
	queryParameters.Add("dt", "t")    // Data Type
	queryParameters.Add("q", textToTranslate)

	httpResponse, err := http.Get(googleTranslateAPIURL + "?" + queryParameters.Encode())
	if err != nil {
		return "", err
	}
	defer httpResponse.Body.Close()

	if httpResponse.StatusCode != 200 {
		return "", fmt.Errorf("API status: %d", httpResponse.StatusCode)
	}

	responseBodyBytes, _ := io.ReadAll(httpResponse.Body)

	// 解析JSON结构
	var parsedJSONRoot []interface{}
	if err := json.Unmarshal(responseBodyBytes, &parsedJSONRoot); err != nil {
		return "", err
	}

	if len(parsedJSONRoot) > 0 {
		if sentencesArray, ok := parsedJSONRoot[0].([]interface{}); ok {
			var chunkTranslationBuilder strings.Builder
			for _, singleSentenceItem := range sentencesArray {
				if sentenceProperties, ok := singleSentenceItem.([]interface{}); ok && len(sentenceProperties) > 0 {
					if translatedSentenceText, ok := sentenceProperties[0].(string); ok {
						chunkTranslationBuilder.WriteString(translatedSentenceText)
					}
				}
			}
			return chunkTranslationBuilder.String(), nil
		}
	}
	return "", fmt.Errorf("failed to parse response")
}

func generateOutputFilename(originalFilePath string) string {
	fileExtension := filepath.Ext(originalFilePath)
	fileNameWithoutExtension := strings.TrimSuffix(originalFilePath, fileExtension)
	return fileNameWithoutExtension + "_en" + fileExtension
}
