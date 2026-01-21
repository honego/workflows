package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/schollz/progressbar/v3"
	"github.com/tidwall/gjson"
	"golang.org/x/sync/errgroup"
)

const (
	googleTranslateAPIURL = "https://translate.googleapis.com/translate_a/single"
	maxChunkRunes         = 4000
)

var (
	retryClient *retryablehttp.Client
	targetLang  string
	concurrency int
)

type chunkInfo struct {
	text       string
	addParaSep bool
}

func init() {
	rand.Seed(time.Now().UnixNano())
	retryClient = retryablehttp.NewClient()
	retryClient.RetryMax = 5
	retryClient.RetryWaitMin = 500 * time.Millisecond
	retryClient.RetryWaitMax = 4 * time.Second
	retryClient.Logger = nil
}

func main() {
	log.SetFlags(log.LstdFlags)

	for _, arg := range os.Args[1:] {
		if arg == "-h" || arg == "--help" {
			printUsage()
		}
	}

	flag.StringVar(&targetLang, "tl", "en", "target language code (default: en)")
	flag.IntVar(&concurrency, "c", 4, "concurrency level (default: 4, recommended 3-6)")
	flag.Parse()

	if flag.NArg() != 1 {
		log.Fatal("Input file is required! Use -h for help.")
	}
	if concurrency < 1 {
		concurrency = 1
	}
	if concurrency > 10 {
		log.Printf("Concurrency too high, may trigger rate limiting. Auto-capped at 10.")
		concurrency = 10
	}

	inputFile := flag.Arg(0)
	if _, err := os.Stat(inputFile); os.IsNotExist(err) {
		log.Fatalf("File not found: %s", inputFile)
	}

	outputFile := generateOutputFilename(inputFile)
	log.Printf("Starting task: %s → %s (target: %s, concurrency: %d)", inputFile, outputFile, targetLang, concurrency)

	contentBytes, err := os.ReadFile(inputFile)
	if err != nil {
		log.Fatalf("Failed to read file: %v", err)
	}
	content := string(contentBytes)

	if strings.TrimSpace(content) == "" {
		log.Println("File is empty, copying as-is.")
		if err := os.WriteFile(outputFile, contentBytes, 0644); err != nil {
			log.Printf("Failed to write output file: %v", err)
		}
		return
	}

	chunks := splitIntoChunks(content)

	if len(chunks) == 0 {
		log.Fatal("Failed to split into chunks.")
	}

	bar := progressbar.Default(int64(len(chunks)), "Translating")

	startTime := time.Now()
	var g errgroup.Group
	g.SetLimit(concurrency)

	results := make([]string, len(chunks))
	var mu sync.Mutex

	for i, ch := range chunks {
		i := i
		ch := ch
		g.Go(func() error {
			trans := ch.text
			if strings.TrimSpace(ch.text) != "" {
				var err error
				trans, err = translateChunk(ch.text)
				if err != nil {
					log.Printf("Chunk %d failed: %v → keeping original", i, err)
					trans = ch.text
				}
			}
			mu.Lock()
			results[i] = trans
			mu.Unlock()
			_ = bar.Add(1)
			time.Sleep(time.Duration(rand.Intn(600)+400) * time.Millisecond)
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		log.Fatalf("Concurrency error: %v", err)
	}

	var final strings.Builder
	for i, res := range results {
		final.WriteString(res)
		if chunks[i].addParaSep {
			final.WriteString("\n\n")
		}
	}

	translatedText := postProcess(final.String())

	if err := os.WriteFile(outputFile, []byte(translatedText), 0644); err != nil {
		log.Fatalf("Failed to write output: %v", err)
	}

	totalRunes := len([]rune(content))
	elapsed := time.Since(startTime)
	log.Printf("Done! Saved to: %s", outputFile)
	log.Printf("Stats → Characters: %d | Time: %s | Speed: %.0f chars/sec",
		totalRunes, elapsed.Round(time.Second), float64(totalRunes)/elapsed.Seconds())
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `
translate - Advanced free Google Translate CLI tool (2026 Ultimate Edition)

Usage:
  translate [options] <input_file>

Options:
  -h, --help              Show this help message
  -tl <code>              Target language (default: en)
  -c <num>                Concurrency level (default: 4, recommended 3-6)

Examples:
  translate -tl en -c 5 novel.txt
  translate -tl fr docs.md

Features:
  • Smart paragraph/line chunking, preserves original structure
  • Concurrent processing with beautiful progress bar
  • Enterprise-grade retries + random delays to avoid bans
  • Ultra-fast gjson parsing + rock-solid retryablehttp
  • Failed chunks automatically keep original text
  • Output filename auto-appended with _<tl>

No registration, no API key required — pure free Google Translate power.
`)
	os.Exit(0)
}

func splitIntoChunks(text string) []chunkInfo {
	var chunks []chunkInfo
	paragraphs := strings.Split(text, "\n\n")

	for paraIdx, para := range paragraphs {
		trimmed := strings.TrimSpace(para)
		if trimmed == "" {
			chunks = append(chunks, chunkInfo{"", true})
			continue
		}

		lines := strings.Split(para, "\n")
		var current strings.Builder

		for _, line := range lines {
			test := line
			if current.Len() > 0 {
				test = "\n" + line
			}
			if len([]rune(current.String()+test)) > maxChunkRunes && current.Len() > 0 {
				chunks = append(chunks, chunkInfo{current.String(), false})
				current.Reset()
			}
			if current.Len() > 0 {
				current.WriteString("\n")
			}
			current.WriteString(line)
		}

		if current.Len() > 0 {
			addSep := paraIdx < len(paragraphs)-1
			chunks = append(chunks, chunkInfo{current.String(), addSep})
		}
	}
	return chunks
}

func translateChunk(text string) (string, error) {
	params := url.Values{
		"client": {"gtx"},
		"sl":     {"auto"},
		"tl":     {targetLang},
		"dt":     {"t"},
		"q":      {text},
	}

	req, err := retryablehttp.NewRequest("GET", googleTranslateAPIURL+"?"+params.Encode(), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
	req.Header.Set("Referer", "https://translate.google.com/")

	resp, err := retryClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var builder strings.Builder
	gjson.Get(string(body), "0").ForEach(func(_, sentence gjson.Result) bool {
		if sentence.IsArray() && sentence.Array()[0].Exists() {
			builder.WriteString(sentence.Array()[0].String())
		}
		return true
	})

	return builder.String(), nil
}

func postProcess(text string) string {
	var cleaned []string
	for _, line := range strings.Split(text, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			if len(cleaned) == 0 || cleaned[len(cleaned)-1] != "" {
				cleaned = append(cleaned, "")
			}
		} else {
			cleaned = append(cleaned, trimmed)
		}
	}
	return strings.Join(cleaned, "\n")
}

func generateOutputFilename(path string) string {
	ext := filepath.Ext(path)
	name := strings.TrimSuffix(path, ext)
	return name + "_" + targetLang + ext
}
