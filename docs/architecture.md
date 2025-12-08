# Novel Builder Fullstack Architecture Document

## Introduction

This document outlines the complete fullstack architecture for Novel Builder, including backend systems, frontend implementation, and their integration. It serves as the single source of truth for AI-driven development, ensuring consistency across the entire technology stack.

This unified approach combines what would traditionally be separate backend and frontend architecture documents, streamlining the development process for modern fullstack applications where these concerns are increasingly intertwined.

### Starter Template or Existing Project

**Project Type:** Existing Fullstack Application

**Current Stack Analysis:**
- **Frontend**: Flutter-based mobile application with SQLite local storage
- **Backend**: FastAPI with PostgreSQL database, featuring multi-site novel crawling capabilities
- **Infrastructure**: Docker Compose for containerized deployment
- **Architecture**: Microservices pattern with separation between mobile app and backend services

**Key Architectural Decisions Already Made:**
- Mobile-first approach with Flutter
- RESTful API design with FastAPI
- Microservices architecture for scalability
- Container-based deployment strategy
- Multi-site content aggregation system

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|---------|
| 2025-11-14 | v2.0 | Initial fullstack architecture documentation | Winston (Architect) |

## High Level Architecture

### Technical Summary

Novel Builder uses a microservices architecture with a mobile-first design philosophy. The Flutter mobile app provides cross-platform novel reading experience, while the FastAPI backend handles content aggregation through multi-site crawlers, user management, and API services. PostgreSQL serves as the primary data store, with Docker Compose enabling simple containerized deployment. This architecture prioritizes development efficiency and maintainability over performance optimization.

### Platform and Infrastructure Choice

**Platform:** Self-hosted Docker deployment
**Key Services:** Docker Compose, PostgreSQL, FastAPI
**Deployment Host and Regions:** Cloud server or local server, single-region deployment

### Repository Structure

**Structure:** Monorepo
**Monorepo Tool:** Simple folder separation without complex tooling
**Package Organization:** Frontend and backend code in same repository for easier management

```
novel_builder/
├── novel_app/           # Flutter移动应用
├── backend/             # FastAPI后端服务
├── docker-compose.yml   # 容器编排配置
├── .env.example        # 环境变量模板
└── docs/               # 项目文档
```

### High Level Architecture Diagram

```mermaid
graph TD
    A["用户设备"] --> B["Flutter移动应用"]
    B --> C["SQLite本地缓存"]
    B --> D["FastAPI后端服务"]
    D --> E["PostgreSQL数据库"]
    D --> F["多站点爬虫系统"]
    F --> G["AliceSW爬虫"]
    F --> H["书库爬虫"]
    F --> I["小说网爬虫"]
    F --> J["我的书城爬虫"]
    F --> K["爱尚小说爬虫"]
    D --> L["AI增强功能"]
    L --> M["Dify工作流集成"]

    subgraph "Docker容器环境"
        D
        E
        F
    end
```

### Architectural Patterns

- **Mobile-First Architecture**: Flutter cross-platform mobile app as primary user interface - _Rationale:_ Single codebase for iOS/Android reduces development and maintenance costs
- **Service Layer Pattern**: Business logic separated from data access and presentation layers - _Rationale:_ Improves testability and maintainability of backend services
- **RESTful API Design**: Standard HTTP interfaces with OpenAPI documentation - _Rationale:_ Enables easy debugging, testing, and third-party integration
- **Local-First Data Strategy**: SQLite caching with backend synchronization - _Rationale:_ Provides offline reading experience and reduces server load
- **Plugin-Based Crawlers**: Modular crawler architecture for easy site addition - _Rationale:_ Allows quick adaptation to new novel sites without core system changes
- **Container-First Deployment**: Docker Compose for consistent development and production environments - _Rationale:_ Simplifies deployment and eliminates environment-specific issues

## Tech Stack

### Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
|----------|------------|---------|---------|-----------|
| **Frontend Language** | Dart | 3.0+ | Flutter应用开发语言 | 类型安全，现代语言特性，与Flutter完美集成 |
| **Frontend Framework** | Flutter | 3.0+ | 跨平台移动应用框架 | 单一代码库支持iOS/Android，丰富的UI组件 |
| **UI Component Library** | Material 3 | Latest | Google Material Design | 现代化设计语言，内置Flutter支持 |
| **State Management** | Provider | 6.0+ | 简单状态管理 | 轻量级，学习成本低，适合中小型应用 |
| **Backend Language** | Python | 3.11+ | 后端服务开发语言 | 开发效率高，生态丰富，易于维护 |
| **Backend Framework** | FastAPI | 0.104+ | Web框架和API服务 | 自动API文档生成，类型提示支持，开发体验好 |
| **API Style** | REST | OpenAPI 3.0 | API设计规范 | 标准化，工具支持丰富，易于调试 |
| **Database** | PostgreSQL | 15+ | 主数据存储 | 成熟稳定，数据一致性强，JSON支持 |
| **Cache** | Redis | 7.0+ | 缓存和会话存储 | 简单可靠的内存数据库，支持多种数据结构 |
| **File Storage** | Local Filesystem | - | 小说封面和内容存储 | 简单直接，无需第三方依赖 |
| **Authentication** | JWT | PyJWT 2.8+ | 简单令牌认证 | 无状态，易于实现，跨平台支持 |
| **Frontend Testing** | Flutter Test | Built-in | 单元和组件测试 | Flutter内置测试框架，无需额外配置 |
| **Backend Testing** | Pytest | 7.4+ | 单元和集成测试 | Python标准测试框架，插件丰富 |
| **E2E Testing** | Integration Tests | Custom | API集成测试 | 简单的API调用测试，无需复杂E2E工具 |
| **Build Tool** | Docker Compose | 2.20+ | 容器编排构建 | 一键启动所有服务，环境一致性 |
| **Bundler** | Pub (Flutter) | Built-in | 前端包管理 | Flutter内置包管理器 |
| **IaC Tool** | Docker Compose | 2.20+ | 基础设施即代码 | 简单的容器编排，无需复杂IaC工具 |
| **CI/CD** | GitHub Actions | Latest | 自动化构建部署 | 免费且功能强大，与GitHub集成 |
| **Monitoring** | Basic Logging | Python Logging | 简单日志监控 | 内置日志模块，易于使用 |
| **Logging** | Python Logging + File | Built-in | 应用日志记录 | 文件日志，简单可靠，便于调试 |
| **CSS Framework** | Material Theme | Built-in | Flutter样式系统 | 内置主题系统，无需CSS |

## Data Models

### Novel

**Purpose:** 小说元数据管理，是系统的核心业务实体

**Key Attributes:**
- id: string - UUID，小说唯一标识符
- title: string - 小说标题，用于搜索和显示
- author: string - 作者姓名，支持作者搜索
- description: string - 小说简介，展示在搜索结果中
- cover_url: string - 封面图片地址，增强用户体验
- source_site: string - 来源站点标识，追踪内容来源
- source_url: string - 原站点链接，便于溯源
- status: string - 更新状态（连载中/已完结），帮助用户选择
- total_chapters: integer - 总章节数，让用户了解内容规模
- created_at: datetime - 创建时间，用于排序和管理
- updated_at: datetime - 更新时间，用于同步检测

#### TypeScript Interface
```typescript
interface Novel {
  id: string;
  title: string;
  author: string;
  description: string;
  cover_url?: string;
  source_site: string;
  source_url: string;
  status: 'ongoing' | 'completed';
  total_chapters: number;
  created_at: string;
  updated_at: string;
}
```

#### Relationships
- 一对多：Novel ↔ Chapter (一部小说包含多个章节)
- 一对多：Novel ↔ UserNovel (多个用户可以收藏同一部小说)

### Chapter

**Purpose:** 章节内容管理，支持离线阅读和进度跟踪

**Key Attributes:**
- id: string - UUID，章节唯一标识符
- novel_id: string - 关联小说ID，建立章节归属
- chapter_number: integer - 章节序号，用于排序和导航
- title: string - 章节标题，显示在目录中
- content: text - 章节正文内容，核心业务数据
- word_count: integer - 字数统计，估算阅读时间
- source_url: string - 原站点链接，便于更新和校验
- is_cached: boolean - 是否已缓存，支持离线阅读
- created_at: datetime - 创建时间
- updated_at: datetime - 更新时间

#### TypeScript Interface
```typescript
interface Chapter {
  id: string;
  novel_id: string;
  chapter_number: number;
  title: string;
  content: string;
  word_count: number;
  source_url: string;
  is_cached: boolean;
  created_at: string;
  updated_at: string;
}
```

#### Relationships
- 多对一：Chapter ↔ Novel (多个章节属于一部小说)
- 一对一：Chapter ↔ ReadingProgress (一个章节对应用户的一个阅读进度)

### UserNovel

**Purpose:** 用户个人书架管理，支持收藏和分类

**Key Attributes:**
- id: string - UUID，记录唯一标识符
- user_id: string - 用户ID，标识收藏者
- novel_id: string - 小说ID，被收藏的小说
- is_favorite: boolean - 是否为收藏，用于特别标记
- reading_status: string - 阅读状态（未读/在读/已读）
- last_read_chapter_id: string - 最后阅读章节ID，支持断点续读
- last_read_position: integer - 阅读位置，精确到字符
- added_at: datetime - 添加到书架的时间
- updated_at: datetime - 最后更新时间

