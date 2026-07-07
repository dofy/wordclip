#!/usr/bin/env python3
"""从完整 ECDICT(data/ecdict.db)构建懒人词包 JSON。

分级包:按 tag 全量筛,词频升序。
场景包:读 data/wordpacks/<slug>.txt(一行一词),用 ECDICT 补全释义,词频升序。
产物写到 WordClip/Resources/wordpacks/pack-<slug>.json。
"""
import json
import os
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "ecdict.db")
OUT_DIR = os.path.join(HERE, "..", "WordClip", "Resources", "wordpacks")
WORDLIST_DIR = os.path.join(HERE, "wordpacks")

# 分级包:slug -> (显示名, ECDICT tag, SF Symbol)
LEVEL_PACKS = [
    ("beginner", "初学者(中考)", "zk", "leaf"),
    ("gaokao",   "高考",         "gk", "graduationcap"),
    ("cet4",     "CET-4",        "cet4", "book"),
    ("cet6",     "CET-6",        "cet6", "books.vertical"),
    ("kaoyan",   "考研",         "ky", "pencil.and.ruler"),
    ("toefl",    "托福 TOEFL",   "toefl", "airplane.circle"),
    ("ielts",    "雅思 IELTS",   "ielts", "globe"),
    ("gre",      "GRE",          "gre", "brain"),
]

# 场景包:slug -> (显示名, SF Symbol);词表来自 wordpacks/<slug>.txt
SCENE_PACKS = [
    ("daily",       "日常生活",       "house"),
    ("travel",      "旅游娱乐",       "airplane"),
    ("programming", "程序员/技术文档", "chevron.left.forwardslash.chevron.right"),
    ("business",    "商务职场",       "briefcase"),
]

SCENE_MAX = 500  # 场景包上限


def row_to_word(row):
    word, phonetic, translation, definition_en = row
    return {
        "headword": word,
        "lemma": word.lower(),
        "definition": translation or None,
        "definitionEn": definition_en or None,
        "phonetic": phonetic or None,
    }


def build_level(conn, slug, name, tag, icon):
    cur = conn.execute(
        """SELECT word, phonetic, translation, definition
           FROM stardict
           WHERE (' '||tag||' ') LIKE ?
           ORDER BY CASE WHEN frq>0 THEN frq ELSE 999999 END ASC, word ASC""",
        (f"% {tag} %",),
    )
    words = [row_to_word(r) for r in cur.fetchall()]
    return {"slug": slug, "name": name, "icon": icon, "kind": "pack",
            "version": 1, "language": "en", "words": words}


def build_scene(conn, slug, name, icon):
    path = os.path.join(WORDLIST_DIR, f"{slug}.txt")
    with open(path, encoding="utf-8") as f:
        lemmas = [ln.strip().lower() for ln in f if ln.strip() and not ln.startswith("#")]
    # 去重保序
    seen, ordered = set(), []
    for l in lemmas:
        if l not in seen:
            seen.add(l); ordered.append(l)
    words = []
    for lemma in ordered:
        cur = conn.execute(
            "SELECT word, phonetic, translation, definition FROM stardict WHERE word=? COLLATE NOCASE LIMIT 1",
            (lemma,),
        )
        row = cur.fetchone()
        if row:
            words.append(row_to_word(row))
        else:
            words.append({"headword": lemma, "lemma": lemma,
                          "definition": None, "definitionEn": None, "phonetic": None})
    words = words[:SCENE_MAX]
    return {"slug": slug, "name": name, "icon": icon, "kind": "pack",
            "version": 1, "language": "en", "words": words}


def main():
    if not os.path.exists(DB):
        sys.exit(f"找不到 {DB};请先在 data/ 下准备完整 ECDICT。")
    os.makedirs(OUT_DIR, exist_ok=True)
    conn = sqlite3.connect(DB)

    for slug, name, tag, icon in LEVEL_PACKS:
        pack = build_level(conn, slug, name, tag, icon)
        out = os.path.join(OUT_DIR, f"pack-{slug}.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False)
        print(f"{slug}: {len(pack['words'])} 词 -> {out}")

    for slug, name, icon in SCENE_PACKS:
        pack = build_scene(conn, slug, name, icon)
        out = os.path.join(OUT_DIR, f"pack-{slug}.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False)
        print(f"{slug}: {len(pack['words'])} 词 -> {out}")

    conn.close()


if __name__ == "__main__":
    main()
