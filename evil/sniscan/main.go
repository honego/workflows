package main

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	jsoniter "github.com/json-iterator/go"
	"github.com/panjf2000/ants/v2"
	"github.com/valyala/fasthttp"
)

const (
	UniversityDataSourceURL = "https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json"

	// 资源控制限制
	MaxConcurrencyCount = 50              // 严格限制并发数
	NetworkTimeout      = 3 * time.Second // 快速失败机制
)

var traceURLs = []string{
	"https://www.qualcomm.cn/cdn-cgi/trace",
	"https://www.prologis.cn/cdn-cgi/trace",
	"https://www.autodesk.com.cn/cdn-cgi/trace",
}

const SpoofedUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

var jsonParser = jsoniter.ConfigCompatibleWithStandardLibrary

var contentDeliveryNetworkKeywords = []string{
	"cloudflare", "akamai", "fastly", "cloudfront", "azure", "vercel", "netlify", "cdn", "gws", "imperva", "sucuri",
}

var originServerKeywords = []string{
	"nginx", "apache", "openresty", "microsoft-iis", "litespeed", "caddy", "jetty", "tomcat", "envoy",
}

type University struct {
	Name        string   `json:"name"`
	Domains     []string `json:"domains"`
	CountryCode string   `json:"alpha_two_code"`
}

type ServerHealthResult struct {
	UniversityName string
	Domain         string
	Latency        time.Duration
	ServerHeader   string
}

var limitResultCount int

func init() {
	log.SetFlags(log.Ltime)
	log.SetOutput(os.Stderr)
	flag.IntVar(&limitResultCount, "n", 10, "Number of results to display")
	flag.Parse()
}

func main() {
	validateIPv4Connectivity()

	localCountryCode := fetchLocalLocationWithFallback()
	log.Printf("[-] Detected Local Region (via Cloudflare): %s", localCountryCode)

	log.Printf("[-] Fetching university list data.")
	targetUniversities := fetchAndFilterUniversities(localCountryCode)
	totalTargetCount := len(targetUniversities)

	if totalTargetCount == 0 {
		log.Printf("[!] No universities found for region: %s", localCountryCode)
		return
	}

	log.Printf("[-] Found %d universities. Starting concurrent analysis (Pool Size: %d)...", totalTargetCount, MaxConcurrencyCount)

	// 初始化并发控制组件
	var validResults []ServerHealthResult
	var resultMutex sync.Mutex
	var waitGroup sync.WaitGroup

	// 实例化协程池
	executionPool, poolError := ants.NewPoolWithFunc(MaxConcurrencyCount, func(interfaceData interface{}) {
		defer waitGroup.Done()
		university := interfaceData.(University)
		processUniversityCheck(university, &validResults, &resultMutex)
	})

	if poolError != nil {
		log.Fatalf("[!] Failed to initialize worker pool: %v", poolError)
	}
	defer executionPool.Release()

	// 任务分发
	startTime := time.Now()
	for _, university := range targetUniversities {
		waitGroup.Add(1)
		invokeError := executionPool.Invoke(university)
		if invokeError != nil {
			waitGroup.Done()
			log.Printf("[!] Task submission failed: %v", invokeError)
		}
	}

	waitGroup.Wait()
	totalDuration := time.Since(startTime)

	sort.Slice(validResults, func(i, j int) bool {
		return validResults[i].Latency < validResults[j].Latency
	})

	displayCount := limitResultCount
	if len(validResults) < limitResultCount {
		displayCount = len(validResults)
	}

	log.Printf("[+] Analysis Complete in %v", totalDuration)
	log.Printf("[+] Identified %d Origin Servers.", len(validResults))

	printTable(validResults, displayCount)
}

func validateIPv4Connectivity() {
	probeTarget := "8.8.8.8:443"

	connection, err := net.DialTimeout("tcp4", probeTarget, 5*time.Second)
	if err != nil {
		log.Printf("[!] IPv4 Probe Failed: %v", err)
		log.Fatalf("[FATAL] This program requires a working IPv4 network stack. IPv6-only environment detected. Exiting.")
	}

	if connection != nil {
		connection.Close()
	}
	log.Printf("[-] IPv4 Connectivity Check: OK")
}