#### TypeScript Interface
```typescript
interface UserNovel {
  id: string;
  user_id: string;
  novel_id: string;
  is_favorite: boolean;
  reading_status: 'unread' | 'reading' | 'completed';
  last_read_chapter_id?: string;
  last_read_position?: number;
  added_at: string;
  updated_at: string;
}
```

#### Relationships
- 多对一：UserNovel ↔ Novel (多条书架记录指向同一部小说)
- 多对一：UserNovel ↔ User (一个用户有多条书架记录)

### ReadingProgress

**Purpose:** 精确的阅读进度跟踪，支持多设备同步

**Key Attributes:**
- id: string - UUID，进度记录唯一标识符
- user_id: string - 用户ID，标识阅读者
- chapter_id: string - 章节ID，被阅读的章节
- position: integer - 阅读位置（字符偏移量）
- progress_percent: float - 阅读百分比，便于展示
- read_time: integer - 阅读时长（秒），用于统计
- last_read_at: datetime - 最后阅读时间
- is_completed: boolean - 是否完成阅读该章节

#### TypeScript Interface
```typescript
interface ReadingProgress {
  id: string;
  user_id: string;
  chapter_id: string;
  position: number;
  progress_percent: number;
  read_time: number;
  last_read_at: string;
  is_completed: boolean;
}
```

#### Relationships
- 多对一：ReadingProgress ↔ Chapter (多个进度记录指向同一章节)
- 多对一：ReadingProgress ↔ User (一个用户有多条进度记录)

### CacheTask

**Purpose:** 后台缓存任务管理，支持离线阅读体验

**Key Attributes:**
- id: string - UUID，任务唯一标识符
- user_id: string - 用户ID，任务发起者
- novel_id: string - 小说ID，缓存目标
- task_type: string - 任务类型（全本缓存/更新缓存）
- status: string - 任务状态（排队/进行中/完成/失败）
- total_chapters: integer - 总章节数
- cached_chapters: integer - 已缓存章节数
- error_message: string - 错误信息，便于调试
- created_at: datetime - 任务创建时间
- completed_at: datetime - 任务完成时间

#### TypeScript Interface
```typescript
interface CacheTask {
  id: string;
  user_id: string;
  novel_id: string;
  task_type: 'full_cache' | 'update_cache';
  status: 'pending' | 'running' | 'completed' | 'failed';
  total_chapters: number;
  cached_chapters: number;
  error_message?: string;
  created_at: string;
  completed_at?: string;
}
```

#### Relationships
- 多对一：CacheTask ↔ Novel (多个缓存任务指向同一部小说)
- 多对一：CacheTask ↔ User (一个用户可以有多个缓存任务)

## API Specification

### REST API Specification (OpenAPI 3.0)

```yaml
openapi: 3.0.0
info:
  title: Novel Builder API
  version: 1.0.0
  description: 全栈小说阅读平台RESTful API，支持小说搜索、阅读、缓存等功能

servers:
  - url: http://localhost:3800/api/v1
    description: 本地开发环境
  - url: https://your-domain.com/api/v1
    description: 生产环境

paths:
  # 搜索相关
  /search:
    get:
      summary: 搜索小说
      parameters:
        - name: q
          in: query
          required: true
          schema:
            type: string
          description: 搜索关键词
        - name: site
          in: query
          required: false
          schema:
            type: string
            enum: [alice_sw, shukuge, xspsw, wdscw]
          description: 指定搜索站点
        - name: page
          in: query
          required: false
          schema:
            type: integer
            default: 1
          description: 页码
        - name: limit
          in: query
          required: false
          schema:
            type: integer
            default: 20
          description: 每页数量
      responses:
        '200':
          description: 搜索成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    type: object
                    properties:
                      novels:
                        type: array
                        items:
                          $ref: '#/components/schemas/Novel'
                      total:
                        type: integer
                      page:
                        type: integer
                      limit:
                        type: integer

  # 小说管理
  /novels/{novel_id}:
    get:
      summary: 获取小说详情
      parameters:
        - name: novel_id
          in: path
          required: true
          schema:
            type: string
          description: 小说ID
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    $ref: '#/components/schemas/NovelDetail'

  /novels/{novel_id}/chapters:
    get:
      summary: 获取小说章节列表
      parameters:
        - name: novel_id
          in: path
          required: true
          schema:
            type: string
          description: 小说ID
        - name: page
          in: query
          required: false
          schema:
            type: integer
            default: 1
          description: 页码
        - name: limit
          in: query
          required: false
          schema:
            type: integer
            default: 50
          description: 每页数量
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    type: object
                    properties:
                      chapters:
                        type: array
                        items:
                          $ref: '#/components/schemas/Chapter'
                      total:
                        type: integer
                      page:
                        type: integer
                      limit:
                        type: integer

  # 章节内容
  /chapters/{chapter_id}:
    get:
      summary: 获取章节内容
      parameters:
        - name: chapter_id
          in: path
          required: true
          schema:
            type: string
          description: 章节ID
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    $ref: '#/components/schemas/ChapterContent'

  # 用户书架管理
  /user/bookshelf:
    get:
      summary: 获取用户书架
      security:
        - bearerAuth: []
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/UserNovel'

    post:
      summary: 添加小说到书架
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - novel_id
              properties:
                novel_id:
                  type: string
      responses:
        '200':
          description: 添加成功

  /user/bookshelf/{novel_id}:
    delete:
      summary: 从书架移除小说
      security:
        - bearerAuth: []
      parameters:
        - name: novel_id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: 移除成功

  # 阅读进度
  /user/reading-progress:
    post:
      summary: 更新阅读进度
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - chapter_id
                - position
              properties:
                chapter_id:
                  type: string
                position:
                  type: integer
                progress_percent:
                  type: number
                read_time:
                  type: integer
      responses:
        '200':
          description: 更新成功

  # 缓存任务
  /cache/tasks:
    post:
      summary: 创建缓存任务
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - novel_id
              properties:
                novel_id:
                  type: string
                task_type:
                  type: string
                  enum: [full_cache, update_cache]
                  default: full_cache
      responses:
        '200':
          description: 任务创建成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    $ref: '#/components/schemas/CacheTask'

    get:
      summary: 获取用户缓存任务列表
      security:
        - bearerAuth: []
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/CacheTask'

  /cache/tasks/{task_id}/status:
    get:
      summary: 获取缓存任务状态
      security:
        - bearerAuth: []
      parameters:
        - name: task_id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: 获取成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  data:
                    $ref: '#/components/schemas/CacheTask'

components:
  schemas:
    Novel:
      type: object
      properties:
        id:
          type: string
          format: uuid
        title:
          type: string
        author:
          type: string
        description:
          type: string
        cover_url:
          type: string
        source_site:
          type: string
        status:
          type: string
          enum: [ongoing, completed]
        total_chapters:
          type: integer
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    NovelDetail:
      allOf:
        - $ref: '#/components/schemas/Novel'
        - type: object
          properties:
            chapters_count:
              type: integer
            last_updated:
              type: string
              format: date-time
            tags:
              type: array
              items:
                type: string

    Chapter:
      type: object
      properties:
        id:
          type: string
          format: uuid
        novel_id:
          type: string
          format: uuid
        chapter_number:
          type: integer
        title:
          type: string
        word_count:
          type: integer
        is_cached:
          type: boolean
        created_at:
          type: string
          format: date-time

    ChapterContent:
      allOf:
        - $ref: '#/components/schemas/Chapter'
        - type: object
          properties:
            content:
              type: string
            source_url:
              type: string

    UserNovel:
      type: object
      properties:
        id:
          type: string
          format: uuid
        novel_id:
          type: string
          format: uuid
        is_favorite:
          type: boolean
        reading_status:
          type: string
          enum: [unread, reading, completed]
        last_read_chapter_id:
          type: string
          format: uuid
        last_read_position:
          type: integer
        added_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    CacheTask:
      type: object
      properties:
        id:
          type: string
          format: uuid
        novel_id:
          type: string
          format: uuid
        task_type:
          type: string
          enum: [full_cache, update_cache]
        status:
          type: string
          enum: [pending, running, completed, failed]
        total_chapters:
          type: integer
        cached_chapters:
          type: integer
        error_message:
          type: string
        created_at:
          type: string
          format: date-time
        completed_at:
          type: string
          format: date-time

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

## Components

### Frontend Components

#### **NovelSearchService**
**Responsibility:** 处理小说搜索功能，支持关键词和站点筛选
**Key Interfaces:**
- searchNovels(query: string, site?: string): Promise<Novel[]>
- getSearchHistory(): Promise<string[]>
- clearSearchHistory(): Promise<void>
**Dependencies:** FastAPI backend search endpoint
**Technology Stack:** Flutter HTTP client, Provider state management

#### **BookshelfManager**
**Responsibility:** 用户书架管理，包括收藏、分类、阅读状态跟踪
**Key Interfaces:**
- addToBookshelf(novelId: string): Promise<void>
- removeFromBookshelf(novelId: string): Promise<void>
- getBookshelf(): Promise<UserNovel[]>
- updateReadingStatus(novelId: string, status: string): Promise<void>
**Dependencies:** SQLite local storage, backend bookshelf API
**Technology Stack:** Flutter Provider, SQLite database

#### **ReadingProgressTracker**
**Responsibility:** 精确的阅读进度跟踪和同步
**Key Interfaces:**
- updateProgress(chapterId: string, position: number): Promise<void>
- getProgress(novelId: string): Promise<ReadingProgress[]>
- syncProgress(): Promise<void>
**Dependencies:** Local storage, backend progress API
**Technology Stack:** Flutter SharedPreferences, background sync

#### **ChapterContentManager**
**Responsibility:** 章节内容缓存和离线阅读支持
**Key Interfaces:**
- getChapterContent(chapterId: string): Promise<string>
- cacheChapter(chapterId: string): Promise<void>
- getCachedChapters(novelId: string): Promise<string[]>
**Dependencies:** File system, backend chapter API
**Technology Stack:** Flutter file operations, background downloading

### Backend Components

#### **NovelSearchService**
**Responsibility:** 处理多站点小说搜索请求
**Key Interfaces:**
- searchAcrossSites(query: string, sites: string[]): Promise<SearchResult[]>
- getSiteCapabilities(): Promise<SiteCapability[]>
- normalizeSearchResults(results: SearchResult[]): Promise<SearchResult[]>
**Dependencies:** Multiple crawler services, PostgreSQL
**Technology Stack:** FastAPI, SQLAlchemy, asyncio

#### **CrawlerOrchestrator**
**Responsibility:** 管理和调度多个爬虫服务
**Key Interfaces:**
- triggerCrawl(site: string, novelUrl: string): Promise<CrawlTask>
- getCrawlerStatus(): Promise<CrawlerStatus[]>
- handleCrawlError(taskId: string, error: Error): Promise<void>
**Dependencies:** Individual crawler services, task queue
**Technology Stack:** Python asyncio, error handling, logging

#### **UserBookshelfService**
**Responsibility:** 用户书架数据管理
**Key Interfaces:**
- getUserBookshelf(userId: string): Promise<UserNovel[]>
- addToBookshelf(userId: string, novelId: string): Promise<void>
- updateBookshelfEntry(userId: string, novelId: string, data: Partial<UserNovel>): Promise<void>
**Dependencies:** PostgreSQL database, authentication service
**Technology Stack:** FastAPI, SQLAlchemy, database transactions

#### **CacheTaskManager**
**Responsibility:** 后台缓存任务管理
**Key Interfaces:**
- createCacheTask(userId: string, novelId: string, type: CacheType): Promise<CacheTask>
- updateTaskProgress(taskId: string, cachedCount: number): Promise<void>
- markTaskCompleted(taskId: string): Promise<void>
**Dependencies:** PostgreSQL, background task processor
**Technology Stack:** FastAPI, background jobs, Redis for task state

#### **ContentDeliveryService**
**Responsibility:** 章节内容获取和缓存管理
**Key Interfaces:**
- getChapterContent(chapterId: string): Promise<ChapterContent>
- cacheChapterContent(chapterId: string, content: string): Promise<void>
- invalidateCache(chapterId: string): Promise<void>
**Dependencies:** File system, database cache status, crawler services
**Technology Stack:** File I/O, caching strategies, error recovery

### Component Interactions

```mermaid
sequenceDiagram
    participant U as User Device
    participant FS as Flutter App
    participant API as FastAPI Backend
    participant DB as PostgreSQL
    participant Crawler as Crawler System

    U->>FS: Search for novel
    FS->>API: GET /search?q=keyword
    API->>Crawler: Trigger search across sites
    Crawler->>API: Return search results
    API->>FS: Return aggregated results
    FS->>U: Display search results

    U->>FS: Add to bookshelf
    FS->>FS: Save to local SQLite
    FS->>API: POST /user/bookshelf
    API->>DB: Save bookshelf entry
    API->>FS: Confirm saved

    U->>FS: Read chapter
    FS->>FS: Check local cache
    alt Chapter not cached
        FS->>API: GET /chapters/{id}
        API->>Crawler: Fetch chapter content
        Crawler->>API: Return chapter content
        API->>FS: Return chapter content
        FS->>FS: Cache content locally
    end
    FS->>U: Display chapter content

    U->>FS: Update reading progress
    FS->>FS: Save to local storage
    FS->>API: POST /user/reading-progress
    API->>DB: Update progress record
