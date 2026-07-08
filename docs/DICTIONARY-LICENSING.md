# 词典数据授权与合规调研

> 日期:2026-07-08 · 状态:调研存档,供收费上架前决策参考
> ⚠️ 本文为基于公开信息的合规分析,**非法律意见**。收费上架前建议咨询知识产权律师。

## 背景

WordClip 是**收费**项目,内置离线词库随包分发。词典**数据**(而非代码)的授权链是否干净,直接关系收费分发的版权风险。本文调研当前词源 ECDICT 的风险,并评估可商用替代词源的质量。

## 核心结论

1. **ECDICT 的 MIT 只覆盖代码,不覆盖词典数据。** ECDICT 仓库标注 MIT,但其 README 未对**数据**单独声明协议;数据来源东拼西凑(`cdict-1.0-1.rpm`、《屌丝字典》英汉部分、网友贡献、BNC/WordNet 语料),其中部分中文释义的原始来源可能可追溯到受版权保护的商业词典——这是中文英汉词库生态的普遍历史问题。
2. **市面上不存在「协议明确可商用 + 数据来源透明 + 完整英汉释义」的开源英汉词库。** 所有候选都在"协议"或"来源"上有取舍。
3. **务实选择**:独立收费 App 通常在「留 ECDICT + 合规标注」与「采购商业授权($10k–100k+/年)」之间权衡;彻底消除风险只有后者。

## 替代词源对比

评估维度(针对本项目场景:英语学习 · 中文用户 · 需英→中释义 + 音标 · 收费商业分发):

| 词源 | 适用性 | 英→中释义 | 音标 | 协议 | 收费项目的坑 |
|------|--------|-----------|------|------|-------------|
| **ECDICT**(现用) | 🎯 最佳可用 | ✅ 完整 | ✅ 有 | MIT(仅代码) | 数据来源不透明,释义或含商业词典 |
| **CC-CEDICT** | ❌ 不适合 | 方向反(汉→英) | ❌ 仅拼音 | CC BY-SA 4.0 | 方向不对 + ShareAlike 传染 |
| **Wiktionary / Kaikki** | 🟡 勉强 | ⚠️ 覆盖 30–60% | ✅ 多数有 | CC BY-SA | 需 3–5 天清洗;SA 需"集合作品"模式规避 |
| **WordNet + 中文(COW/CWN)** | 🟡 勉强 | ⚠️ COW 仅 36% | ❌ 无 IPA | ✅ 最干净(PWN BSD / OEWN MIT / COW CC-BY) | 缺音标 + 中文不全,要多源拼(CWN 覆盖 99.99% 但无商用许可,需规避) |

### 三角权衡(不可兼得)

- **协议最干净** → WordNet 系(BSD/MIT,可商用无传染)——但缺音标、中文映射不全,要拼 COW + ipa-dict + 人工,工程量大、质量降级。
- **释义质量最好** → ECDICT(现状)——但来源不透明,MIT 仅给法律上的挡箭牌,未真正消除风险。
- **完全免费社区** → Wiktionary——但中文覆盖仅 30–60%,英语学习者约一半词查不到中文,体验硬伤。

## 各候选要点

### ECDICT(现用)
- MIT 承诺商用权(法律上有意义的挡箭牌,但不覆盖数据来源问题)。
- 260–432 万条目、含音标、中英释义,质量充足,社区活跃。
- 风险:数据溯源非官方透明。

### CC-CEDICT
- 汉→英词典,词条以中文为主键;查英文词给中文需自建倒排索引,非原生设计。
- 124k 中文词条;仅拼音无 IPA;无词性/例句。
- CC BY-SA 4.0:允许商用但 ShareAlike 传染性强(衍生数据库须开源),与闭源收费冲突。

### Wiktionary / Kaikki
- 英→中 translations 存在但覆盖 30–60%;~100–200 万高质量词条;多数有 IPA;例句极少。
- Kaikki 提供 JSONL 导出(压缩 ~2.6GB),转 SQLite 需 3–5 天清洗(社区编辑噪声)。
- CC BY-SA:保持原样展示、按"集合作品"模式 + 署名可合法商用,避免"改编"触发 SA。

### WordNet + 中文
- PWN 3.0 (BSD) / OEWN (MIT) 协议最干净、可商用无传染;OEWN 现成 SQLite ~147k 词。
- 短板:无 IPA 音标(需外接 ipa-dict / TTS);中文映射不完整——COW(CC-BY)仅覆盖 36%,CWN 覆盖 99.99% 但无官方商用许可(需向台湾大学书面授权,建议规避)。

## 后续可选路径

- **想彻底消除风险** → 采购商业词库授权(牛津 / 剑桥等)。对独立收费 App 通常不现实。
- **接受可控风险(务实)** → 留 ECDICT,做合规动作:App 内 + `data/README` 明确标注数据来源与"MIT 覆盖代码、数据来源见上游"的事实,不宣称数据本身 MIT。
- **长期理想** → 若有资源,基于 WordNet(OEWN MIT)+ 自建/众包中文释义 + ipa-dict 音标,构建来源完全透明的自有词库——工程量大,但一劳永逸。

## 参考来源

- ECDICT: https://github.com/skywind3000/ECDICT
- CC-CEDICT: https://cc-cedict.org/wiki/
- Wiktionary / Kaikki: https://kaikki.org/dictionary/rawdata.html
- Princeton WordNet: https://wordnet.princeton.edu/license-and-commercial-use
- Open Multilingual WordNet: https://omwn.org/
- Chinese Open Wordnet (COW): https://github.com/bond-lab/cow
- ipa-dict: https://github.com/open-dict-data/ipa-dict
