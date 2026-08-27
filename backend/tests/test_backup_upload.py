#!/usr/bin/env python3
"""
简单的备份上传功能测试脚本

测试POST /api/backup/upload端点的基本功能
"""

import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

# 创建测试用的.db文件
test_db_path = Path(__file__).parent / "backups" / "test_backup.db"

# 确保测试目录存在
test_db_path.parent.mkdir(parents=True, exist_ok=True)

# 创建一个简单的SQLite数据库文件
import sqlite3

conn = sqlite3.connect(test_db_path)
cursor = conn.cursor()

# 创建测试表
cursor.execute("""
    CREATE TABLE test (
        id INTEGER PRIMARY KEY,
        name TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
""")

# 插入测试数据
cursor.execute("INSERT INTO test (name) VALUES (?)", ("测试备份",))
cursor.execute("INSERT INTO test (name) VALUES (?)", ("测试数据2",))

conn.commit()
conn.close()

print(f"✅ 测试数据库文件已创建: {test_db_path}")
print(f"   文件大小: {test_db_path.stat().st_size} 字节")
print()
print("现在可以使用以下命令测试上传API:")
print(f'curl -X POST "http://localhost:3800/api/backup/upload" \\')
print(f'     -H "X-API-TOKEN: your-api-token" \\')
print(f'     -F "file=@{test_db_path}"')
