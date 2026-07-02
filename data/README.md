# data — 词库构建

这个目录包含离线词库的构建脚本。**原始数据文件（CSV / zip）和生成的 SQLite 不入库**（已在 `.gitignore` 中排除）；每次构建时由脚本拉取并生成。

## 文件说明

| 文件 | 说明 |
|------|------|
| `build_dictionary.py` | 下载 ECDICT → 裁剪字段 → 生成 `dictionary-en.sqlite` |
| `verify_dictionary.py` | 快速验证生成的词库（抽查词条、词频、文件大小） |
| `dictionary-en.sqlite` | **构建产物，不入库**，构建后复制到 Xcode 工程的 Resources |

## 快速开始

```bash
cd data/

# 完整构建（~77 万词，约 80 MB）
python3 build_dictionary.py

# 只保留词频前 5 万词（约 8 MB，适合 App bundle 分发）
python3 build_dictionary.py --top 50000

# 验证生成结果
python3 verify_dictionary.py
```

## 词库来源

[ECDICT](https://github.com/skywind3000/ECDICT) — MIT 协议，约 77 万英语词条，包含：
- 中文释义（`translation`）
- 英英释义（`definition`）
- IPA 音标（`phonetic`）
- 词性（`pos`）
- 词频（BNC / COCA）
- 变形（复数、过去式、比较级等）

## 关于词库体积

| 版本 | 词条数 | 大小（估算） | 适用场景 |
|------|--------|-------------|---------|
| 全量 | ~77 万 | ~80 MB | 不适合直接打包进 App |
| top 10 万 | 10 万 | ~12 MB | 覆盖绝大多数常用词，推荐 |
| top 5 万 | 5 万 | ~6 MB | 精简包，适合 App bundle |

建议 App 默认打包 top 5–10 万词，完整词库可按需下载。

## 作为「自定义词典」导入 App

脚本产出的 SQLite 就是 App 导入器认的 `entries` 表结构，可直接在 **设置 → 词典 → 导入词典…** 里选中导入，叠加在内置 5 万词之上：

```bash
python3 build_dictionary.py --output ecdict-full.sqlite      # 全量 ~77 万词
python3 build_dictionary.py --top 100000 --output ecdict-100k.sqlite   # 或高频 10 万词（体积更小，适合 iOS）
```

> ⚠️ ECDICT **原生** 的 `ecdict.db`（表名 `stardict`、中文在 `translation` 列）**不能**直接被 App 导入，必须先经本脚本转成 `entries` 结构。

## 添加新语言

新增一个 `build_dictionary_ja.py`（日语，使用 JMdict），遵循相同的 SQLite schema 输出 `dictionary-ja.sqlite`，即可配合 `LanguagePack` 协议接入 App。
