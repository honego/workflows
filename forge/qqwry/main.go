package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"

	"github.com/ipipdotnet/ipdb-go"
)

var (
	port   string
	dbPath string
	db     *ipdb.City
)

func init() {
	flag.StringVar(&port, "port", "2060", "HTTP request listening port")
	flag.StringVar(&dbPath, "qqwry", "./qqwry.ipdb", "IP database file path")
}

func main() {
	// 统一解析参数
	flag.Parse()

	// 初始化加载 IP 数据库
	var err error
	db, err = ipdb.NewCity(dbPath)
	if err != nil {
		log.Fatalf("Initialization terminated, failed to load IP database [%s]: %v", dbPath, err)
	}

	// 注册查询接口
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")

		ip := r.URL.Query().Get("ip")
		if ip == "" {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"error": "missing ip parameter"}`))
			return
		}

		// IP合法校验
		if net.ParseIP(ip) == nil {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"error": "invalid IP address format"}`))
			return
		}

		lang := "EN"
		if strings.ToUpper(r.URL.Query().Get("lang")) == "CN" {
			lang = "CN"
		}

		info, err := db.FindMap(ip, lang)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(fmt.Sprintf(`{"error": "%v"}`, err)))
			return
		}

		// 构建 JSON 响应
		encodeErr := json.NewEncoder(w).Encode(map[string]string{
			"country_name":   info["country_name"],
			"region_name":    info["region_name"],
			"city_name":      info["city_name"],
			"district_name":  info["district_name"],
			"owner_domain":   info["owner_domain"],
			"isp_domain":     info["isp_domain"],
			"country_code":   info["country_code"],
			"continent_code": info["continent_code"],
		})

		if encodeErr != nil {
			// 写入响应体失败 记录服务端日志
			log.Printf("Failed to encode JSON response (IP: %s): %v\n", ip, encodeErr)
		}
	})

	addr := fmt.Sprintf(":%s", port)
	log.Printf("Loaded IP database file: %s", dbPath)

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("HTTP server runtime error: %v", err)
	}
}
