# 小说缓存后端测试指南

本文档说明如何测试小说缓存后端的各种功能。

## 目录

1. [环境准备](#环境准备)
2. [快速测试](#快速测试)
3. [完整测试](#完整测试)
4. [手动测试](#手动测试)
5. [数据库管理](#数据库管理)
6. [故障排除](#故障排除)

## 环境准备

### 1. 确保后端服务运行

```bash
# 在 backend 目录下
docker-compose up -d
```

### 2. 检查服务状态

```bash
# 检查容器是否运行
docker ps | grep novel-backend

# 检查健康状态
curl http://localhost:3800/health
```

### 3. 设置环境变量

确保 `NOVEL_API_TOKEN` 环境变量已设置：

```bash
# 在宿主机上
export NOVEL_API_TOKEN="your-api-token-here"

# 或者在 docker-compose.yml 中设置
```

## 快速测试

快速测试可以验证基本的API功能：

### 方法1：使用测试脚本（推荐）

```bash
# 在 backend 目录下
# 方法A：在宿主机运行（需要安装requests和websockets库）
pip install requests websockets
python test_backend.py --quick

# 方法B：在Docker容器内运行（无需额外安装）
docker exec novel-backend-dev python /app/test_backend.py --quick
```

### 方法2：手动快速测试

```bash
# 健康检查
curl http://localhost:3800/health

# 搜索功能（替换 YOUR_TOKEN）
curl -H "X-API-TOKEN: YOUR_TOKEN" "http://localhost:3800/search?keyword=斗罗"

# 获取任务列表
curl -H "X-API-TOKEN: YOUR_TOKEN" "http://localhost:3800/api/cache/tasks"
```

## 完整测试

完整测试会测试整个缓存流程，包括创建任务、监听进度、下载内容等：

### 使用测试脚本

```bash
# 在 backend 目录下

# 方法A：在宿主机运行
python test_backend.py

# 方法B：在Docker容器内运行
docker exec novel-backend-dev python /app/test_backend.py
```

完整测试流程包括：
1. ✅ 健康检查
2. ✅ 搜索小说
3. ✅ 获取章节列表
4. ✅ 创建缓存任务
5. ✅ 查询任务状态
6. ✅ 获取任务列表
7. ✅ WebSocket进度监听
8. ✅ 下载缓存内容（如果任务完成）

## 手动测试

### 1. 搜索小说

```bash
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/search?keyword=斗罗"
```

### 2. 获取章节列表

从搜索结果中获取小说URL，然后：

```bash
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/chapters?url=NOVEL_URL"
```

### 3. 创建缓存任务

```bash
curl -X POST \
     -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/api/cache/create?novel_url=NOVEL_URL"
```

### 4. 查询任务状态

```bash
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/api/cache/status/TASK_ID"
```

### 5. 获取任务列表

```bash
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/api/cache/tasks"
```

### 6. 下载缓存内容

```bash
# JSON格式
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/api/cache/download/TASK_ID?format=json"

# TXT格式
curl -H "X-API-TOKEN: YOUR_TOKEN" \
     "http://localhost:3800/api/cache/download/TASK_ID?format=txt" \
     -o novel.txt
```

### 7. WebSocket进度监听

可以使用WebSocket客户端工具连接：
```
ws://localhost:3800/ws/cache/TASK_ID
```

## 数据库管理

### 使用Alembic管理数据库迁移

项目使用Alembic来管理数据库迁移，这是推荐的数据库管理方式：

```bash
# 查看当前迁移状态
docker exec novel-backend-dev alembic current

# 运行所有迁移
docker exec novel-backend-dev alembic upgrade head

# 创建新的迁移
docker exec novel-backend-dev alembic revision --autogenerate -m "描述你的更改"

# 回滚到上一个版本
docker exec novel-backend-dev alembic downgrade -1

# 查看迁移历史
docker exec novel-backend-dev alembic history
```

### 手动数据库初始化（不推荐）

如果需要手动重新初始化数据库：

```bash
# 删除数据库文件
docker exec novel-backend-dev rm -f /app/novel_cache.db

# 重新运行所有迁移
docker exec novel-backend-dev alembic upgrade head
```

## 测试脚本使用说明

### 脚本参数

```bash
# 快速测试（不包含异步WebSocket测试）
python test_backend.py --quick

# 完整测试（包含所有功能测试）
python test_backend.py
```

### 自定义测试

可以修改 `test_backend.py` 中的测试参数：

```python
# 修改搜索关键词
search_results = self.test_search("你的搜索关键词")

# 修改小说URL
novel_url = "你的小说URL"

# 修改任务ID
task_id = 你的任务ID
```

## 故障排除

### 常见问题

1. **连接被拒绝**
   ```
   解决方案：检查后端服务是否启动
   docker-compose up -d
   ```

2. **Token认证失败**
   ```
   解决方案：检查X-API-TOKEN头是否正确设置
   确保NOVEL_API_TOKEN环境变量与配置一致
   默认Token: your-api-token-here
   ```

3. **数据库表不存在错误**
   ```
   解决方案：运行数据库迁移
   docker exec novel-backend-dev alembic upgrade head
   ```

4. **搜索结果为空**
   ```
   解决方案：检查爬虫服务是否正常
   确保网络连接正常
   ```

5. **WebSocket连接失败**
   ```
   解决方案：检查防火墙设置
   确保端口8000（容器内）或3800（宿主机）可访问
   ```

6. **Alembic迁移失败**
   ```
   解决方案：检查迁移文件是否存在
   确保alembic/versions目录存在且有正确权限
   docker exec novel-backend-dev ls -la /app/alembic/versions/
   ```

### 调试方法

1. **查看容器日志**
   ```bash
   docker logs novel-backend-dev -f
   ```

2. **进入容器调试**
   ```bash
   docker exec -it novel-backend-dev /bin/bash
   ```

3. **检查数据库**
   ```bash
   # 进入容器后
   sqlite3 /app/novel_cache.db
   .tables
   SELECT * FROM novel_cache_tasks;
   ```

4. **测试网络连接**
   ```bash
   # 测试小说网站是否可访问
   docker exec novel-backend-dev curl -I "https://www.23txt.com"
   ```

### 性能测试

如果要测试大量数据的缓存性能：

1. **选择章节数多的小说**
2. **监控缓存任务的内存和CPU使用**
3. **观察WebSocket推送的实时性**
4. **测试并发缓存任务**

## API参考

详细的API文档可以在以下地址查看：
- Swagger UI: http://localhost:3800/docs
- ReDoc: http://localhost:3800/redoc

## 注意事项

1. ⚠️ 测试时请使用合适的API Token
2. ⚠️ 大量缓存测试可能消耗较多资源
3. ⚠️ 频繁请求可能被目标网站限制
4. ⚠️ 请遵守目标网站的使用条款
5. ⚠️ 测试完成后及时清理不需要的缓存数据

## 联系支持

如果遇到无法解决的问题，请：
1. 检查容器日志获取详细错误信息
2. 确认环境配置是否正确
3. 提供具体的错误信息和复现步骤