```

## External APIs

### Multi-Site Novel Crawlers

**AliceSW API**
- **Purpose:** 从AliceSW小说站点获取内容
- **Documentation:** Internal crawler service documentation
- **Base URL(s):** Internal service endpoints
- **Authentication:** Service-to-service API keys
- **Rate Limits:** 1 request/second per novel

**Key Endpoints Used:**
- `GET /search` - 搜索小说
- `GET /novel/{url}` - 获取小说详情
- `GET /chapter/{url}` - 获取章节内容

**Integration Notes:** Need to handle anti-bot measures, respect robots.txt, implement retry logic

**Shukuge Crawler API**
- **Purpose:** 从书库小说站点获取内容
- **Documentation:** Internal crawler service documentation
- **Base URL(s):** Internal service endpoints
- **Authentication:** Service-to-service API keys
- **Rate Limits:** 1 request/second per novel

**Key Endpoints Used:**
- `GET /search` - 搜索小说
- `GET /novel/{url}` - 获取小说详情
- `GET /chapter/{url}` - 获取章节内容

**Integration Notes:** Similar integration pattern as AliceSW, site-specific parsing logic

**Xspsw Crawler API**
- **Purpose:** 从小说网小说站点获取内容
- **Documentation:** Internal crawler service documentation
- **Base URL(s):** Internal service endpoints
- **Authentication:** Service-to-service API keys
- **Rate Limits:** 1 request/second per novel

**Key Endpoints Used:**
- `GET /search` - 搜索小说
- `GET /novel/{url}` - 获取小说详情
- `GET /chapter/{url}` - 获取章节内容

**Integration Notes:** Handle site-specific encoding and format differences

**WDSCW Crawler API**
- **Purpose:** 从我的书城小说站点获取内容
- **Documentation:** Internal crawler service documentation
- **Base URL(s):** Internal service endpoints
- **Authentication:** Service-to-service API keys
- **Rate Limits:** 1 request/second per novel

**Key Endpoints Used:**
- `GET /search` - 搜索小说
- `GET /novel/{url}` - 获取小说详情
- `GET /chapter/{url}` - 获取章节内容

**Integration Notes:** May require special handling for login-protected content

**Syshangguan Crawler API**
- **Purpose:** 从尚官小说站点获取内容
- **Documentation:** Internal crawler service documentation
- **Base URL(s):** Internal service endpoints
- **Authentication:** Service-to-service API keys
- **Rate Limits:** 1 request/second per novel

**Key Endpoints Used:**
- `GET /search` - 搜索小说
- `GET /novel/{url}` - 获取小说详情
- `GET /chapter/{url}` - 获取章节内容

**Integration Notes:** Most recent addition, may need ongoing maintenance

## Core Workflows

### Novel Discovery and Reading Workflow

```mermaid
sequenceDiagram
    participant U as User
    participant FA as Flutter App
    participant API as FastAPI Backend
    participant CR as Crawler Services
    participant DB as PostgreSQL
    participant FS as File System

    U->>FA: 搜索小说
    FA->>API: GET /api/v1/search?q=关键词
    API->>CR: 并行搜索多个站点
    CR->>API: 返回聚合搜索结果
    API->>FA: 返回统一格式结果
    FA->>U: 显示搜索结果

    U->>FA: 选择小说查看详情
    FA->>API: GET /api/v1/novels/{id}
    API->>DB: 查询小说详情
    API->>FA: 返回小说信息
    FA->>U: 显示小说详情页

    U->>FA: 添加到书架
    FA->>FA: 本地SQLite保存
    FA->>API: POST /api/v1/user/bookshelf
    API->>DB: 保存书架记录
    API->>FA: 确认保存成功
    FA->>U: 显示添加成功提示

    U->>FA: 开始阅读章节
    FA->>FA: 检查本地缓存
    alt 章节未缓存
        FA->>API: GET /api/v1/chapters/{id}
        API->>CR: 请求章节内容
        CR->>API: 返回章节内容
        API->>FA: 返回章节数据
        FA->>FS: 本地缓存章节内容
    else 章节已缓存
        FA->>FS: 直接读取本地缓存
    end
    FA->>U: 显示章节内容

    U->>FA: 滚动阅读
    FA->>FA: 定期更新阅读进度
    FA->>API: POST /api/v1/user/reading-progress
    API->>DB: 保存阅读进度

    U->>FA: 请求全本缓存
    FA->>API: POST /api/v1/cache/tasks
    API->>API: 创建后台缓存任务
    Note over API: 异步执行缓存任务
    API->>FA: 返回任务ID
    FA->>U: 显示缓存开始提示
```

### Multi-Site Content Synchronization Workflow

```mermaid
sequenceDiagram
    participant Scheduler as Task Scheduler
    participant Orchestrator as Crawler Orchestrator
    participant AliceSW as AliceSW Crawler
    participant Shukuge as Shukuge Crawler
    participant DB as PostgreSQL
    participant Cache as Redis Cache

    Scheduler->>Orchestrator: 定时同步任务
    Orchestrator->>AliceSW: 检查站点更新
    Orchestrator->>Shukuge: 检查站点更新

    par AliceSW 同步
        AliceSW->>AliceSW: 获取更新列表
        AliceSW->>DB: 更新小说信息
        AliceSW->>Cache: 刷新章节缓存
    and Shukuge 同步
        Shukuge->>Shukuge: 获取更新列表
        Shukuge->>DB: 更新小说信息
        Shukuge->>Cache: 刷新章节缓存
    end

    Orchestrator->>DB: 记录同步状态
    Orchestrator->>Scheduler: 返回同步结果
