#!/usr/bin/env python3
"""快速验证生成的词库是否可用。"""

import sqlite3, sys, os

DB = os.path.join(os.path.dirname(__file__), "dictionary-en.sqlite")

def check(db_path: str):
    if not os.path.exists(db_path):
        sys.exit(f"找不到 {db_path}，请先运行 build_dictionary.py")

    con = sqlite3.connect(db_path)
    total = con.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
    size_kb = os.path.getsize(db_path) // 1024

    probes = ["the", "apple", "run", "serendipity", "hello", "abandon"]
    print(f"词库：{db_path}  ({total} 词, {size_kb} KB)\n")
    print(f"{'单词':<16} {'freq_rank':<12} {'音标':<20} {'释义（中文，前60字）'}")
    print("-" * 80)
    for w in probes:
        row = con.execute(
            "SELECT freq_rank, phonetic, definition FROM entries WHERE word=?", (w,)
        ).fetchone()
        if row:
            rank     = str(row[0] or "—")
            phonetic = (row[1] or "—")[:18]
            defn     = (row[2] or "—").replace("\n", " ")[:60]
            print(f"{w:<16} {rank:<12} {phonetic:<20} {defn}")
        else:
            print(f"{w:<16} {'(未找到)'}")

    # 最高频前 5（rank 最小）
    print("\n最高频前 5（freq_rank 越小越常见）：")
    for row in con.execute(
        "SELECT word, freq_rank, definition FROM entries ORDER BY freq_rank ASC LIMIT 5"
    ):
        defn = (row[2] or "").replace("\n", " ")[:40]
        print(f"  {row[0]:<16} rank={row[1]:<8} {defn}")

    con.close()
    print("\n✅ 验证通过")

if __name__ == "__main__":
    check(DB)
