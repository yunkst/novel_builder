# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a full-stack novel reading platform with two main components:

### 1. Flutter Novel Reader App (`novel_app/`)
A Flutter-based novel reader application (小说阅读器) that allows users to search, read, cache, and interact with novels. Features include:
- Multi-source novel crawling via backend API
- Local SQLite caching for offline reading
- AI-powered content generation using Dify workflows
- User-inserted custom chapters
- Bookshelf management with reading progress tracking

### 2. Python Backend API (`backend/`)
FastAPI-based backend service that provides novel content crawling from multiple websites with unified API endpoints.

### 3. Vue.js Frontend (`frontend/`)
Vue.js frontend interface for the novel platform.

## Architecture Overview

The project follows a microservices architecture with:
- **Flutter Mobile App**: Cross-platform mobile client
- **FastAPI Backend**: Python REST API service (port 8000, exposed as 3800)
- **Vue.js Frontend**: Web interface (port 5173, exposed as 3154)
- **Docker Compose**: Orchestrates all services

## Development Commands

### Flutter App (`novel_app/`)

#### Setup
```bash
cd novel_app
flutter pub get

# Generate JSON serialization code (if needed)
dart run build_runner build --delete-conflicting-outputs
```

#### Code Quality
```bash
# Always run after making changes
flutter analyze

# Format code
flutter format lib/
```

#### Testing
```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

#### Building
```bash
# Build for Android
flutter build apk
flutter build appbundle

# Build for Windows
flutter build windows

# Build for iOS (macOS only)
flutter build ios
```

#### API Code Generation
```bash
# Install openapi-generator-cli first
npm install -g @openapitools/openapi-generator-cli

# Generate API client code
dart run tool/generate_api.dart

# Then install generated dependencies
flutter pub get
```

**Note:** Generated code goes into `lib/generated/api/` and should NOT be committed to Git.

### Vue.js Frontend (`frontend/`)

#### Setup
```bash
cd frontend
npm install
```

#### Development
```bash
npm run dev
npm run build
npm run type-check
npm run lint
npm run format
```

### Python Backend (`backend/`)

#### Setup
```bash
cd backend
pip install -r requirements.txt
```

#### Development
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Docker Services

#### Start All Services
```bash
docker-compose up -d
```

#### Stop Services
```bash
docker-compose down
```

#### View Logs
```bash
docker-compose logs -f
```

## Detailed Architecture

### Flutter App Structure

#### Application Structure
- **Main Entry**: `lib/main.dart` - Sets up Material3 theme with dark mode default and bottom navigation
- **Screens**: Bottom nav with 3 main tabs:
  - Bookshelf (`bookshelf_screen.dart`) - Display saved novels
  - Search (`search_screen.dart`) - Search for novels
  - Settings (`settings_screen.dart`) - App configuration
- **Additional Screens**:
  - `chapter_list_screen.dart` - Show all chapters for a novel
  - `reader_screen.dart` - Novel reading interface with AI features
  - `backend_settings_screen.dart` - Configure backend API endpoint

#### Data Layer

**Models (`lib/models/`)**
- `novel.dart` - Novel metadata (title, author, url, cover, description)
- `chapter.dart` - Chapter data with support for user-inserted chapters

**Services (`lib/services/`)**
- `database_service.dart` - SQLite database management with caching
- `backend_api_service.dart` - HTTP client for backend API
- `api_service_wrapper.dart` - Wrapper for auto-generated OpenAPI client
- `dify_service.dart` - AI integration via Dify workflows
- `cache_manager.dart` - Content caching coordination

### Backend API Structure

**Core Architecture:**
- FastAPI-based REST API
- Token-based authentication via `X-API-TOKEN` header
- Multi-site novel crawling with unified interface
- No database required (stateless service)

**Key Endpoints:**
- `/search` - Search novels across sources
- `/chapters` - Get chapter list for a novel
- `/chapter-content` - Get specific chapter content
- `/openapi.json` - OpenAPI specification for client generation

**Crawler System:**
- Pluggable crawler architecture for different novel sites
- Consistent API responses regardless of source
- Environment-based site enablement (`NOVEL_ENABLED_SITES`)

### Vue.js Frontend Structure

**Technology Stack:**
- Vue 3 with Composition API
- TypeScript for type safety
- Pinia for state management
- Vite for build tooling

**Key Features:**
- Web interface for novel browsing
- Responsive design
- Type-safe development

## Development Workflow

### Setting Up Development Environment

1. **Clone and Setup**
```bash
git clone <repository>
cd novel_builder
```

2. **Flutter App Setup**
```bash
cd novel_app
flutter pub get
dart run tool/generate_api.dart  # After backend is running
```

3. **Backend Setup**
```bash
cd backend
# Set environment variables:
export NOVEL_API_TOKEN=your_token_here
export NOVEL_ENABLED_SITES=site1,site2

