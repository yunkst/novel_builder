# 后端调试模式使用指南

## 快速开始

### 1. 启动调试模式容器

```bash
# 启动调试模式的Docker容器
docker-compose up -d --build
```

### 2. 在VSCode中连接调试器

1. 打开VSCode
2. 按 `F5` 或进入调试面板
3. 选择 "Docker: Attach to Backend" 配置
4. 点击绿色播放按钮开始调试

### 3. 验证调试功能

- 在后端代码中设置断点
- 访问API端点触发断点
- 检查变量和执行流程

## 配置说明

### 调试端口
- **应用端口**: 3800 (FastAPI)
- **调试端口**: 6678 (debugpy)

### 等待调试器连接

如果需要在应用启动时等待调试器连接，修改 `docker-compose.yml` 中的环境变量：

```yaml
environment:
  - DEBUG_WAIT=true  # 改为true
```

### 查看容器日志

```bash
docker-compose logs -f backend
```

### 停止调试模式

```bash
docker-compose down
```

## VSCode调试配置

调试配置文件位于 `.vscode/launch.json`：

```json
{
    "name": "Docker: Attach to Backend",
    "type": "python",
    "request": "attach",
    "connect": {
        "host": "localhost",
        "port": 5678
    },
    "pathMappings": [
        {
            "localRoot": "${workspaceFolder}/backend",
            "remoteRoot": "/app"
        }
    ],
    "justMyCode": false
}
```

## 文件说明

- `Dockerfile.debug`: 包含debugpy的调试版本Docker镜像
- `docker-compose.debug.yml`: 调试模式的Docker Compose配置
- `.vscode/launch.json`: VSCode调试配置

## 注意事项

1. 确保安装了Python扩展
2. 调试模式下代码热重载已启用
3. 文件修改会自动同步到容器中
4. 调试端口5678仅在调试模式下开放