# 数据库锁定实验 - 文档索引

## 🚀 快速开始

**新用户?** 请先阅读: [QUICKSTART.md](./QUICKSTART.md)

**立即运行实验**:
- Windows: `run_experiment.bat`
- Linux/macOS: `./run_experiment.sh`

---

## 📚 文档列表

### 必读文档

1. **[QUICKSTART.md](./QUICKSTART.md)** ⭐ 推荐首读
   - 快速开始指南
   - 一键运行命令
   - 快速判断结果

2. **[README.md](./README.md)**
   - 完整使用指南
   - 详细实验说明
   - 常见问题解答

3. **[PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)**
   - 项目概述
   - 文件清单
   - 下一步行动

### 参考文档

4. **[STRUCTURE.txt](./STRUCTURE.txt)**
   - 目录结构说明
   - 文件组织方式
   - 快速参考

5. **[EXPERIMENT_REPORT_TEMPLATE.md](./EXPERIMENT_REPORT_TEMPLATE.md)**
   - 实验报告模板
   - 结果记录表格
   - 分析方法说明

6. **[EXAMPLE_REPORT.md](./EXAMPLE_REPORT.md)**
   - 示例实验报告
   - 预期结果展示
   - 最佳实践建议

---

## 🛠️ 实验文件

### 核心代码

**[database_lock_experiment.dart](./database_lock_experiment.dart)**
- 主要实验代码
- 4个方案 × 3个测试 = 12个测试用例
- 系统性验证隔离方案

### 运行脚本

**[run_experiment.sh](./run_experiment.sh)**
- Linux/macOS运行脚本
- 自动化实验流程
- 生成测试报告

**[run_experiment.bat](./run_experiment.bat)**
- Windows运行脚本
- 自动化实验流程
- 生成测试报告

### 分析工具

**[analyze_experiment_results.py](./analyze_experiment_results.py)**
- Python结果分析脚本
- 自动生成对比表格
- 给出推荐方案

---

## 📊 输出目录

### reports/

实验报告输出目录,包含:

- `experiment_report_YYYYMMDD_HHMMSS.txt` - 原始测试输出
- `experiment_report_YYYYMMDD_HHMMSS_analysis.txt` - 分析后的报告

---

## 🎯 使用流程

```
1. 阅读 QUICKSTART.md
   ↓
2. 运行 run_experiment.sh/bat
   ↓
3. 查看 reports/experiment_report_*.txt
   ↓
4. (可选) 运行 analyze_experiment_results.py
   ↓
5. 参考 EXPERIMENT_REPORT_TEMPLATE.md 填写报告
   ↓
6. 应用推荐方案到测试
```

---

## 📖 按需阅读

### 我想要...

**快速了解实验**
→ 阅读 [QUICKSTART.md](./QUICKSTART.md)

**深入了解原理**
→ 阅读 [README.md](./README.md)

**查看实验代码**
→ 阅读 [database_lock_experiment.dart](./database_lock_experiment.dart)

**填写实验报告**
→ 参考 [EXPERIMENT_REPORT_TEMPLATE.md](./EXPERIMENT_REPORT_TEMPLATE.md)

**查看示例报告**
→ 阅读 [EXAMPLE_REPORT.md](./EXAMPLE_REPORT.md)

**分析实验结果**
→ 运行 [analyze_experiment_results.py](./analyze_experiment_results.py)

**了解文件结构**
→ 阅读 [STRUCTURE.txt](./STRUCTURE.txt)

**项目整体概览**
→ 阅读 [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)

---

## 🔍 关键概念

### 实验方案

| 方案 | 描述 | 推荐指数 |
|------|------|----------|
| 方案1 | DatabaseService单例 | ⭐ (不推荐) |
| 方案2 | DatabaseTestBase包装类 | ⭐⭐⭐⭐ |
| 方案3 | 纯内存数据库 | ⭐⭐⭐⭐⭐ |
| 方案4 | 独立数据库实例 | ⭐⭐⭐⭐⭐ |

### 预期结果

| 方案 | 测试1 | 测试2 | 测试3 | 有锁冲突? |
|------|-------|-------|-------|-----------|
| 方案1 | ❌ | ❌ | ❌ | 是 |
| 方案2 | ✅ | ✅ | ✅ | 否 |
| 方案3 | ✅ | ✅ | ✅ | 否 |
| 方案4 | ✅ | ✅ | ✅ | 否 |

---

## 💡 快速命令

### Windows

```cmd
# 运行实验
cd novel_app\test\experiments
run_experiment.bat

# 查看报告
type reports\experiment_report_*.txt

# 分析结果
python3 analyze_experiment_results.py reports\experiment_report_*.txt
```

### Linux/macOS

```bash
# 运行实验
cd novel_app/test/experiments
./run_experiment.sh

# 查看报告
cat reports/experiment_report_*.txt

# 分析结果
python3 analyze_experiment_results.py reports/experiment_report_*.txt
```

---

## 📞 获取帮助

### 常见问题

**Q: 实验运行失败?**
→ 查看 [README.md](./README.md) 的常见问题部分

**Q: 如何理解实验结果?**
→ 查看 [EXAMPLE_REPORT.md](./EXAMPLE_REPORT.md) 的示例

**Q: 如何应用方案?**
→ 查看 [QUICKSTART.md](./QUICKSTART.md) 的应用示例

**Q: 实验原理是什么?**
→ 查看 [README.md](./README.md) 的技术细节部分

---

## ✅ 检查清单

实验前:
- [ ] 已阅读 QUICKSTART.md
- [ ] 已安装 Flutter 环境
- [ ] 已了解实验目的

实验中:
- [ ] 成功运行实验脚本
- [ ] 查看测试输出
- [ ] 记录实验结果

实验后:
- [ ] 分析实验结果
- [ ] 填写实验报告
- [ ] 应用推荐方案

---

**文档版本**: 1.0.0
**最后更新**: 2026-02-02
**维护者**: AI Assistant
