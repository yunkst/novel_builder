FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 安装运行依赖
RUN pip install --no-cache-dir fastapi uvicorn[standard] requests beautifulsoup4 lxml urllib3

# 复制应用代码
COPY ./app ./app

EXPOSE 8000

# 启动服务
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]