```

## Database Schema

### PostgreSQL Schema Design

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Novels table
CREATE TABLE novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    description TEXT,
    cover_url VARCHAR(500),
    source_site VARCHAR(50) NOT NULL,
    source_url VARCHAR(500) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('ongoing', 'completed')) DEFAULT 'ongoing',
    total_chapters INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    INDEX idx_novels_source_site (source_site),
    INDEX idx_novels_title_author (title, author),
    INDEX idx_novels_status (status)
);

-- Chapters table
CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    word_count INTEGER DEFAULT 0,
    source_url VARCHAR(500) NOT NULL,
    is_cached BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE KEY unique_chapter_novel_number (novel_id, chapter_number),
    INDEX idx_chapters_novel_id (novel_id),
    INDEX idx_chapters_cached (is_cached)
);

-- User bookshelf table
CREATE TABLE user_novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    is_favorite BOOLEAN DEFAULT FALSE,
    reading_status VARCHAR(20) CHECK (reading_status IN ('unread', 'reading', 'completed')) DEFAULT 'unread',
    last_read_chapter_id UUID REFERENCES chapters(id),
    last_read_position INTEGER DEFAULT 0,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE KEY unique_user_novel (user_id, novel_id),
    INDEX idx_user_novels_user_id (user_id),
    INDEX idx_user_novels_reading_status (reading_status)
);

-- Reading progress table
CREATE TABLE reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    position INTEGER DEFAULT 0,
    progress_percent DECIMAL(5,2) DEFAULT 0.0,
    read_time INTEGER DEFAULT 0,
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_completed BOOLEAN DEFAULT FALSE,

    UNIQUE KEY unique_user_chapter_progress (user_id, chapter_id),
    INDEX idx_reading_progress_user_id (user_id),
    INDEX idx_reading_progress_last_read (last_read_at)
);

-- Cache tasks table
CREATE TABLE cache_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    task_type VARCHAR(20) CHECK (task_type IN ('full_cache', 'update_cache')) DEFAULT 'full_cache',
    status VARCHAR(20) CHECK (status IN ('pending', 'running', 'completed', 'failed')) DEFAULT 'pending',
    total_chapters INTEGER DEFAULT 0,
    cached_chapters INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    INDEX idx_cache_tasks_user_id (user_id),
    INDEX idx_cache_tasks_status (status),
    INDEX idx_cache_tasks_created_at (created_at)
);

-- Full-text search index for novels
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_novels_title_trgm ON novels USING gin (title gin_trgm_ops);
CREATE INDEX idx_novels_author_trgm ON novels USING gin (author gin_trgm_ops);

-- Trigger functions for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_novels_updated_at BEFORE UPDATE ON novels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_novels_updated_at BEFORE UPDATE ON user_novels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Database Design Analysis

**Schema Normalization:** Database follows 3NF normalization with clear relationships between entities. Foreign key constraints ensure data integrity while allowing for efficient joins.

**Indexing Strategy:** Critical indexes on frequently queried columns (novel_id, user_id, status) and full-text search capabilities for novel titles and authors using PostgreSQL's pg_trgm extension.

**Data Integrity:** CHECK constraints ensure valid enum values, UNIQUE constraints prevent duplicate entries, and NOT NULL constraints maintain required data.

**Performance Considerations:** While not performance-optimized, the schema includes basic indexing for common query patterns. PostgreSQL's built-in query optimization will handle most read scenarios efficiently.

## Frontend Architecture

### Component Architecture

#### Component Organization
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes/
│   │   ├── app_routes.dart
│   │   └── route_generator.dart
│   └── theme/
│       ├── app_theme.dart
│       └── colors.dart
├── screens/
│   ├── home/
│   │   └── home_screen.dart
│   ├── search/
│   │   └── search_screen.dart
│   ├── bookshelf/
│   │   └── bookshelf_screen.dart
│   ├── reading/
│   │   ├── reader_screen.dart
│   │   └── chapter_list_screen.dart
│   └── settings/
│       └── settings_screen.dart
├── widgets/
│   ├── common/
│   │   ├── loading_widget.dart
│   │   ├── error_widget.dart
│   │   └── empty_state_widget.dart
│   ├── novel/
│   │   ├── novel_card.dart
│   │   ├── novel_cover.dart
│   │   └── novel_info.dart
│   ├── reading/
│   │   ├── chapter_item.dart
│   │   ├── reading_progress.dart
│   │   └── page_view.dart
│   └── bookshelf/
│       ├── bookshelf_item.dart
│       └── reading_status_badge.dart
├── services/
│   ├── api_service.dart
│   ├── novel_service.dart
│   ├── bookshelf_service.dart
│   ├── reading_service.dart
│   ├── cache_service.dart
│   └── auth_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── novel_provider.dart
│   ├── bookshelf_provider.dart
│   ├── reading_provider.dart
│   └── cache_provider.dart
├── models/
│   ├── novel.dart
│   ├── chapter.dart
│   ├── user_novel.dart
│   ├── reading_progress.dart
│   └── cache_task.dart
├── utils/
│   ├── database_helper.dart
│   ├── storage_helper.dart
│   ├── file_helper.dart
│   └── date_helper.dart
└── constants/
    ├── api_constants.dart
    ├── app_constants.dart
    └── storage_constants.dart
```

