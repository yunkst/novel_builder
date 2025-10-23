# 开发指南

## 🚀 快速开始

### 一键启动开发环境

```bash
# 克隆项目
git clone <repository-url>
cd novel-builder/backend

# 安装依赖并启动
make install-dev
make run
```

访问 http://localhost:8000 查看API文档

## 📁 项目结构详解

```
backend/
├── app/                          # 应用代码
│   ├── main.py                   # FastAPI应用入口
│   ├── config.py                 # 配置管理
│   ├── schemas.py                # Pydantic数据模型
│   ├── models.py                 # SQLAlchemy数据模型
│   ├── database.py               # 数据库连接
│   ├── deps/                     # 依赖注入
│   │   └── auth.py               # 认证依赖
│   └── services/                 # 业务逻辑服务
│       ├── base_crawler.py       # 爬虫基类
│       ├── crawler_factory.py    # 爬虫工厂
│       ├── alice_sw_crawler.py   # 爱丽丝小说网爬虫
│       └── ...
├── tests/                        # 测试代码
│   ├── unit/                     # 单元测试
│   ├── integration/              # 集成测试
│   └── conftest.py               # 测试配置
├── pyproject.toml                # 项目配置和依赖
├── Dockerfile                    # 生产环境镜像
├── Dockerfile.test               # 测试环境镜像
├── docker-compose.yml            # 开发环境
├── docker-compose.test.yml       # 测试环境
├── Makefile                      # 开发命令
├── .env.example                  # 环境变量模板
├── .pre-commit-config.yaml       # Git钩子配置
└── .ruff.toml                    # Ruff配置
```

## ⚙️ 配置说明

### 环境变量

| 变量名 | 描述 | 默认值 | 必需 |
|--------|------|--------|------|
| `NOVEL_API_TOKEN` | API认证令牌 | - | ✅ |
| `NOVEL_ENABLED_SITES` | 启用的爬虫网站 | - | ✅ |
| `SECRET_KEY` | JWT密钥 | - | ✅ |
| `DEBUG` | 调试模式 | false | ❌ |
| `API_HOST` | API监听地址 | 0.0.0.0 | ❌ |
| `API_PORT` | API监听端口 | 8000 | ❌ |

### 爬虫配置

支持的网站：
- `alice_sw` - 爱丽丝小说网
- `shukuge` - 书阁网

示例配置：
```bash
NOVEL_ENABLED_SITES=alice_sw,shukuge
```

## 🔧 开发工具

### Make命令

```bash
# 安装
make install          # 安装生产依赖
make install-dev      # 安装开发依赖
make pre-commit       # 安装Git钩子

# 开发
make run              # 启动开发服务器
make format           # 格式化代码
make lint             # 代码检查
make type-check       # 类型检查
make test             # 运行测试
make test-cov         # 运行测试(带覆盖率)
make check-all        # 运行所有检查

# Docker
make docker-build     # 构建Docker镜像
make docker-run       # 运行Docker容器
make docker-test      # Docker中运行测试

# 维护
make clean            # 清理缓存文件
```

### IDE配置

#### VS Code

推荐安装扩展：
- Python
- Pylance
- Python Docstring Generator
- GitLens

创建`.vscode/settings.json`：
```json
{
    "python.defaultInterpreterPath": "./venv/bin/python",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "python.testing.pytestEnabled": true,
    "python.testing.pytestArgs": ["tests/"],
    "python.testing.unittestEnabled": false,
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true
    }
}
```

#### PyCharm

1. 设置项目解释器为虚拟环境
2. 启用代码检查：Settings → Editor → Inspections → Python
3. 配置测试运行器：Settings → Tools → Python Integrated Tools → Testing → pytest

## 🧪 测试指南

### 测试类型

1. **单元测试** - 测试单个函数/类
2. **集成测试** - 测试组件间交互
3. **端到端测试** - 测试完整流程

### 测试标记

使用pytest标记分类测试：
```python
@pytest.mark.unit
def test_unit_function():
    pass

@pytest.mark.integration
async def test_integration():
    pass

@pytest.mark.slow
def test_slow_operation():
    pass
```

### 测试数据

使用fixture提供测试数据：
```python
@pytest.fixture
def sample_novel():
    return {
        "title": "测试小说",
        "author": "测试作者",
        "url": "https://example.com/novel/1"
    }

def test_with_sample(sample_novel):
    assert sample_novel["title"] == "测试小说"
```

### Mock使用

```python
from unittest.mock import AsyncMock, patch

@patch('app.services.crawler_factory.get_enabled_crawlers')
async def test_with_mock(mock_get_crawlers):
    mock_crawler = AsyncMock()
    mock_crawler.search.return_value = []
    mock_get_crawlers.return_value = {"test": mock_crawler}

    # 测试逻辑
```

## 🔍 代码调试

### 日志配置

```python
import logging

# 在config.py中配置
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# 在代码中使用
logger = logging.getLogger(__name__)
logger.info("这是一条信息")
logger.error("这是一条错误")
```

### 调试技巧

1. **使用断点调试**
   ```python
   import pdb; pdb.set_trace()  # Python调试器
   # 或者使用更现代的debugpy
   ```

