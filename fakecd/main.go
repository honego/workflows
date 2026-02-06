package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"

	"gopkg.in/yaml.v3"
)

// 全局配置变量
var (
	dockerComposeFilePath string
	serverPort            string
	authenticationToken   string
	fileMutex             sync.Mutex                                    // 文件锁
	inputValidator        = regexp.MustCompile(`^[a-zA-Z0-9_\-\.\/]+$`) // 防止Shell注入
)

// 请求体结构
type DeployRequest struct {
	ImageRepo string `json:"image"`
	NewTag    string `json:"tag"`
}

func main() {
	flag.StringVar(&dockerComposeFilePath, "file", "", "docker-compose 文件路径")
	flag.StringVar(&serverPort, "port", "5000", "监听端口")
	flag.Parse()

	// 检查环境变量中的Token
	authenticationToken = os.Getenv("FAKECD_TOKEN")
	if authenticationToken == "" {
		log.Fatal("Startup failed: Please set FAKECD_TOKEN environment variable")
	}

	if dockerComposeFilePath == "" {
		if _, err := os.Stat("docker-compose.yaml"); err == nil {
			dockerComposeFilePath = "docker-compose.yaml"
		} else if _, err := os.Stat("docker-compose.yml"); err == nil {
			dockerComposeFilePath = "docker-compose.yml"
		} else {
			log.Fatal("Startup failed: docker-compose file not found")
		}
	}

	log.Printf("FakeCD started | Port: %s | File: %s", serverPort, dockerComposeFilePath)

	// 注册路由
	http.HandleFunc("/deploy", authenticationMiddleware(handleDeploy))

	if err := http.ListenAndServe(":"+serverPort, nil); err != nil {
		log.Fatal(err)
	}
}

// 鉴权中间件
func authenticationMiddleware(nextHandler http.HandlerFunc) http.HandlerFunc {
	return func(responseWriter http.ResponseWriter, httpRequest *http.Request) {
		tokenHeader := httpRequest.Header.Get("Authorization")
		// 比对Token
		if tokenHeader != authenticationToken {
			log.Printf("Auth failed: %s", httpRequest.RemoteAddr)
			http.Error(responseWriter, "Unauthorized", http.StatusUnauthorized)
			return
		}
		nextHandler(responseWriter, httpRequest)
	}
}

// 处理部署请求的主逻辑
func handleDeploy(responseWriter http.ResponseWriter, httpRequest *http.Request) {
	if httpRequest.Method != http.MethodPost {
		http.Error(responseWriter, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var deployRequest DeployRequest
	if err := json.NewDecoder(httpRequest.Body).Decode(&deployRequest); err != nil {
		http.Error(responseWriter, "JSON parse error", http.StatusBadRequest)
		return
	}

	// 检查输入字符是否合法
	if !inputValidator.MatchString(deployRequest.ImageRepo) || !inputValidator.MatchString(deployRequest.NewTag) {
		http.Error(responseWriter, "Invalid input characters", http.StatusBadRequest)
		return
	}

	fileMutex.Lock()
	defer fileMutex.Unlock()

	// 更新文件
	updatedServiceNames, err := updateImageInFile(deployRequest.ImageRepo, deployRequest.NewTag)
	if err != nil {
		log.Printf("File update error: %v", err)
		http.Error(responseWriter, fmt.Sprintf("File Error: %v", err), http.StatusInternalServerError)
		return
	}

	// 没有找到匹配的服务
	if len(updatedServiceNames) == 0 {
		errorMessage := fmt.Sprintf("No service found using image '%s'", deployRequest.ImageRepo)
		log.Println("[Warn] " + errorMessage)
		http.Error(responseWriter, errorMessage, http.StatusNotFound)
		return
	}

	// 重启服务
	if err := runDockerRestart(updatedServiceNames); err != nil {
		log.Printf("Docker execution error: %v", err)
		http.Error(responseWriter, "Docker restart failed", http.StatusInternalServerError)
		return
	}

	log.Printf("Successfully updated services: %v | Image: %s:%s", updatedServiceNames, deployRequest.ImageRepo, deployRequest.NewTag)

	// 返回成功响应
	responseWriter.Header().Set("Content-Type", "application/json")
	json.NewEncoder(responseWriter).Encode(map[string]interface{}{
		"message":          "Deploy success",
		"updated_services": updatedServiceNames,
		"new_tag":          deployRequest.NewTag,
	})
}

// 读取YAML查找匹配的镜像并更新
func updateImageInFile(targetImageRepository, newTag string) ([]string, error) {
	fileData, err := os.ReadFile(dockerComposeFilePath)
	if err != nil {
		return nil, err
	}

	var yamlRootMap map[string]interface{}
	if err := yaml.Unmarshal(fileData, &yamlRootMap); err != nil {
		return nil, err
	}

	servicesMap, ok := yamlRootMap["services"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("format error: 'services' key not found")
	}

	var updatedServiceNames []string
	newFullImageString := fmt.Sprintf("%s:%s", targetImageRepository, newTag)

	// 遍历所有服务
	for serviceName, serviceData := range servicesMap {
		serviceConfiguration, ok := serviceData.(map[string]interface{})
		if !ok {
			continue
		}

		currentImageString, ok := serviceConfiguration["image"].(string)
		if !ok {
			continue
		}

		// 解析镜像名
		currentRepository := getRepositoryFromImage(currentImageString)

		// 匹配成功
		if currentRepository == targetImageRepository {
			// 更新内存中的数据
			serviceConfiguration["image"] = newFullImageString
			// 记录被修改的服务名
			updatedServiceNames = append(updatedServiceNames, serviceName)
		}
	}

	if len(updatedServiceNames) > 0 {
		newFileData, err := yaml.Marshal(&yamlRootMap)
		if err != nil {
			return nil, err
		}

		if err := os.WriteFile(dockerComposeFilePath, newFileData, 0644); err != nil {
			return nil, err
		}
	}

	return updatedServiceNames, nil
}

func getRepositoryFromImage(fullImageString string) string {
	lastColonIndex := strings.LastIndex(fullImageString, ":")
	if lastColonIndex == -1 {
		return fullImageString
	}
	return fullImageString[:lastColonIndex]
}

// 重启服务
func runDockerRestart(serviceNames []string) error {
	dockerArguments := []string{"compose", "-f", dockerComposeFilePath, "up", "-d"}
	dockerArguments = append(dockerArguments, serviceNames...)

	log.Printf("Executing command: docker %v", strings.Join(dockerArguments, " "))

	dockerCommand := exec.Command("docker", dockerArguments...)
	dockerCommand.Stdout = os.Stdout
	dockerCommand.Stderr = os.Stderr
	return dockerCommand.Run()
}