# Install dependencies and run
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

4. **Frontend Setup**
```bash
cd frontend
npm install
npm run dev
```

### API Client Generation Workflow

When the backend API changes:

1. **Ensure backend is running** at `http://localhost:3800` with `/openapi.json` available
2. **Regenerate client code**: `dart run tool/generate_api.dart`
3. **Install dependencies**: `flutter pub get`
4. **Update wrapper**: Modify `lib/services/api_service_wrapper.dart` to use new generated methods
5. **Verify**: `flutter analyze`

### Docker Development

**Full Stack Development:**
```bash
# Start all services
docker-compose up -d

# View individual service logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

**Environment Configuration:**
Create `.env` file with:
```
NOVEL_API_TOKEN=your_api_token
NOVEL_ENABLED_SITES=site1,site2,site3
```

## Important Constraints

### Flutter App
1. **Never attempt to run the Flutter app** - Analysis only, no execution
2. **Always run `flutter analyze`** after making changes
3. **Do not commit generated code** - The `lib/generated/` directory is git-ignored
4. **Preserve user-inserted chapters** - When modifying database operations

### Backend
1. **Token required** - All API calls must include `X-API-TOKEN` header
2. **Stateless design** - No persistent storage required
3. **Unified interface** - All crawlers must return consistent response formats

### General
1. **Use type-safe clients** - Leverage OpenAPI generation for Flutter
2. **Environment-based configuration** - Use environment variables for deployment settings
3. **Docker-first deployment** - Services should be containerizable

## Configuration Management

### Flutter App SharedPreferences
- `backend_host` - Backend API URL
- `backend_token` - Optional API authentication token
- `dify_url` - Dify workflow API endpoint
- `dify_token` - Dify authentication token
- `ai_writer_prompt` - Custom AI writer settings/prompt

### Backend Environment Variables
- `NOVEL_API_TOKEN` - Required token for API access
- `NOVEL_ENABLED_SITES` - Comma-separated list of enabled crawling sites

## Code Generation and Build Exclusions

The following patterns are excluded from analysis (`analysis_options.yaml`):
- `lib/generated/**` - OpenAPI generated code
- `**/*.g.dart` - JSON serialization code
- `**/*.freezed.dart` - Freezed immutable classes

## Testing Strategy

### Flutter App
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for user flows
- Mock external dependencies (HTTP, database)

### Backend
- Unit tests for crawler logic
- Integration tests for API endpoints
- Mock external novel sites during testing

### Frontend
- Component unit tests
- E2E tests for user workflows
- Type checking via TypeScript

## Key Dependencies

### Flutter App
- `sqflite` - SQLite database
- `dio` - HTTP client for API calls
- `html` - HTML parsing
- `provider` - State management
- `shared_preferences` - Persistent storage
- `json_annotation` - JSON serialization

### Backend
- `fastapi` - Web framework
- `uvicorn` - ASGI server
- `requests` - HTTP client
- `beautifulsoup4` - HTML parsing
- `lxml` - XML/HTML parser

### Frontend
- `vue` - Frontend framework
- `typescript` - Type safety
- `pinia` - State management
- `vite` - Build tool

## Architecture

### Application Structure
- **Main Entry**: `lib/main.dart` - Sets up Material3 theme with dark mode default and bottom navigation
- **Screens**: Bottom nav with 3 main tabs:
  - Bookshelf (`bookshelf_screen.dart`) - Display saved novels
  - Search (`search_screen.dart`) - Search for novels
  - Settings (`settings_screen.dart`) - App configuration
- **Additional Screens**:
  - `chapter_list_screen.dart` - Show all chapters for a novel
  - `reader_screen.dart` - Novel reading interface with AI features
  - `backend_settings_screen.dart` - Configure backend API endpoint
  - `dify_settings_screen.dart` - Configure Dify AI integration

### Data Layer

#### Models (`lib/models/`)
- `novel.dart` - Novel metadata (title, author, url, cover, description)
- `chapter.dart` - Chapter data with support for:
  - `isCached` - Whether content is stored locally
  - `isUserInserted` - Distinguishes user-created chapters from source chapters
  - `chapterIndex` - Position in chapter list

#### Services (`lib/services/`)

**Database Service** (`database_service.dart`)
- Singleton pattern managing SQLite database
- Three tables:
  - `bookshelf` - User's saved novels with reading progress
  - `chapter_cache` - Cached chapter content
  - `novel_chapters` - Chapter list metadata
- Key features:
  - Batch caching for whole novels
  - User-inserted chapters preserved during updates
  - Automatic reordering of chapter indices
  - Cache statistics tracking

**Backend API Service** (`backend_api_service.dart`)
- HTTP client for novel content backend
- Configuration stored in SharedPreferences (host, optional token)
- Token sent via `X-API-TOKEN` header
- Endpoints: `/search`, `/chapters`, `/chapter-content`

**API Service Wrapper** (`api_service_wrapper.dart`)
- Wrapper for auto-generated OpenAPI client (from `lib/generated/api/`)
- Uses Dio with interceptors for auth and logging
- Must call `init()` before use
- **Note:** Business methods are commented out until API code is generated

**Dify Service** (`dify_service.dart`)
- Integrates with Dify AI workflows for content generation
- Supports both blocking and streaming response modes
- Used for "close-up" (特写) feature in reader
- Parses SSE (Server-Sent Events) format for streaming
- Configuration stored in SharedPreferences (url, token, ai_writer_prompt)

### Database Schema Details

**Version 2** (current) - Added user-inserted chapter support:
- `novel_chapters.isUserInserted` - Flag for user-created chapters
- `novel_chapters.insertedAt` - Timestamp of insertion

**Important Database Behaviors:**
- User-inserted chapters are preserved when updating chapter lists from source
- Chapter indices are automatically reordered to maintain consistency
- When inserting a user chapter, all subsequent chapters increment their index
- Cache clearing operations distinguish between content cache and metadata cache

### State Management
- Uses Provider package (see `pubspec.yaml`)
- Current implementation uses setState for local state
- SharedPreferences for persistent configuration

## Important Constraints

1. **Never attempt to run the Flutter app** - Analysis only, no execution
2. **Always run `flutter analyze`** after making changes
3. **Do not commit generated code** - The `lib/generated/` directory is git-ignored
4. **Preserve user-inserted chapters** - When modifying database operations, ensure `isUserInserted=1` chapters are never accidentally deleted

## Code Generation Files

The analyzer excludes these patterns (see `analysis_options.yaml`):
- `lib/generated/**` - OpenAPI generated code
- `**/*.g.dart` - JSON serialization code
- `**/*.freezed.dart` - Freezed immutable classes

## Configuration Management

All user settings are stored in SharedPreferences with these keys:
- `backend_host` - Backend API URL
- `backend_token` - Optional API authentication token
- `dify_url` - Dify workflow API endpoint
- `dify_token` - Dify authentication token
- `ai_writer_prompt` - Custom AI writer settings/prompt

## Development Workflow for API Changes

When the backend API changes:

1. Ensure backend is running at `http://localhost:3800` with `/openapi.json` available
2. Run `dart run tool/generate_api.dart` to regenerate client
3. Run `flutter pub get` to install any new dependencies
4. Update `lib/services/api_service_wrapper.dart` to:
   - Uncomment the generated API import
   - Uncomment the API instance initialization
   - Add/update business methods wrapping the generated API
5. Run `flutter analyze` to verify

## Testing Notes

- Main test file: `test/widget_test.dart`
- Tests should mock external dependencies (HTTP, database)
- When adding new services, create corresponding test files
- Use `setUp()` and `tearDown()` for test isolation

## Key Dependencies

- `sqflite` - SQLite database
- `http` / `dio` - HTTP clients (both used, consolidating to dio for generated code)
- `html` - HTML parsing for web crawling
- `provider` - State management
- `shared_preferences` - Persistent key-value storage
- `json_annotation` / `json_serializable` - JSON serialization
