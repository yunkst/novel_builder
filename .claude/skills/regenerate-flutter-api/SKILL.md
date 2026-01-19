---
name: regenerate-flutter-api
description: 自动检测backend API变更并重新生成Flutter API客户端代码。当修改了backend的API接口、schemas或models后，使用此skill自动更新Flutter端的API客户端代码以保持同步。支持检测API路由变更、数据模型变更，并自动调用openapi-generator-cli生成新的Dart客户端代码。
---

# Regenerate Flutter API Skill

此skill用于在backend API发生变更时，自动重新生成Flutter端的API客户端代码。

## Skill用途

当以下情况发生时，使用此skill保持Flutter API客户端代码与backend同步：

1. **新增或修改API端点**: 在 `backend/app/main.py` 中添加/修改路由
2. **变更数据模型**: 修改 `backend/app/schemas.py` 中的Pydantic模型
3. **更新业务逻辑**: 修改 `backend/app/models/` 或 `backend/app/services/` 中的代码

## 何时使用

在以下场景中应使用此skill：

- 用户说"生成API客户端"、"更新Flutter API"、"重新生成API代码"
- 修改了backend API后，用户说"同步到Flutter"
- Claude检测到backend API文件被修改，建议更新客户端代码

## 执行流程

### 步骤1: 确认后端服务运行

确保后端服务运行在 `http://localhost:3800`：

```bash
# 检查后端服务
curl http://localhost:3800/health

# 或者检查OpenAPI规范
curl http://localhost:3800/openapi.json
```

### 步骤2: 运行生成脚本

```bash
cd novel_app
dart run tool/generate_api.dart
```

该脚本会：
1. 检查 `openapi-generator-cli` 是否安装
2. 验证后端服务是否运行
3. 删除旧的生成代码
4. 调用 `openapi-generator-cli` 生成新代码
5. 运行 `flutter pub get` 安装依赖
6. 运行 `build_runner` 生成 `.g.dart` 文件

### 步骤3: 验证生成结果

检查生成的代码：

```bash
# 查看生成的文件
ls -la novel_app/generated/api/lib/src/

# 检查模型类
ls novel_app/generated/api/lib/src/model/
```

## 项目结构

### Backend API配置

- **OpenAPI规范**: `http://localhost:3800/openapi.json`
- **API定义**: `backend/app/main.py`
- **数据模型**: `backend/app/schemas.py`

### Flutter生成配置

- **生成工具**: `novel_app/tool/generate_api.dart`
- **配置文件**: `novel_app/openapi-config.yaml`
- **输出目录**: `novel_app/generated/api/`
- **生成器**: `dart-dio` (基于Dio HTTP客户端)

### 生成配置详解

`openapi-config.yaml`:
```yaml
generatorName: dart-dio
inputSpec: http://localhost:3800/openapi.json
outputDir: generated/api
additionalProperties:
  pubName: novel_api
  useEnumExtension: true
  enumUnknownDefaultCase: true
  nullableFields: true
```

## 使用生成的API客户端

### 初始化API服务

```dart
import 'package:novel_api/api.dart';

// 创建API实例
final api = DefaultApi();

// 配置base URL
api.dio.options.baseUrl = 'http://localhost:3800';

// 添加认证
api.dio.options.headers['X-API-TOKEN'] = 'your_token';
```

### 调用API方法

```dart
// 调用搜索API
final results = await api.searchNovels(keyword, token);

// 调用章节API
final chapters = await api.getChapters(url, token);

// 调用内容API
final content = await api.getChapterContent(url, forceRefresh, token);
```

## 常见问题

### Q: openapi-generator-cli未安装怎么办？
A: 运行 `npm install -g @openapitools/openapi-generator-cli`

### Q: 生成后代码报错？
A: 运行 `cd novel_app && flutter pub get` 安装依赖

### Q: 后端服务未启动？
A: 先启动后端: `cd backend && uvicorn app.main:app --host 0.0.0.0 --port 3800`

### Q: 生成的代码不符合Flutter风格？
A: 可以使用 `ApiServiceWrapper` 封装生成的API，提供更友好的接口

## 版本控制建议

生成的代码通常不应提交到版本控制：

```gitignore
# .gitignore
novel_app/generated/
```

团队成员应按照以下流程工作：
1. 拉取最新代码
2. 启动后端服务
3. 运行 `dart run tool/generate_api.dart`
4. 开始开发

## 相关文件

- `tool/generate_api.dart` - API生成主脚本
- `openapi-config.yaml` - OpenAPI生成器配置
- `lib/services/api_service_wrapper.dart` - API服务包装器
- `lib/services/backend_api_service.dart` - 后端API服务实现