#### Component Template
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;

  const NovelCard({
    Key? key,
    required this.novel,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              NovelCover(
                coverUrl: novel.coverUrl,
                title: novel.title,
                width: 60,
                height: 80,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ReadingStatusBadge(
                          status: novel.status,
                        ),
                        const Spacer(),
                        Text(
                          '${novel.totalChapters}章',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### State Management Architecture

#### State Structure
```dart
// AppState.dart
class AppState {
  final AuthState auth;
  final NovelState novels;
  final BookshelfState bookshelf;
  final ReadingState reading;
  final CacheState cache;
  final SettingsState settings;

  AppState({
    required this.auth,
    required this.novels,
    required this.bookshelf,
    required this.reading,
    required this.cache,
    required this.settings,
  });

  AppState copyWith({
    AuthState? auth,
    NovelState? novels,
    BookshelfState? bookshelf,
    ReadingState? reading,
    CacheState? cache,
    SettingsState? settings,
  }) {
    return AppState(
      auth: auth ?? this.auth,
      novels: novels ?? this.novels,
      bookshelf: bookshelf ?? this.bookshelf,
      reading: reading ?? this.reading,
      cache: cache ?? this.cache,
      settings: settings ?? this.settings,
    );
  }
}

// NovelProvider.dart
class NovelProvider with ChangeNotifier {
  final NovelService _novelService;

  List<Novel> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  List<String> _searchHistory = [];

  NovelProvider(this._novelService);

  List<Novel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  List<String> get searchHistory => _searchHistory;

  Future<void> searchNovels(String query, {String? site}) async {
    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final results = await _novelService.searchNovels(query, site: site);
      _searchResults = results;

      // 更新搜索历史
      if (query.isNotEmpty && !_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
        await _saveSearchHistory();
      }
    } catch (e) {
      _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> clearSearchResults() async {
    _searchResults.clear();
    _searchError = null;
    notifyListeners();
  }

  Future<void> _saveSearchHistory() async {
    // 保存搜索历史到本地存储
    final storage = StorageHelper();
    await storage.setStringList('search_history', _searchHistory);
  }

  Future<void> loadSearchHistory() async {
    final storage = StorageHelper();
    _searchHistory = storage.getStringList('search_history') ?? [];
    notifyListeners();
  }
}
```

#### State Management Patterns
- **Single Source of Truth**: Each Provider manages one specific domain state
- **Immutable Updates**: Use copyWith pattern for state updates
- **Local Caching**: Critical data cached locally for offline support
- **Background Sync**: Progressive sync with backend when online
- **Error Boundaries**: Graceful error handling at each state level

### Routing Architecture

#### Route Organization
```dart
// app_routes.dart
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String bookshelf = '/bookshelf';
  static const String novelDetail = '/novel/:id';
  static const String chapterList = '/novel/:id/chapters';
  static const String reading = '/novel/:id/chapter/:chapterId';
  static const String settings = '/settings';
  static const String login = '/login';
}

// route_generator.dart
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: settings,
      );

    case AppRoutes.search:
      return MaterialPageRoute(
        builder: (_) => const SearchScreen(),
        settings: settings,
      );

    case AppRoutes.novelDetail:
      final novelId = settings.arguments as String;
      return MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novelId: novelId),
        settings: settings,
      );

    case AppRoutes.reading:
      final args = settings.arguments as Map<String, String>;
      final novelId = args['novelId']!;
      final chapterId = args['chapterId']!;
      return MaterialPageRoute(
        builder: (_) => ReadingScreen(
          novelId: novelId,
          chapterId: chapterId,
        ),
        settings: settings,
      );

    default:
      return MaterialPageRoute(
        builder: (_) => const NotFoundScreen(),
        settings: settings,
      );
  }
}
```

#### Protected Route Pattern
```dart
// protected_route.dart
class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final String? redirectTo;

  const ProtectedRoute({
    Key? key,
    required this.child,
    this.redirectTo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuthenticated) {
          return child;
        } else {
          // 重定向到登录页，保存当前路由用于登录后跳转
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.login,
              arguments: redirectTo ?? ModalRoute.of(context)?.settings.name,
            );
          });
          return const LoadingScreen();
        }
      },
    );
  }
}
```

### Frontend Services Layer

#### API Client Setup
```dart
// api_service.dart
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _authToken;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) => log(object.toString()),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // 处理token过期
          await _refreshToken();
          if (_authToken != null) {
            // 重试原请求
            final clonedRequest = error.requestOptions;
            clonedRequest.headers['Authorization'] = 'Bearer $_authToken';
            final response = await _dio.fetch(clonedRequest);
            handler.resolve(response);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<void> _refreshToken() async {
    try {
      final refreshToken = await StorageHelper().getString('refresh_token');
      if (refreshToken != null) {
        final response = await _dio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
        });
        final newToken = response.data['access_token'];
        await StorageHelper().setString('access_token', newToken);
        setAuthToken(newToken);
      }
    } catch (e) {
      clearAuthToken();
      await StorageHelper().remove('access_token');
      await StorageHelper().remove('refresh_token');
      throw Exception('Token refresh failed');
    }
  }
}
```

#### Service Example
```dart
// novel_service.dart
class NovelService {
  final ApiService _apiService = ApiService();

  Future<List<Novel>> searchNovels(String query, {String? site}) async {
    try {
      final Map<String, dynamic> queryParams = {'q': query};
      if (site != null) {
        queryParams['site'] = site;
      }

      final response = await _apiService.get('/search', queryParameters: queryParams);

      if (response.data['success'] == true) {
        final List<dynamic> novelsJson = response.data['data']['novels'];
        return novelsJson.map((json) => Novel.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '搜索失败');
      }
    } catch (e) {
      throw Exception('搜索小说时发生错误: $e');
    }
  }

  Future<NovelDetail> getNovelDetail(String novelId) async {
    try {
      final response = await _apiService.get('/novels/$novelId');

      if (response.data['success'] == true) {
        return NovelDetail.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '获取小说详情失败');
      }
    } catch (e) {
      throw Exception('获取小说详情时发生错误: $e');
    }
  }

  Future<List<Chapter>> getChapterList(String novelId, {int page = 1, int limit = 50}) async {
    try {
      final response = await _apiService.get('/novels/$novelId/chapters', queryParameters: {
        'page': page,
        'limit': limit,
      });

      if (response.data['success'] == true) {
        final List<dynamic> chaptersJson = response.data['data']['chapters'];
        return chaptersJson.map((json) => Chapter.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '获取章节列表失败');
      }
    } catch (e) {
      throw Exception('获取章节列表时发生错误: $e');
    }
  }

  Future<ChapterContent> getChapterContent(String chapterId) async {
    try {
      final response = await _apiService.get('/chapters/$chapterId');

      if (response.data['success'] == true) {
        return ChapterContent.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '获取章节内容失败');
      }
    } catch (e) {
      throw Exception('获取章节内容时发生错误: $e');
    }
  }
}
```

## Backend Architecture

### Service Architecture

#### Function Organization
```
backend/
├── app/
│   ├── main.py
│   ├── api/
│   │   ├── v1/
│   │   │   ├── endpoints/
│   │   │   │   ├── novels.py
│   │   │   │   ├── chapters.py
│   │   │   │   ├── users.py
│   │   │   │   ├── bookshelf.py
│   │   │   │   ├── reading.py
│   │   │   │   └── cache.py
│   │   │   ├── api.py
│   │   │   └── dependencies.py
│   │   └── __init__.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   ├── database.py
│   │   └── logging.py
│   ├── services/
│   │   ├── novel_service.py
│   │   ├── chapter_service.py
│   │   ├── user_service.py
│   │   ├── bookshelf_service.py
│   │   ├── reading_service.py
│   │   ├── cache_service.py
│   │   └── crawler_orchestrator.py
│   ├── models/
│   │   ├── user.py
│   │   ├── novel.py
│   │   ├── chapter.py
│   │   ├── user_novel.py
│   │   ├── reading_progress.py
│   │   └── cache_task.py
│   ├── schemas/
│   │   ├── user.py
│   │   ├── novel.py
│   │   ├── chapter.py
│   │   ├── user_novel.py
│   │   ├── reading_progress.py
│   │   └── cache_task.py
│   ├── crawlers/
│   │   ├── base_crawler.py
│   │   ├── alice_sw_crawler.py
│   │   ├── shukuge_crawler.py
│   │   ├── xspsw_crawler.py
│   │   ├── wdscw_crawler.py
│   ├── utils/
│   │   ├── text_processing.py
│   │   ├── file_operations.py
│   │   └── cache_manager.py
│   └── workers/
│       ├── cache_worker.py
│       └── sync_worker.py
├── alembic/
│   └── versions/
├── tests/
├── requirements.txt
└── docker-compose.yml
```

#### Controller Template
```python
# endpoints/novels.py
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.novel import Novel, NovelDetail, NovelSearchResponse
from app.schemas.user import User
from app.services.novel_service import NovelService

router = APIRouter()

@router.get("/search", response_model=NovelSearchResponse)
async def search_novels(
    q: str = Query(..., min_length=1, description="搜索关键词"),
    site: Optional[str] = Query(None, description="指定搜索站点"),
    page: int = Query(1, ge=1, description="页码"),
    limit: int = Query(20, ge=1, le=100, description="每页数量"),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    搜索小说

    - **q**: 搜索关键词（必需）
    - **site**: 指定搜索站点（可选）
    - **page**: 页码，默认为1
    - **limit**: 每页数量，默认为20，最大100
    """
    try:
        novel_service = NovelService(db)
        result = await novel_service.search_novels(
            query=q,
            site=site,
            page=page,
            limit=limit,
            user_id=current_user.id if current_user else None
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{novel_id}", response_model=NovelDetail)
async def get_novel_detail(
    novel_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    获取小说详情

    - **novel_id**: 小说ID
    """
    try:
        novel_service = NovelService(db)
        novel = await novel_service.get_novel_detail(
            novel_id=novel_id,
            user_id=current_user.id if current_user else None
        )
        if not novel:
            raise HTTPException(status_code=404, detail="小说不存在")
        return novel
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{novel_id}/chapters")
async def get_chapter_list(
    novel_id: str,
    page: int = Query(1, ge=1, description="页码"),
    limit: int = Query(50, ge=1, le=200, description="每页数量"),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    获取小说章节列表

    - **novel_id**: 小说ID
    - **page**: 页码，默认为1
    - **limit**: 每页数量，默认为50，最大200
    """
    try:
        novel_service = NovelService(db)
        result = await novel_service.get_chapter_list(
            novel_id=novel_id,
            page=page,
            limit=limit,
            user_id=current_user.id if current_user else None
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### Database Architecture

#### Schema Design
```sql
-- Database schema defined in SQLAlchemy models
-- See Database Schema section for complete SQL definitions
```

#### Data Access Layer
```python
# models/novel.py
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base

class Novel(Base):
    __tablename__ = "novels"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default="gen_random_uuid()")
    title = Column(String(255), nullable=False)
    author = Column(String(255), nullable=False)
    description = Column(String)
    cover_url = Column(String(500))
    source_site = Column(String(50), nullable=False)
    source_url = Column(String(500), nullable=False)
    status = Column(String(20), default="ongoing")  # ongoing, completed
    total_chapters = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default="now()")
    updated_at = Column(DateTime(timezone=True), server_default="now()")

    # Relationships
    chapters = relationship("Chapter", back_populates="novel", cascade="all, delete-orphan")
    user_novels = relationship("UserNovel", back_populates="novel", cascade="all, delete-orphan")

    __table_args__ = (
        Index('idx_novels_source_site', 'source_site'),
        Index('idx_novels_title_author', 'title', 'author'),
        Index('idx_novels_status', 'status'),
    )

# services/novel_service.py
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, text

from app.models.novel import Novel
from app.models.chapter import Chapter
from app.schemas.novel import NovelCreate, NovelUpdate, NovelSearchResponse

class NovelService:
    def __init__(self, db: Session):
        self.db = db

    async def search_novels(
        self,
        query: str,
        site: Optional[str] = None,
        page: int = 1,
        limit: int = 20,
        user_id: Optional[str] = None
    ) -> NovelSearchResponse:
        """搜索小说"""
        # 构建搜索查询
        search_filter = []

        # 全文搜索标题和作者
        search_filter.append(
            or_(
                Novel.title.ilike(f"%{query}%"),
                Novel.author.ilike(f"%{query}%")
            )
        )

        # 站点筛选
        if site:
            search_filter.append(Novel.source_site == site)

        # 执行查询
        query_obj = self.db.query(Novel).filter(and_(*search_filter))

        # 获取总数
        total = query_obj.count()

        # 分页查询
        novels = query_obj.offset((page - 1) * limit).limit(limit).all()

        # 如果用户已登录，获取用户的收藏状态
        if user_id:
            from app.models.user_novel import UserNovel
            user_novels = self.db.query(UserNovel).filter(
                UserNovel.user_id == user_id,
                UserNovel.novel_id.in_([novel.id for novel in novels])
            ).all()

            user_novel_map = {
                un.novel_id: un for un in user_novels
            }

            # 为每个小说添加用户收藏信息
            for novel in novels:
                if novel.id in user_novel_map:
                    novel.user_novel = user_novel_map[novel.id]

        return NovelSearchResponse(
            novels=novels,
            total=total,
            page=page,
            limit=limit
        )

    async def get_novel_detail(
        self,
        novel_id: str,
        user_id: Optional[str] = None
    ) -> Optional[Novel]:
        """获取小说详情"""
        novel = self.db.query(Novel).filter(Novel.id == novel_id).first()

        if not novel:
            return None

        # 如果用户已登录，获取用户收藏状态
        if user_id:
            from app.models.user_novel import UserNovel
            user_novel = self.db.query(UserNovel).filter(
                UserNovel.user_id == user_id,
                UserNovel.novel_id == novel_id
            ).first()
            novel.user_novel = user_novel

        # 获取章节数量
        novel.chapters_count = self.db.query(func.count(Chapter.id)).filter(
            Chapter.novel_id == novel_id
        ).scalar() or 0

        return novel

    async def get_chapter_list(
        self,
        novel_id: str,
        page: int = 1,
        limit: int = 50,
        user_id: Optional[str] = None
    ) -> dict:
        """获取章节列表"""
        # 获取总章节数
        total = self.db.query(func.count(Chapter.id)).filter(
            Chapter.novel_id == novel_id
        ).scalar() or 0

        # 分页查询章节
        chapters = self.db.query(Chapter).filter(
            Chapter.novel_id == novel_id
        ).order_by(Chapter.chapter_number).offset((page - 1) * limit).limit(limit).all()

        # 如果用户已登录，获取阅读进度
        if user_id:
            from app.models.reading_progress import ReadingProgress
            user_progress = self.db.query(ReadingProgress).filter(
                ReadingProgress.user_id == user_id,
                ReadingProgress.chapter_id.in_([chapter.id for chapter in chapters])
            ).all()

            progress_map = {
                rp.chapter_id: rp for rp in user_progress
            }

            # 为每个章节添加阅读进度
            for chapter in chapters:
                if chapter.id in progress_map:
                    chapter.reading_progress = progress_map[chapter.id]

        return {
            "chapters": chapters,
            "total": total,
            "page": page,
            "limit": limit
        }

    async def create_novel(self, novel_data: NovelCreate) -> Novel:
        """创建小说"""
        novel = Novel(**novel_data.dict())
        self.db.add(novel)
        self.db.commit()
        self.db.refresh(novel)
        return novel

    async def update_novel(self, novel_id: str, novel_data: NovelUpdate) -> Optional[Novel]:
        """更新小说"""
        novel = self.db.query(Novel).filter(Novel.id == novel_id).first()
        if not novel:
            return None

        for field, value in novel_data.dict(exclude_unset=True).items():
            setattr(novel, field, value)

        self.db.commit()
        self.db.refresh(novel)
        return novel

    async def delete_novel(self, novel_id: str) -> bool:
        """删除小说"""
        novel = self.db.query(Novel).filter(Novel.id == novel_id).first()
        if not novel:
            return False

        self.db.delete(novel)
        self.db.commit()
        return True
```

### Authentication and Authorization

#### Auth Flow
```mermaid
sequenceDiagram
    participant U as User
    participant FA as Flutter App
    participant API as FastAPI Backend
    participant DB as PostgreSQL
    participant TokenStore as JWT Storage

    U->>FA: 输入用户名密码
    FA->>API: POST /auth/login
    API->>DB: 验证用户凭据
    DB->>API: 返回用户信息
    API->>API: 生成JWT token
    API->>FA: 返回access_token和refresh_token
    FA->>TokenStore: 存储tokens

    Note over FA: 后续API请求携带token

    FA->>API: GET /protected/resource (带Bearer Token)
    API->>API: 验证JWT token
    API->>DB: 获取资源数据
    DB->>API: 返回资源
    API->>FA: 返回响应

    Note over API: Token过期时
    API->>API: 检测token过期
    API->>FA: 返回401未授权
    FA->>API: POST /auth/refresh (带refresh_token)
    API->>TokenStore: 验证refresh_token
    API->>API: 生成新的access_token
    API->>FA: 返回新token
    FA->>API: 重试原请求
```

#### Middleware/Guards
```python
# core/security.py
from datetime import datetime, timedelta
from typing import Optional, Union
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.user import User

# 密码加密上下文
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT认证
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """生成密码哈希"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """创建访问令牌"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def create_refresh_token(data: dict) -> str:
    """创建刷新令牌"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Optional[dict]:
    """验证令牌"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        username: str = payload.get("sub")
        token_type: str = payload.get("type")

        if username is None:
            return None

        if token_type == "refresh":
            return {"username": username, "type": "refresh"}
        else:
            return {"username": username, "type": "access"}

    except JWTError:
        return None

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """获取当前用户"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            credentials.credentials, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        username: str = payload.get("sub")
        token_type: str = payload.get("type")

        if username is None or token_type != "access":
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise credentials_exception

    return user

async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """获取当前活跃用户"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# 可选认证（允许匿名访问的端点）
async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """获取当前用户（可选）"""
    if not credentials:
        return None

    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None

# 权限检查装饰器
def require_permissions(permissions: Union[str, list]):
    """权限检查装饰器"""
    def permission_checker(current_user: User = Depends(get_current_user)) -> User:
        if isinstance(permissions, str):
            required_permissions = [permissions]
        else:
            required_permissions = permissions

        user_permissions = current_user.permissions or []

        # 检查用户是否有所需权限
        if not any(perm in user_permissions for perm in required_permissions):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )

        return current_user

    return permission_checker
```

## Unified Project Structure

### Monorepo Structure
```
novel_builder/
├── .github/                    # CI/CD workflows
│   └── workflows/
│       ├── ci.yaml
│       └── deploy.yaml
├── novel_app/                  # Flutter移动应用
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/
│   │   │   ├── app.dart
│   │   │   ├── routes/
│   │   │   └── theme/
│   │   ├── screens/
│   │   │   ├── home/
│   │   │   ├── search/
│   │   │   ├── bookshelf/
│   │   │   ├── reading/
│   │   │   └── settings/
│   │   ├── widgets/
│   │   │   ├── common/
│   │   │   ├── novel/
│   │   │   ├── reading/
│   │   │   └── bookshelf/
│   │   ├── services/
│   │   ├── providers/
│   │   ├── models/
│   │   ├── utils/
│   │   └── constants/
│   ├── test/
│   ├── pubspec.yaml
│   └── Dockerfile
├── backend/                    # FastAPI后端应用
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   ├── core/
│   │   ├── services/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── crawlers/
│   │   ├── utils/
│   │   └── workers/
│   ├── tests/
│   ├── requirements.txt
│   ├── alembic/
│   └── Dockerfile
├── infrastructure/             # IaC定义
│   ├── docker/
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.prod.yml
│   │   └── nginx/
│   └── database/
│       └── init.sql
├── docs/                       # 项目文档
│   ├── architecture.md
│   ├── api/
│   └── deployment/
├── scripts/                    # 构建部署脚本
│   ├── build.sh
│   ├── deploy.sh
│   └── backup.sh
├── .env.example                # 环境变量模板
├── .gitignore
├── README.md
└── LICENSE
```

### Container Configuration
```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL数据库
  postgres:
    image: postgres:15
    container_name: novel_builder_db
    environment:
      POSTGRES_DB: novel_builder
      POSTGRES_USER: novel_user
      POSTGRES_PASSWORD: novel_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infrastructure/database/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - novel_network

  # Redis缓存
  redis:
    image: redis:7-alpine
    container_name: novel_builder_redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - novel_network

  # FastAPI后端
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: novel_builder_api
    environment:
      DATABASE_URL: postgresql://novel_user:novel_password@postgres:5432/novel_builder
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-here}
      DEBUG: true
    volumes:
      - ./backend:/app
      - novel_cache:/app/cache
    ports:
      - "3800:8000"
    depends_on:
      - postgres
      - redis
    networks:
      - novel_network
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  # Flutter应用开发服务（仅开发环境）
  flutter_dev:
    build:
      context: ./novel_app
      dockerfile: Dockerfile.dev
    container_name: novel_builder_flutter
    environment:
      API_BASE_URL: http://localhost:3800/api/v1
    volumes:
      - ./novel_app:/app
      - flutter_deps:/app/.pub-cache
    ports:
      - "3154:3000"
    depends_on:
      - backend
    networks:
      - novel_network
    command: flutter run -d web-server --web-port 3000 --web-host 0.0.0.0

