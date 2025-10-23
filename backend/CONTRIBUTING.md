# 贡献指南

## 📋 开发环境设置

### 1. 前置条件
- Python 3.11+
- Git
- Docker & Docker Compose (可选，用于容器化开发)

### 2. 本地开发设置

#### 方法一：直接在本地环境开发

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd novel-builder/backend
   ```

2. **创建虚拟环境**
   ```bash
   python -m venv venv
   source venv/bin/activate  # Windows: venv\Scripts\activate
   ```

3. **安装依赖**
   ```bash
   pip install -e ".[dev]"
   ```

4. **配置环境变量**
   ```bash
   cp .env.example .env
   # 编辑 .env 文件，设置必要的环境变量
   ```

5. **安装pre-commit钩子**
   ```bash
   pre-commit install
   ```

6. **启动开发服务器**
   ```bash
   make run
   # 或者
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

#### 方法二：使用Docker开发

1. **配置环境变量**
   ```bash
   cp .env.example .env
   # 编辑 .env 文件
   ```

2. **启动开发环境**
   ```bash
   docker-compose up --build
   ```

3. **查看日志**
   ```bash
   docker-compose logs -f novel-backend
   ```

## 🔧 开发工作流

### 代码质量检查

运行所有代码质量检查：
```bash
make check-all
```

或者分别运行：
```bash
# 代码格式化
make format

# 代码检查
make lint

# 类型检查
make type-check
```

### 测试

运行所有测试：
```bash
make test
```

运行测试并生成覆盖率报告：
```bash
make test-cov
```

### Docker中的测试

运行完整的环境测试：
```bash
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

## 📝 代码规范

### Python代码风格

项目使用以下工具确保代码质量：

1. **Ruff** - 快速的Python linter和formatter
2. **MyPy** - 静态类型检查
3. **PyLint** - 深度代码质量检查
4. **Black** - 代码格式化（备选）
5. **isort** - 导入排序

### 代码检查配置

所有配置都在以下文件中：
- `pyproject.toml` - 主要配置文件
- `.ruff.toml` - Ruff专用配置
- `.pre-commit-config.yaml` - Git钩子配置

### 提交前检查

在提交代码前，确保运行：
```bash
pre-commit run --all-files
```

这将自动：
- 格式化代码
- 检查语法错误
- 运行类型检查
- 运行静态分析
- 运行基本测试

## 🧪 编写测试

### 测试结构

```
tests/
├── unit/           # 单元测试
├── integration/    # 集成测试
└── conftest.py     # 测试配置
```

### 测试示例

#### 单元测试
```python
import pytest
from unittest.mock import AsyncMock

class TestMyService:
    def test_service_method(self):
        # 测试逻辑
        assert True

    async def test_async_service_method(self):
        # 异步测试逻辑
        assert True
```

#### 集成测试
```python
import pytest
from httpx import AsyncClient

@pytest.mark.integration
class TestAPIEndpoints:
    async def test_search_endpoint(self, async_client):
        response = await async_client.get("/search?keyword=test")
        assert response.status_code == 200
```

### 运行特定测试

```bash
# 运行特定测试文件
pytest tests/unit/test_main.py

# 运行特定测试类
pytest tests/unit/test_main.py::TestHealthCheck

# 运行特定测试方法
pytest tests/unit/test_main.py::TestHealthCheck::test_health_check

# 按标记运行
pytest -m unit
pytest -m integration
```

## 🐛 调试

### 本地调试

1. **使用VS Code调试**
   - 安装Python扩展
   - 创建`.vscode/launch.json`配置文件

2. **使用print调试**
   ```python
   import logging
   logger = logging.getLogger(__name__)
   logger.info("Debug info")
   ```

### Docker调试

```bash
# 进入容器
docker-compose exec novel-backend bash

# 查看实时日志
docker-compose logs -f novel-backend
```

## 📚 添加新功能

### 添加新的爬虫

1. **创建爬虫类**
   ```python
   # app/services/crawlers/new_site_crawler.py
   from ..base_crawler import BaseCrawler

   class NewSiteCrawler(BaseCrawler):
       name = "new_site"

       async def search(self, keyword: str):
           # 实现搜索逻辑
           pass
   ```

2. **注册爬虫**
   在`crawler_factory.py`中注册新爬虫

3. **添加测试**
   ```python
   # tests/unit/test_new_site_crawler.py
   class TestNewSiteCrawler:
       async def test_search(self):
           # 测试搜索功能
           pass
   ```

4. **更新环境变量**
   ```bash
   # .env
   NOVEL_ENABLED_SITES=alice_sw,shukuge,new_site
   ```

### 添加新的API端点

1. **定义Pydantic模型** (schemas.py)
2. **实现路由处理函数** (main.py)
3. **添加认证装饰器** (如果需要)
4. **编写测试**
5. **更新API文档**

## 🔍 性能优化

### 代码优化

1. **异步操作** - 使用async/await
2. **缓存** - 实现适当的缓存策略
3. **连接池** - 使用HTTP连接池
4. **批处理** - 减少网络请求次数

### 监控

```python
# 添加日志记录
import logging
logger = logging.getLogger(__name__)

async def my_function():
    logger.info("Starting operation")
    try:
        # 业务逻辑
        logger.info("Operation completed successfully")
    except Exception as e:
        logger.error(f"Operation failed: {e}")
        raise
```

## ❓ 常见问题

### 依赖安装问题

```bash
# 清理pip缓存
pip cache purge

# 重新安装
pip install -e ".[dev]" --force-reinstall
```

### 测试失败

```bash
# 检查环境变量
echo $NOVEL_API_TOKEN

# 重新安装测试依赖
pip install pytest pytest-asyncio pytest-cov
```

### Docker问题

```bash
# 重新构建镜像
docker-compose build --no-cache

# 清理Docker缓存
docker system prune -a
```

## 📞 获取帮助

1. **查看项目文档** - README.md
2. **查看代码注释** - 内联文档
3. **查看测试用例** - 了解功能用法
4. **搜索现有issue** - 可能已有解决方案
5. **创建新issue** - 提供详细信息和复现步骤