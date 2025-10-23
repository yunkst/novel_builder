# Novel Builder Backend

FastAPI backend service for novel crawling and management with multi-site support.

## 🚀 Features

- **Multi-site novel crawling** - Support for multiple novel websites
- **Unified API interface** - Consistent response format regardless of source
- **Token-based authentication** - Secure API access
- **Real-time content fetching** - On-demand chapter content retrieval
- **Modern Python project structure** - Using pyproject.toml for dependency management

## 📋 Prerequisites

- Python 3.11+
- Docker & Docker Compose (for containerized deployment)
- Git

## 🛠️ Development Setup

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd novel-builder/backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   # Install production dependencies
   pip install -e .

   # Install development dependencies
   pip install -e ".[dev]"
   ```

4. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run pre-commit setup**
   ```bash
   pre-commit install
   ```

6. **Run the development server**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

### Docker Development

1. **Build and run with Docker Compose**
   ```bash
   docker-compose up --build
   ```

2. **Run tests in Docker**
   ```bash
   docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
   ```

## 🧪 Testing

### Run All Tests
```bash
pytest
```

### Run Tests with Coverage
```bash
pytest --cov=app --cov-report=html
```

### Run Specific Test File
```bash
pytest tests/test_main.py
```

### Run Tests by Marker
```bash
pytest -m unit        # Unit tests only
pytest -m integration # Integration tests only
```

## 🔍 Code Quality

### Static Analysis
```bash
# Run all checks
ruff check .          # Fast linting and formatting
pylint app/           # Deep code quality check
mypy app/             # Static type checking

# Format code
ruff format .         # Auto-format with ruff
black .               # Alternative formatter
isort .               # Sort imports
```

### Pre-commit Hooks
The project uses pre-commit hooks to ensure code quality. They will run automatically before each commit.

To run them manually:
```bash
pre-commit run --all-files
```

## 📁 Project Structure

```
backend/
├── app/                    # Application code
│   ├── api/               # API route handlers
│   ├── core/              # Core application logic
│   ├── models/            # Database models
│   ├── schemas/           # Pydantic models
│   ├── services/          # Business logic services
│   ├── deps/              # Dependencies (auth, etc.)
│   └── main.py           # FastAPI application entry point
├── tests/                 # Test files
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── conftest.py       # Test configuration
├── pyproject.toml         # Project configuration and dependencies
├── Dockerfile            # Production Docker image
├── docker-compose.yml    # Development environment
├── docker-compose.test.yml # Test environment
├── .env.example          # Environment variables template
├── .pre-commit-config.yaml # Pre-commit hooks configuration
└── README.md             # This file
```

## 🔧 Configuration

### Environment Variables

Key environment variables (see `.env.example`):

- `NOVEL_API_TOKEN`: API authentication token (required)
- `NOVEL_ENABLED_SITES`: Comma-separated list of enabled crawler sites
- `SECRET_KEY`: JWT secret key for authentication
- `DEBUG`: Enable debug mode

### Adding New Crawlers

1. Create a new crawler class in `app/services/crawlers/`
2. Inherit from `BaseCrawler`
3. Implement required methods (`search`, `get_chapters`, `get_chapter_content`)
4. Register in `crawler_factory.py`
5. Add to `NOVEL_ENABLED_SITES` environment variable

## 📚 API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

### Authentication

All API endpoints require `X-API-TOKEN` header:
```
X-API-TOKEN: your-api-token-here
```

### Main Endpoints

- `GET /health` - Health check
- `GET /search` - Search novels across enabled sites
- `GET /chapters` - Get chapter list for a novel
- `GET /chapter-content` - Get specific chapter content

## 🚀 Deployment

### Production Docker Build
```bash
docker build -t novel-backend .
docker run -p 8000:8000 --env-file .env novel-backend
```

### Using Docker Compose (Production)
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and code quality checks
5. Submit a pull request

### Code Style

This project follows:
- **PEP 8** for Python code style
- **Black** for code formatting (line length: 88)
- **Ruff** for fast linting
- **MyPy** for type checking
- **PyLint** for deep code analysis

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔍 Troubleshooting

### Common Issues

1. **Import errors**: Make sure you're in the virtual environment
2. **Permission denied**: Check Docker permissions or use `sudo`
3. **Port already in use**: Change port in docker-compose.yml or stop conflicting services
4. **Tests failing**: Check environment variables and dependencies

### Getting Help

- Check the [Issues](../../issues) page
- Read the [Documentation](../../wiki)
- Create a new issue with detailed information