volumes:
  postgres_data:
  redis_data:
  novel_cache:
  flutter_deps:

networks:
  novel_network:
    driver: bridge
```

## Development Workflow

### Local Development Setup

#### Prerequisites
```bash
# 检查系统要求
# Flutter SDK 3.0+
flutter doctor

# Python 3.11+
python --version

# Docker and Docker Compose
docker --version
docker-compose --version

# Git
git --version
```

#### Initial Setup
```bash
# 克隆项目
git clone <repository-url>
cd novel_builder

# 创建环境变量文件
cp .env.example .env
# 编辑 .env 文件设置必要的环境变量

# 启动数据库和后端服务
docker-compose up -d postgres redis backend

# 等待后端服务启动（约30秒）
sleep 30

# 运行数据库迁移
docker-compose exec backend alembic upgrade head

# 安装Flutter依赖
cd novel_app
flutter pub get

# 返回根目录
cd ..
```

#### Development Commands

```bash
# 启动所有服务（开发模式）
docker-compose up

# 启动前端服务（独立）
cd novel_app
flutter run

# 启动后端服务（独立）
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 运行测试
# Flutter测试
cd novel_app && flutter test

# 后端测试
cd backend && python -m pytest

# 数据库操作
cd backend
# 创建迁移
alembic revision --autogenerate -m "描述"
# 应用迁移
alembic upgrade head
# 回滚迁移
alembic downgrade -1

# 代码质量检查
# Flutter代码分析
cd novel_app && flutter analyze

# Python代码格式化
cd backend && ruff format . && ruff check .

