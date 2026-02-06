package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"

	"gopkg.in/yaml.v3"
)

// 全局配置变量
var (
	serverPort          string
	authenticationToken string
	fileMutex           sync.Mutex                                    // 文件操作锁
	inputValidator      = regexp.MustCompile(`^[a-zA-Z0-9_\-\.\/]+$`) // 防止Shell注入正则
)

// 请求结构体
type DeployRequest struct {
	ImageRepo string `json:"image"`
	NewTag    string `json:"tag"`
}

// 统一标准响应结构
type StandardResponse struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// 成功时JSON返回
type SuccessData struct {
	NewTag      string   `json:"newTag"`
	UpdateImage []string `json:"updateImage"`
}

func main() {
	flag.StringVar(&serverPort, "port", "5000", "监听端口")
	flag.Parse()

	authenticationToken = os.Getenv("AUTH_TOKEN")
	if authenticationToken == "" {
		log.Fatal("Startup failed: Please set AUTH_TOKEN environment variable")
	}

	// 启动日志
	workingDirectory, _ := os.Getwd()
	log.Printf("FakeCD started | Port: %s | WorkDir: %s | Mode: Global Upgrade (up -d)", serverPort, workingDirectory)

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
			sendJSONResponse(responseWriter, http.StatusUnauthorized, "Unauthorized", nil)
			return
		}
		nextHandler(responseWriter, httpRequest)
	}
}

// 统一发送JSON响应
func sendJSONResponse(responseWriter http.ResponseWriter, statusCode int, message string, data interface{}) {
	responseWriter.Header().Set("Content-Type", "application/json")
	// HTTP状态码
	responseWriter.WriteHeader(statusCode)

	// 构造响应体
	response := StandardResponse{
		Code:    statusCode,
		Message: message,
		Data:    data,
	}

	if err := json.NewEncoder(responseWriter).Encode(response); err != nil {
		log.Printf("Error sending JSON response: %v", err)
	}
}

// 处理部署请求的主逻辑
func handleDeploy(responseWriter http.ResponseWriter, httpRequest *http.Request) {
	if httpRequest.Method != http.MethodPost {
		sendJSONResponse(responseWriter, http.StatusMethodNotAllowed, "Method Not Allowed", nil)
		return
	}

	var deployRequest DeployRequest
	if err := json.NewDecoder(httpRequest.Body).Decode(&deployRequest); err != nil {
		sendJSONResponse(responseWriter, http.StatusBadRequest, "JSON parse error", nil)
		return
	}

	// 检查输入字符是否合法
	if !inputValidator.MatchString(deployRequest.ImageRepo) || !inputValidator.MatchString(deployRequest.NewTag) {
		sendJSONResponse(responseWriter, http.StatusBadRequest, "Invalid input characters", nil)
		return
	}

	fileMutex.Lock()
	defer fileMutex.Unlock()

	// 扫描并处理当前目录下的所有子文件夹
	updatedProjects, err := scanAndProcessAllDirectories(deployRequest.ImageRepo, deployRequest.NewTag)
	if err != nil {
		log.Printf("Process error: %v", err)
		sendJSONResponse(responseWriter, http.StatusInternalServerError, fmt.Sprintf("Process Error: %v", err), nil)
		return
	}

	// 没有项目被更新
	if len(updatedProjects) == 0 {
		errorMessage := fmt.Sprintf("No service found using image '%s' in any subdirectory", deployRequest.ImageRepo)
		log.Println("[Warn] " + errorMessage)
		sendJSONResponse(responseWriter, http.StatusNotFound, errorMessage, nil)
		return
	}

	log.Printf("Successfully updated projects: %v | Image: %s:%s", updatedProjects, deployRequest.ImageRepo, deployRequest.NewTag)

	// 构造成功响应数据
	responseData := SuccessData{
		NewTag:      deployRequest.NewTag,
		UpdateImage: updatedProjects,
	}

	sendJSONResponse(responseWriter, http.StatusOK, "Deploy success", responseData)
}

// 扫描当前目录下的所有文件夹
func scanAndProcessAllDirectories(targetImageRepository, newTag string) ([]string, error) {
	var successfullyUpdatedProjects []string

	// 读取当前目录下的文件列表
	entries, err := os.ReadDir(".")
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if entry.IsDir() {
			directoryName := entry.Name()

			// 检查文件夹下是否有docker-compose
			composeFilePath := findComposeFileInDir(directoryName)
			if composeFilePath == "" {
				continue
			}

			// 更新镜像
			updatedServices, err := updateImageInFile(composeFilePath, targetImageRepository, newTag)
			if err != nil {
				log.Printf("Error processing %s: %v", composeFilePath, err)
				continue
			}

			if len(updatedServices) > 0 {
				log.Printf("Found match in project: %s | Services: %v", directoryName, updatedServices)

				if err := runDockerUp(directoryName, composeFilePath); err != nil {
					log.Printf("Docker restart failed for %s: %v", directoryName, err)
					return nil, err
				}

				successfullyUpdatedProjects = append(successfullyUpdatedProjects, directoryName)
			}
		}
	}

	return successfullyUpdatedProjects, nil
}

// 在指定目录下寻找docker-compose文件
func findComposeFileInDir(dir string) string {
	pathYaml := filepath.Join(dir, "docker-compose.yaml")
	if _, err := os.Stat(pathYaml); err == nil {
		return pathYaml
	}
	pathYml := filepath.Join(dir, "docker-compose.yml")
	if _, err := os.Stat(pathYml); err == nil {
		return pathYml
	}
	return ""
}

// 读取指定YAML文件查找匹配的镜像并更新
func updateImageInFile(filePath, targetImageRepository, newTag string) ([]string, error) {
	fileData, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	var yamlRootMap map[string]interface{}
	if err := yaml.Unmarshal(fileData, &yamlRootMap); err != nil {
		return nil, err
	}

	servicesMap, ok := yamlRootMap["services"].(map[string]interface{})
	if !ok {
		return nil, nil
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

		currentRepository := getRepositoryFromImage(currentImageString)

		// 匹配成功
		if currentRepository == targetImageRepository {
			// 更新配置
			serviceConfiguration["image"] = newFullImageString
			updatedServiceNames = append(updatedServiceNames, serviceName)
		}
	}

	if len(updatedServiceNames) > 0 {
		newFileData, err := yaml.Marshal(&yamlRootMap)
		if err != nil {
			return nil, err
		}
		if err := os.WriteFile(filePath, newFileData, 0644); err != nil {
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

// 更新项目
func runDockerUp(workingDirectory string, composeFilePath string) error {
	fileName := filepath.Base(composeFilePath)

	dockerArguments := []string{"compose", "-f", fileName, "up", "-d"}

	log.Printf("Executing command in [%s]: docker %v", workingDirectory, strings.Join(dockerArguments, " "))

	dockerCommand := exec.Command("docker", dockerArguments...)

	// 设置工作目录为子项目文件夹
	dockerCommand.Dir = workingDirectory

	dockerCommand.Stdout = os.Stdout
	dockerCommand.Stderr = os.Stderr
	return dockerCommand.Run()
}