func processUniversityCheck(university University, results *[]ServerHealthResult, mutex *sync.Mutex) {
	if len(university.Domains) == 0 {
		return
	}
	targetDomain := university.Domains[0]

	httpRequest := fasthttp.AcquireRequest()
	httpResponse := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseRequest(httpRequest)
	defer fasthttp.ReleaseResponse(httpResponse)

	httpRequest.Header.SetUserAgent(SpoofedUserAgent)
	httpRequest.Header.SetMethod(fasthttp.MethodHead)

	requestUrl := "http://" + targetDomain
	httpRequest.SetRequestURI(requestUrl)

	checkStartTime := time.Now()

	client := &fasthttp.Client{
		ReadTimeout:     NetworkTimeout,
		WriteTimeout:    NetworkTimeout,
		MaxConnsPerHost: 1,

		TLSConfig: &tls.Config{
			InsecureSkipVerify: true,
		},

		Dial: func(addr string) (net.Conn, error) {
			return net.Dial("tcp4", addr)
		},
	}

	connectionError := client.Do(httpRequest, httpResponse)

	if connectionError != nil {
		httpRequest.SetRequestURI("https://" + targetDomain)
		checkStartTime = time.Now()
		connectionError = client.Do(httpRequest, httpResponse)
	}

	if connectionError != nil {
		return
	}

	latencyDuration := time.Since(checkStartTime)
	serverHeaderValue := string(httpResponse.Header.Peek("Server"))

	if isOriginServer(serverHeaderValue) {
		mutex.Lock()
		*results = append(*results, ServerHealthResult{
			UniversityName: university.Name,
			Domain:         targetDomain,
			Latency:        latencyDuration,
			ServerHeader:   serverHeaderValue,
		})
		mutex.Unlock()
	}
}

func isOriginServer(serverHeader string) bool {
	lowerCaseHeader := strings.ToLower(serverHeader)
	if lowerCaseHeader == "" {
		return true
	}
	for _, cdnKeyword := range contentDeliveryNetworkKeywords {
		if strings.Contains(lowerCaseHeader, cdnKeyword) {
			return false
		}
	}
	for _, originKeyword := range originServerKeywords {
		if strings.Contains(lowerCaseHeader, originKeyword) {
			return true
		}
	}
	return true
}

func fetchLocalLocationWithFallback() string {
	ipv4Client := &fasthttp.Client{
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,

		TLSConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
		Dial: func(addr string) (net.Conn, error) {
			return net.Dial("tcp4", addr)
		},
	}

	for _, url := range traceURLs {
		log.Printf("[-] Probing location via: %s", url)

		req := fasthttp.AcquireRequest()
		resp := fasthttp.AcquireResponse()

		req.SetRequestURI(url)
		req.Header.SetUserAgent(SpoofedUserAgent)

		err := ipv4Client.Do(req, resp)
		if err == nil && resp.StatusCode() == fasthttp.StatusOK {
			loc := parseLocFromTraceBody(resp.Body())
			fasthttp.ReleaseRequest(req)
			fasthttp.ReleaseResponse(resp)

			if loc != "" {
				return loc
			}
		} else {
			log.Printf("[!] Probe failed or blocked: %s (Error: %v)", url, err)
		}

		fasthttp.ReleaseRequest(req)
		fasthttp.ReleaseResponse(resp)
	}

	log.Printf("[!] All location probes failed (but network is up). Defaulting to US.")
	return "US"
}

func parseLocFromTraceBody(body []byte) string {
	scanner := bufio.NewScanner(bytes.NewReader(body))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "loc=") {
			parts := strings.Split(line, "=")
			if len(parts) == 2 {
				return parts[1]
			}
		}
	}
	return ""
}

func fetchAndFilterUniversities(targetCountryCode string) []University {
	client := &fasthttp.Client{
		Dial: func(addr string) (net.Conn, error) {
			return net.Dial("tcp4", addr)
		},
		TLSConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
	}

	statusCode, body, err := client.Get(nil, UniversityDataSourceURL)
	if err != nil || statusCode != fasthttp.StatusOK {
		log.Fatalf("[!] Critical: Failed to download university list (IPv4). Error: %v", err)
	}

	var allUniversities []University
	if decodeError := jsonParser.Unmarshal(body, &allUniversities); decodeError != nil {
		log.Fatalf("[!] Critical: Failed to parse JSON database. Error: %v", decodeError)
	}

	var filteredUniversities []University
	for _, university := range allUniversities {
		if university.CountryCode == targetCountryCode {
			filteredUniversities = append(filteredUniversities, university)
		}
	}
	return filteredUniversities
}

func printTable(results []ServerHealthResult, limit int) {
	fmt.Println("")
	fmt.Printf("%-50s %-30s %-15s %-20s\n", "University", "Domain", "Latency", "Server")
	fmt.Println(strings.Repeat("-", 120))

	for i := 0; i < limit; i++ {
		result := results[i]
		fmt.Printf("%-50s %-30s %-15s %-20s\n",
			truncateString(result.UniversityName, 48),
			truncateString(result.Domain, 28),
			result.Latency,
			truncateString(result.ServerHeader, 18))
	}
}

func truncateString(text string, maxLength int) string {
	if len(text) > maxLength {
		return text[:maxLength-3] + "..."
	}
	return text
}