# 数据库管理
# 连接数据库
docker-compose exec postgres psql -U novel_user -d novel_builder

# 查看日志
docker-compose logs -f backend
docker-compose logs -f postgres
```

### Environment Configuration

#### Required Environment Variables
```bash
# 后端环境变量 (.env)
DATABASE_URL=postgresql://novel_user:novel_password@localhost:5432/novel_builder
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-super-secret-key-here-change-in-production
DEBUG=true
API_V1_STR=/api/v1
PROJECT_NAME=Novel Builder

# 爬虫配置
CRAWLER_USER_AGENT=NovelBuilder/1.0
CRAWLER_DELAY=1
CRAWLER_TIMEOUT=30
CRAWLER_RETRY_TIMES=3

# 文件存储配置
UPLOAD_DIR=./cache
MAX_UPLOAD_SIZE=100MB

# JWT配置
SECRET_KEY=your-jwt-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# 前端环境变量 (novel_app/.env)
API_BASE_URL=http://localhost:3800/api/v1
APP_NAME=Novel Builder
APP_VERSION=1.0.0

# 缓存配置
CACHE_TTL=3600
MAX_CACHE_SIZE=1GB
```

## Deployment Architecture

### Deployment Strategy

**Frontend Deployment:**
- **Platform:** Self-hosted web server (via Flutter web)
- **Build Command:** `flutter build web`
- **Output Directory:** `build/web`
- **CDN/Edge:** None (direct serving)

**Backend Deployment:**
- **Platform:** Docker containers on cloud server
- **Build Command:** `docker build -t novel-builder-backend .`
- **Deployment Method:** Docker Compose with nginx reverse proxy

### CI/CD Pipeline
```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements.txt

    - name: Run tests
      run: |
        cd backend
        python -m pytest

    - name: Check code quality
      run: |
        cd backend
        ruff check .
        ruff format . --check

  flutter-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Set up Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.0+'

    - name: Install dependencies
      run: |
        cd novel_app
        flutter pub get

    - name: Run tests
      run: |
        cd novel_app
        flutter test

    - name: Build web app
      run: |
        cd novel_app
        flutter build web

  build-and-deploy:
    needs: [backend-tests, flutter-tests]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - uses: actions/checkout@v3

    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /path/to/novel_builder
          git pull origin main
          docker-compose down
          docker-compose up -d --build
```

### Environments

| Environment | Frontend URL | Backend URL | Purpose |
|-------------|--------------|-------------|---------|
| Development | http://localhost:3154 | http://localhost:3800 | 本地开发 |
| Staging | https://staging.novel-builder.com | https://api-staging.novel-builder.com | 预生产测试 |
| Production | https://novel-builder.com | https://api.novel-builder.com | 生产环境 |

## Security and Performance

### Security Requirements

**Frontend Security:**
- CSP Headers: Default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'
- XSS Prevention: Flutter's built-in XSS protection + input sanitization
- Secure Storage: Flutter Secure Storage for sensitive data

**Backend Security:**
- Input Validation: Pydantic models with strict validation
- Rate Limiting: 100 requests/minute per user, 1000 requests/hour per IP
- CORS Policy: Restrict to specific origins in production

**Authentication Security:**
- Token Storage: Secure storage with automatic refresh
- Session Management: JWT with refresh token rotation
- Password Policy: Minimum 8 characters, at least one letter and number

### Performance Optimization

**Frontend Performance:**
- Bundle Size Target: <5MB initial load
- Loading Strategy: Lazy loading for chapters and images
- Caching Strategy: Local caching with background sync

**Backend Performance:**
- Response Time Target: <500ms for most API calls
- Database Optimization: Basic indexing for common queries
- Caching Strategy: Redis for frequently accessed data

## Testing Strategy

### Testing Pyramid

```
E2E Tests (5%)
/        \
Integration Tests (15%)
/            \
Frontend Unit (40%)  Backend Unit (40%)
```

### Test Organization

#### Frontend Tests
```
novel_app/test/
├── unit/
│   ├── services/
│   │   ├── novel_service_test.dart
│   │   └── bookshelf_service_test.dart
│   ├── providers/
│   │   ├── novel_provider_test.dart
│   │   └── auth_provider_test.dart
│   └── widgets/
│       ├── novel_card_test.dart
│       └── chapter_item_test.dart
├── widget/
│   ├── screens/
│   │   ├── home_screen_test.dart
│   │   └── reading_screen_test.dart
│   └── integration/
│       ├── search_flow_test.dart
│       └── reading_flow_test.dart
└── integration/
    └── app_test.dart
```

#### Backend Tests
```
backend/tests/
├── unit/
│   ├── services/
│   │   ├── test_novel_service.py
│   │   ├── test_user_service.py
│   │   └── test_crawler_service.py
│   ├── models/
│   │   ├── test_novel.py
│   │   └── test_user.py
│   └── utils/
│       └── test_text_processing.py
├── integration/
│   ├── test_api_endpoints.py
│   ├── test_database.py
│   └── test_crawlers.py
└── e2e/
    └── test_user_workflows.py
```

#### E2E Tests
```
tests/e2e/
├── search_flow_test.dart
├── reading_flow_test.dart
├── bookshelf_flow_test.dart
└── offline_reading_test.dart
```

### Test Examples

#### Frontend Component Test
```dart
// test/widgets/novel_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/novel/novel_card.dart';
import 'package:novel_app/models/novel.dart';

void main() {
  group('NovelCard Widget Tests', () {
    testWidgets('displays novel information correctly', (WidgetTester tester) async {
      const novel = Novel(
        id: 'test-id',
        title: '测试小说',
        author: '测试作者',
        description: '这是一个测试小说',
        coverUrl: 'https://example.com/cover.jpg',
        sourceSite: 'test-site',
        status: 'ongoing',
        totalChapters: 100,
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2023-01-01T00:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovelCard(
              novel: novel,
              onTap: () {},
            ),
          ),
        ),
      );

      // 验证小说标题显示
      expect(find.text('测试小说'), findsOneWidget);

      // 验证作者显示
      expect(find.text('测试作者'), findsOneWidget);

      // 验证章节数显示
      expect(find.text('100章'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool onTapCalled = false;

      const novel = Novel(
        id: 'test-id',
        title: '测试小说',
        author: '测试作者',
        description: '这是一个测试小说',
        sourceSite: 'test-site',
        status: 'ongoing',
        totalChapters: 100,
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2023-01-01T00:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovelCard(
              novel: novel,
              onTap: () {
                onTapCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(NovelCard));
      await tester.pump();

      expect(onTapCalled, isTrue);
    });
  });
}
```

#### Backend API Test
```python
# tests/integration/test_api_endpoints.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate

client = TestClient(app)

class TestNovelEndpoints:
    def test_search_novels_success(self, db_session: Session):
        """测试小说搜索成功"""
        # 创建测试用户
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpassword"
        )
        user = User(**user_data.dict())
        db_session.add(user)
        db_session.commit()

        # 获取认证token
        login_response = client.post("/api/v1/auth/login", data={
            "username": "testuser",
            "password": "testpassword"
        })
        token = login_response.json()["access_token"]

        # 测试搜索
        headers = {"Authorization": f"Bearer {token}"}
        response = client.get(
            "/api/v1/search?q=测试",
            headers=headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "novels" in data["data"]
        assert isinstance(data["data"]["novels"], list)

    def test_search_novels_unauthorized(self):
        """测试未授权搜索"""
        response = client.get("/api/v1/search?q=测试")
        assert response.status_code == 401

    def test_search_novels_invalid_query(self, db_session: Session):
        """测试无效搜索查询"""
        # 创建并认证用户（同上）
        # ...

        headers = {"Authorization": f"Bearer {token}"}
        response = client.get(
            "/api/v1/search",  # 缺少必需的q参数
            headers=headers
        )

        assert response.status_code == 422  # Validation error

    def test_get_novel_detail_success(self, db_session: Session):
        """测试获取小说详情成功"""
        # 创建测试小说
        novel_data = {
            "title": "测试小说",
            "author": "测试作者",
            "description": "这是一个测试小说",
            "source_site": "test-site",
            "source_url": "https://example.com/novel",
            "status": "ongoing",
            "total_chapters": 50
        }

        novel = Novel(**novel_data)
        db_session.add(novel)
        db_session.commit()

        # 认证用户
        # ...

        headers = {"Authorization": f"Bearer {token}"}
        response = client.get(
            f"/api/v1/novels/{novel.id}",
            headers=headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["title"] == "测试小说"
        assert data["data"]["author"] == "测试作者"

    def test_get_novel_detail_not_found(self, db_session: Session):
        """测试获取不存在的小说"""
        # 认证用户
        # ...

        headers = {"Authorization": f"Bearer {token}"}
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = client.get(
            f"/api/v1/novels/{fake_id}",
            headers=headers
        )

        assert response.status_code == 404
```

#### E2E Test
```dart
// tests/e2e/search_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:novel_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Search Flow E2E Tests', () {
    testWidgets('complete search and reading flow', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 验证首页加载
      expect(find.text('Novel Builder'), findsOneWidget);

      // 点击搜索标签页
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      // 输入搜索关键词
      await tester.enterText(find.byType(TextField), '测试小说');
      await tester.pumpAndSettle();

      // 点击搜索按钮
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // 验证搜索结果显示
      expect(find.text('搜索结果'), findsOneWidget);

      // 点击第一个搜索结果
      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      // 验证小说详情页面
      expect(find.text('小说详情'), findsOneWidget);

      // 点击加入书架按钮
      await tester.tap(find.text('加入书架'));
      await tester.pumpAndSettle();

      // 验证加入成功提示
      expect(find.text('已加入书架'), findsOneWidget);

      // 点击开始阅读按钮
      await tester.tap(find.text('开始阅读'));
      await tester.pumpAndSettle();

      // 验证章节列表页面
      expect(find.text('章节列表'), findsOneWidget);

      // 点击第一章
      await tester.tap(find.text('第一章'));
      await tester.pumpAndSettle();

      // 验证阅读页面加载
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // 模拟阅读滚动
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle();

      // 等待阅读进度自动保存
      await tester.pump(const Duration(seconds: 2));

      // 导航到书架页面
      await tester.tap(find.text('书架'));
      await tester.pumpAndSettle();

      // 验证小说出现在书架中
      expect(find.text('测试小说'), findsOneWidget);
    });

    testWidgets('offline reading functionality', (WidgetTester tester) async {
      // 完整的离线阅读测试流程
      // 1. 在线状态下缓存章节
      // 2. 断开网络连接
      // 3. 验证离线阅读功能

      // 这个测试需要模拟网络状态变化
      // 实际实现需要配合网络模拟工具
    });
  });
}
```

## Coding Standards

### Critical Fullstack Rules

- **Type Sharing:** Always define types in shared schema files and import from there for consistency
- **API Calls:** Never make direct HTTP calls - use the service layer for all API communications
- **Environment Variables:** Access only through config objects, never process.env directly in application code
- **Error Handling:** All API routes must use the standard error handler and return consistent error responses
- **State Updates:** Never mutate state directly - use proper state management patterns with immutable updates
- **Database Transactions:** Always use database transactions for multi-table operations to maintain data consistency
- **Authentication:** All protected endpoints must validate JWT tokens and user permissions
- **File Naming:** Use snake_case for backend files and camelCase for frontend files
- **Logging:** Always log important operations and errors for debugging and monitoring

### Naming Conventions

| Element | Frontend | Backend | Example |
|---------|----------|---------|---------|
| Components | PascalCase | - | `UserProfile.dart` |
| Screens | PascalCase | - | `HomeScreen.dart` |
| Services | camelCase | snake_case | `novelService.dart`, `novel_service.py` |
| Models | PascalCase | PascalCase | `Novel.dart`, `Novel.py` |
| API Routes | - | kebab-case | `/user-profile` |
| Database Tables | - | snake_case | `user_profiles` |
| Variables | camelCase | snake_case | `userName`, `user_name` |
| Constants | SCREAMING_SNAKE_CASE | SCREAMING_SNAKE_CASE | `API_BASE_URL` |

## Error Handling Strategy

### Error Flow
```mermaid
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant API as Backend API
    participant DB as Database
    participant L as Logging

    U->>FE: 执行操作
    FE->>API: API请求
    API->>DB: 数据库操作

    alt 成功
        DB->>API: 返回数据
        API->>FE: 200 + success响应
        FE->>U: 显示成功结果
    else 数据库错误
        DB->>API: 抛出异常
        API->>L: 记录错误日志
        API->>FE: 500 + 错误信息
        FE->>U: 显示错误提示
    else 验证错误
        API->>FE: 422 + 验证错误详情
        FE->>U: 显示字段级错误
    else 认证错误
        API->>FE: 401 + 认证失败
        FE->>FE: 重定向到登录页
        FE->>U: 显示登录界面
    end
