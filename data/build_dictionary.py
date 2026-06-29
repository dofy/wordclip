#!/usr/bin/env python3
"""
ECDICT → WordClip SQLite 词库构建脚本

用法:
    python3 build_dictionary.py              # 下载 + 构建（默认输出 dictionary-en.sqlite）
    python3 build_dictionary.py --top 50000  # 只保留词频前 5 万词
    python3 build_dictionary.py --no-download # 跳过下载，直接用已有的 ecdict.db

输出:
    dictionary-en.sqlite   词库文件（随 App 分发，放入 Xcode 工程 Resources）
    build.log              构建日志

ECDICT 来源: https://github.com/skywind3000/ECDICT  (MIT)
"""

import argparse
import logging
import os
import sqlite3
import sys
import urllib.request
import zipfile

ECDICT_URL = "https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-sqlite-28.zip"
ZIP_FILENAME = "ecdict-sqlite.zip"
SOURCE_DB = "ecdict.db"          # zip 内的 SQLite 文件名
OUTPUT_DB = "dictionary-en.sqlite"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(), logging.FileHandler("build.log")],
)
log = logging.getLogger(__name__)

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS entries (
    id            INTEGER PRIMARY KEY,
    word          TEXT NOT NULL,
    lemma         TEXT,
    phonetic      TEXT,
    definition    TEXT,       -- 中文释义
    definition_en TEXT,       -- 英英释义
    pos           TEXT,
    exchange      TEXT,       -- 变形（ECDICT 原始格式）
    freq_rank     INTEGER DEFAULT 999999
    -- freq_rank 越小越常见（BNC/COCA 排名制）：the=1, apple≈2446, serendipity≈23000
    -- 查询「常用词」用 ORDER BY freq_rank ASC
);
CREATE INDEX IF NOT EXISTS idx_word      ON entries(word);
CREATE INDEX IF NOT EXISTS idx_lemma     ON entries(lemma);
CREATE INDEX IF NOT EXISTS idx_freq_rank ON entries(freq_rank ASC);
"""


def download(url: str, dest: str):
    if os.path.exists(dest):
        log.info("已存在 %s，跳过下载", dest)
        return
    log.info("下载 %s ...", url)

    def progress(block_num, block_size, total_size):
        downloaded = block_num * block_size
        if total_size > 0:
            pct = min(downloaded * 100 // total_size, 100)
            mb_done = downloaded // 1024 // 1024
            mb_total = total_size // 1024 // 1024
            print(f"\r  {pct}%  {mb_done}MB / {mb_total}MB", end="", flush=True)

    urllib.request.urlretrieve(url, dest, reporthook=progress)
    print()
    log.info("下载完成 → %s", dest)


def extract(zip_path: str, target_db: str):
    if os.path.exists(target_db):
        log.info("已存在 %s，跳过解压", target_db)
        return
    log.info("解压 %s ...", zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        db_entries = [n for n in zf.namelist() if n.lower().endswith((".db", ".sqlite"))]
        if not db_entries:
            sys.exit("zip 中找不到 .db / .sqlite 文件")
        zf.extract(db_entries[0], ".")
        extracted = db_entries[0]
        if os.path.basename(extracted) != target_db:
            os.rename(extracted, target_db)
    log.info("解压完成 → %s", target_db)


def lemma_from_exchange(exchange: str) -> str | None:
    """从 ECDICT exchange 字段提取原形。格式：p:ran/d:ran/i:running/0:run"""
    if not exchange:
        return None
    for part in exchange.split("/"):
        if part.startswith("0:"):
            return part[2:].strip().lower()
    return None


def build(source_db: str, output_db: str, top: int | None):
    log.info("读取源库 %s ...", source_db)
    src = sqlite3.connect(source_db)

    # 探查源库表结构
    tables = [r[0] for r in src.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    log.info("源库表：%s", tables)

    # ECDICT SQLite 表名通常是 stardict
    tbl = "stardict" if "stardict" in tables else tables[0]
    cols = [r[1] for r in src.execute(f"PRAGMA table_info({tbl})").fetchall()]
    log.info("列：%s", cols)

    # 词频字段：frq 或 bnc（越小越常见，取较小的非零值；0 表示未知，用大数填充）
    has_frq = "frq" in cols
    has_bnc = "bnc" in cols

    if has_frq and has_bnc:
        freq_expr = """
            CASE
                WHEN (frq = 0 OR frq IS NULL) AND (bnc = 0 OR bnc IS NULL) THEN 999999
                WHEN (frq = 0 OR frq IS NULL) THEN bnc
                WHEN (bnc = 0 OR bnc IS NULL) THEN frq
                ELSE MIN(frq, bnc)
            END
        """
    elif has_frq:
        freq_expr = "CASE WHEN frq = 0 OR frq IS NULL THEN 999999 ELSE frq END"
    elif has_bnc:
        freq_expr = "CASE WHEN bnc = 0 OR bnc IS NULL THEN 999999 ELSE bnc END"
    else:
        freq_expr = "999999"

    query = f"""
        SELECT
            word,
            {'phonetic' if 'phonetic' in cols else 'NULL'},
            {'translation' if 'translation' in cols else 'NULL'},
            {'definition' if 'definition' in cols else 'NULL'},
            {'pos' if 'pos' in cols else 'NULL'},
            {'exchange' if 'exchange' in cols else 'NULL'},
            ({freq_expr}) AS freq_rank
        FROM {tbl}
        WHERE word IS NOT NULL AND word != ''
        ORDER BY freq_rank ASC    -- 越小越常见，取前 top 最高频词
        {f'LIMIT {top}' if top else ''}
    """

    rows_src = src.execute(query).fetchall()
    src.close()
    log.info("读取 %d 条原始词条", len(rows_src))

    if os.path.exists(output_db):
        os.remove(output_db)

    dst = sqlite3.connect(output_db)
    dst.executescript(CREATE_TABLE)

    insert_rows = []
    for (word, phonetic, translation, definition, pos, exchange, freq_rank) in rows_src:
        word = (word or "").strip().lower()
        if not word:
            continue
        insert_rows.append((
            word,
            lemma_from_exchange(exchange or ""),
            (phonetic or "").strip() or None,
            (translation or "").strip() or None,
            (definition or "").strip() or None,
            (pos or "").strip() or None,
            (exchange or "").strip() or None,
            int(freq_rank or 999999),
        ))

    dst.executemany(
        "INSERT INTO entries(word,lemma,phonetic,definition,definition_en,pos,exchange,freq_rank) "
        "VALUES(?,?,?,?,?,?,?,?)",
        insert_rows,
    )
    dst.commit()

    count = dst.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
    size_kb = os.path.getsize(output_db) // 1024
    dst.close()

    log.info("完成：%d 词条，%d KB → %s", count, size_kb, output_db)
    print(f"\n✅ 词库已生成：{output_db}（{count} 词，{size_kb} KB）")


def main():
    parser = argparse.ArgumentParser(description="构建 WordClip 英语离线词库")
    parser.add_argument("--top", type=int, default=None, help="保留词频前 N 词（默认全量）")
    parser.add_argument("--no-download", action="store_true", help="跳过下载，直接用本地 ecdict.db")
    parser.add_argument("--output", default=OUTPUT_DB, help=f"输出文件名（默认 {OUTPUT_DB}）")
    args = parser.parse_args()

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    if not args.no_download:
        download(ECDICT_URL, ZIP_FILENAME)
        extract(ZIP_FILENAME, SOURCE_DB)

    if not os.path.exists(SOURCE_DB):
        sys.exit(f"找不到 {SOURCE_DB}，请先运行不带 --no-download 的版本")

    build(SOURCE_DB, args.output, args.top)


if __name__ == "__main__":
    main()
