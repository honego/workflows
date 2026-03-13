package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"

	"github.com/ipipdotnet/ipdb-go"
)

var (
	listenPort   string
	databasePath string
	ipDatabase   *ipdb.City
)

func init() {
	flag.StringVar(&listenPort, "port", "2060", "HTTP request listening port")
	flag.StringVar(&databasePath, "qqwry", "./qqwry.ipdb", "IP database file path")
}

func main() {
	// 统一解析参数
	flag.Parse()

	// 初始化加载 IP 数据库
	var initError error
	ipDatabase, initError = ipdb.NewCity(databasePath)
	if initError != nil {
		log.Fatalf("Initialization terminated, failed to load IP database [%s]: %v", databasePath, initError)
	}

	// 注册查询接口
	http.HandleFunc("/", func(responseWriter http.ResponseWriter, request *http.Request) {
		responseWriter.Header().Set("Content-Type", "application/json; charset=utf-8")

		targetIP := request.URL.Query().Get("ip")
		if targetIP == "" {
			responseWriter.WriteHeader(http.StatusBadRequest)
			_, _ = responseWriter.Write([]byte(`{"error": "missing ip parameter"}`))
			return
		}

		// IP合法校验
		if net.ParseIP(targetIP) == nil {
			responseWriter.WriteHeader(http.StatusBadRequest)
			_, _ = responseWriter.Write([]byte(`{"error": "invalid IP address format"}`))
			return
		}

		locationInfo, queryError := ipDatabase.FindMap(targetIP, "CN")
		if queryError != nil {
			responseWriter.WriteHeader(http.StatusInternalServerError)
			_, _ = responseWriter.Write([]byte(fmt.Sprintf(`{"error": "%v"}`, queryError)))
			return
		}

		// 构建 JSON 响应
		encodeError := json.NewEncoder(responseWriter).Encode(map[string]string{
			"country_name":   locationInfo["country_name"],
			"region_name":    locationInfo["region_name"],
			"city_name":      locationInfo["city_name"],
			"district_name":  locationInfo["district_name"],
			"owner_domain":   locationInfo["owner_domain"],
			"isp_domain":     locationInfo["isp_domain"],
			"country_code":   locationInfo["country_code"],
			"continent_code": locationInfo["continent_code"],
		})

		if encodeError != nil {
			// 写入响应体失败 记录服务端日志
			log.Printf("Failed to encode JSON response (IP: %s): %v\n", targetIP, encodeError)
		}
	})

	serverAddress := fmt.Sprintf(":%s", listenPort)
	log.Printf("Loaded IP database file: %s", databasePath)

	if serveError := http.ListenAndServe(serverAddress, nil); serveError != nil {
		log.Fatalf("HTTP server runtime error: %v", serveError)
	}
}