```

### Error Response Format
```typescript
interface ApiError {
  error: {
    code: string;
    message: string;
    details?: Record<string, any>;
    timestamp: string;
    requestId: string;
  };
}
```

### Frontend Error Handling
```dart
// utils/error_handler.dart
import 'package:flutter/material.dart';

class ErrorHandler {
  static void handleApiError(dynamic error, BuildContext context) {
    String message = '发生了未知错误';

    if (error is Map && error.containsKey('error')) {
      message = error['error']['message'] ?? message;
    } else if (error.toString().contains('SocketException')) {
      message = '网络连接失败，请检查网络设置';
    } else if (error.toString().contains('TimeoutException')) {
      message = '请求超时，请稍后重试';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: '重试',
          onPressed: () {
            // 重试逻辑
          },
        ),
      ),
    );
  }

  static void handleUnexpectedError(dynamic error, BuildContext context) {
    // 记录错误日志
    log('Unexpected error: $error');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发生错误'),
        content: const Text('应用程序遇到了意外错误，请稍后重试'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
```

### Backend Error Handling
```python
# core/exceptions.py
from typing import Any, Dict, Optional
from fastapi import HTTPException, status

class NovelBuilderException(Exception):
    """基础异常类"""
    def __init__(
        self,
        message: str,
        code: str = "GENERAL_ERROR",
        details: Optional[Dict[str, Any]] = None
    ):
        self.message = message
        self.code = code
        self.details = details or {}
        super().__init__(self.message)

class ValidationException(NovelBuilderException):
    """验证异常"""
    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(message, "VALIDATION_ERROR", details)

class NotFoundException(NovelBuilderException):
    """资源未找到异常"""
    def __init__(self, resource: str, identifier: str = ""):
        message = f"{resource} not found"
        if identifier:
            message += f": {identifier}"
        super().__init__(message, "NOT_FOUND", {"resource": resource, "identifier": identifier})

class UnauthorizedException(NovelBuilderException):
    """未授权异常"""
    def __init__(self, message: str = "Unauthorized access"):
        super().__init__(message, "UNAUTHORIZED")

class CrawlerException(NovelBuilderException):
    """爬虫异常"""
    def __init__(self, message: str, site: str = "", details: Optional[Dict[str, Any]] = None):
        super().__init__(message, "CRAWLER_ERROR", {"site": site, **(details or {})})

# core/error_handler.py
import logging
import uuid
from datetime import datetime
from typing import Any, Dict
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from app.core.exceptions import NovelBuilderException

logger = logging.getLogger(__name__)

async def novel_builder_exception_handler(request: Request, exc: NovelBuilderException):
    """自定义异常处理器"""
    request_id = str(uuid.uuid4())

    error_response = {
        "error": {
            "code": exc.code,
            "message": exc.message,
            "details": exc.details,
            "timestamp": datetime.utcnow().isoformat(),
            "requestId": request_id,
        }
    }

    # 记录错误日志
    logger.error(
        f"Request {request_id} failed: {exc.code} - {exc.message}",
        extra={
            "request_id": request_id,
            "path": str(request.url),
            "method": request.method,
            "details": exc.details,
        },
        exc_info=True
    )

    return JSONResponse(
        status_code=get_status_code_for_exception(exc),
        content=error_response,
    )

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """验证异常处理器"""
    request_id = str(uuid.uuid4())

    # 格式化验证错误
    errors = {}
    for error in exc.errors():
        field = ".".join(str(loc) for loc in error["loc"])
        errors[field] = error["msg"]

    error_response = {
        "error": {
            "code": "VALIDATION_ERROR",
            "message": "请求参数验证失败",
            "details": {"validation_errors": errors},
            "timestamp": datetime.utcnow().isoformat(),
            "requestId": request_id,
        }
    }

    logger.warning(
        f"Request {request_id} validation failed: {errors}",
        extra={
            "request_id": request_id,
            "path": str(request.url),
            "method": request.method,
            "validation_errors": errors,
        }
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=error_response,
    )

def get_status_code_for_exception(exc: NovelBuilderException) -> int:
    """根据异常类型返回HTTP状态码"""
    status_code_map = {
        "VALIDATION_ERROR": status.HTTP_400_BAD_REQUEST,
        "NOT_FOUND": status.HTTP_404_NOT_FOUND,
        "UNAUTHORIZED": status.HTTP_401_UNAUTHORIZED,
        "FORBIDDEN": status.HTTP_403_FORBIDDEN,
        "CRAWLER_ERROR": status.HTTP_503_SERVICE_UNAVAILABLE,
    }
    return status_code_map.get(exc.code, status.HTTP_500_INTERNAL_SERVER_ERROR)
```

## Monitoring and Observability

### Monitoring Stack

- **Frontend Monitoring:** Flutter crash reporting + custom analytics
- **Backend Monitoring:** Python logging + structured logging
- **Error Tracking:** Centralized error logging with request IDs
- **Performance Monitoring:** Basic response time logging

### Key Metrics

**Frontend Metrics:**
- App startup time
- Screen load time
- API response times
- Error rates by feature
- User interaction events

**Backend Metrics:**
- Request rate by endpoint
- Response time percentiles
- Error rate by status code
- Database query performance
- Crawler success/failure rates
- Cache hit/miss ratios

---

## Checklist Results Report

Based on the comprehensive architecture analysis above, the Novel Builder project follows modern fullstack development best practices with a focus on simplicity and maintainability. The architecture supports the core requirements of a cross-platform novel reading application with multi-site content aggregation capabilities.

**Key Strengths:**
- ✅ Clear separation of concerns between frontend and backend
- ✅ Well-defined data models and API contracts
- ✅ Comprehensive testing strategy across all layers
- ✅ Containerized deployment for consistency
- ✅ Error handling and logging for observability
- ✅ Security considerations including authentication and input validation

**Areas for Future Enhancement:**
- Consider adding Redis caching layer for frequently accessed content
- Implement more sophisticated content deduplication across crawler sites
- Add comprehensive monitoring and alerting system
- Consider CDN integration for static assets in production

The architecture provides a solid foundation for development while maintaining flexibility for future growth and feature additions.