2. **使用IPython调试**
   ```python
   import IPython; IPython.embed()
   ```

3. **使用print调试**
   ```python
   print(f"调试信息: {variable}")
   ```

### 性能分析

```python
import cProfile
import pstats

def profile_function():
    pr = cProfile.Profile()
    pr.enable()
    # 要分析的代码
    result = your_function()
    pr.disable()

    stats = pstats.Stats(pr)
    stats.sort_stats('cumulative')
    stats.print_stats(10)
    return result
```

## 📊 性能优化

### 异步编程最佳实践

1. **使用async/await**
   ```python
   async def fetch_data():
       async with aiohttp.ClientSession() as session:
           async with session.get(url) as response:
               return await response.json()
   ```

2. **并发执行**
   ```python
   import asyncio

   async def fetch_multiple():
       tasks = [fetch_data(url) for url in urls]
       results = await asyncio.gather(*tasks)
       return results
   ```

3. **连接池**
   ```python
   import aiohttp

   connector = aiohttp.TCPConnector(limit=100, limit_per_host=10)
   async with aiohttp.ClientSession(connector=connector) as session:
       # 使用session进行请求
   ```

### 缓存策略

```python
from functools import lru_cache
import asyncio

# 内存缓存
@lru_cache(maxsize=128)
def expensive_function(param):
    # 耗时操作
    return result

# 异步缓存
from cachetools import TTLCache

cache = TTLCache(maxsize=1000, ttl=300)  # 5分钟过期

async def cached_operation(key):
    if key in cache:
        return cache[key]

    result = await expensive_async_operation()
    cache[key] = result
    return result
```

## 🔐 安全最佳实践

### 认证和授权

1. **使用强密钥**
   ```python
   import secrets

   # 生成安全密钥
   SECRET_KEY = secrets.token_urlsafe(32)
   ```

2. **验证输入**
   ```python
   from pydantic import BaseModel, validator

   class SearchRequest(BaseModel):
       keyword: str

       @validator('keyword')
       def validate_keyword(cls, v):
           if len(v) < 1 or len(v) > 100:
               raise ValueError('关键词长度必须在1-100之间')
           return v.strip()
   ```

3. **错误处理**
   ```python
   try:
       # 业务逻辑
       pass
   except SpecificException as e:
       logger.error(f"特定错误: {e}")
       raise HTTPException(status_code=400, detail="请求参数错误")
   except Exception as e:
       logger.error(f"未知错误: {e}")
       raise HTTPException(status_code=500, detail="内部服务器错误")
   ```

## 📝 API设计指南

### RESTful API设计

1. **使用HTTP方法正确**
   - GET: 获取资源
   - POST: 创建资源
   - PUT/PATCH: 更新资源
   - DELETE: 删除资源

2. **正确的状态码**
   - 200: 成功
   - 201: 创建成功
   - 400: 客户端错误
   - 401: 未认证
   - 404: 资源不存在
   - 500: 服务器错误

3. **统一的响应格式**
   ```python
   # 成功响应
   {
       "data": {...},
       "message": "操作成功",
       "status": "success"
   }

   # 错误响应
   {
       "error": "错误详情",
       "status": "error",
       "code": "ERROR_CODE"
   }
   ```

### API版本控制

```python
# 在URL中包含版本
@app.get("/v1/search")
async def search_v1():
    pass

@app.get("/v2/search")
async def search_v2():
    pass
```

## 🚀 部署指南

### 本地部署

```bash
# 构建镜像
make docker-build

# 运行容器
make docker-run

# 或者使用docker-compose
docker-compose up -d
```

### 生产环境配置

1. **环境变量**
   ```bash
   # 生产环境配置
   DEBUG=false
   LOG_LEVEL=WARNING
   NOVEL_API_TOKEN=生产令牌
   SECRET_KEY=生产密钥
   ```

2. **反向代理**
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://localhost:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

3. **进程管理**
   ```bash
   # 使用systemd管理服务
   sudo systemctl start novel-backend
   sudo systemctl enable novel-backend
   ```

## 🛠️ 故障排除

### 常见问题

1. **依赖冲突**
   ```bash
   # 重新创建虚拟环境
   rm -rf venv
   python -m venv venv
   source venv/bin/activate
   pip install -e ".[dev]"
   ```

2. **测试失败**
   ```bash
   # 清理测试缓存
   pytest --cache-clear

   # 检查环境变量
   env | grep NOVEL_
   ```

3. **Docker问题**
   ```bash
   # 重新构建
   docker-compose build --no-cache

   # 查看日志
   docker-compose logs novel-backend
   ```

### 性能问题

1. **内存使用过高**
   - 检查缓存策略
   - 使用内存分析工具

2. **响应慢**
   - 检查网络请求
   - 优化数据库查询
   - 使用连接池

3. **并发问题**
   - 检查异步操作
   - 优化锁使用

## 📚 学习资源

- [FastAPI官方文档](https://fastapi.tiangolo.com/)
- [Python异步编程](https://docs.python.org/3/library/asyncio.html)
- [Pytest测试框架](https://docs.pytest.org/)
- [Python代码质量工具](https://github.com/PyCQA)