# 编码任务派发模板(TASK TEMPLATE)

> 用途:向 Claude(或任何 agent)派发 seekcode 编码任务的标准格式。收到符合本模板的任务后,执行入口一律是 `/implement-spec`;字段缺省时按「缺省值」列处理。
> 非规范性文档(宪章 7.1)——流程约束本体在宪章第 3/4 章与 `/implement-spec` skill。

## 模板(复制填写)

```text
/implement-spec <SPEC-0xx 或 docs/specs/ 路径>

范围     :AC-_, AC-_(本次实现哪些验收标准)
排除     :AC-_,原因:____(明确不做的及理由)
红-绿    :测试名 specNNN_acM_*;先跑出红并存证,再实现
验收命令 :________(spec 未声明专门命令时 = cargo test specNNN)
边界提醒 :不触碰 F_/D_(如本任务贴近某禁区,点名它)
附加约束 :________(如"不新增依赖""只动 seek-router")
```

## 字段说明

| 字段 | 必填 | 缺省值 | 说明 |
|---|---|---|---|
| SPEC 引用 | ✅ | — | 必须是 `docs/specs/` 已存在的 spec;没有 spec 的想法先走宪章 3.1 立 spec,不接受"顺手实现" |
| 范围 | ❌ | 该 spec 全部 AC | 按 AC 编号圈定;跨多个 spec 的任务拆成多次派发 |
| 排除 | ❌ | 无 | 写明理由,避免被误解为遗漏 |
| 红-绿 | ❌ | 模板所示约定 | 红证据自动存 `.claude/tdd-evidence/SPEC-0xx-<日期>-red.txt` |
| 验收命令 | ❌ | `cargo test specNNN` | 最终以 commit-gate 全量把关,此处是任务级判据 |
| 边界提醒 | ❌ | 无 | F1–F4 / D1–D6 有 future-guard 词表兜底,但点名可减少无效尝试 |
| 附加约束 | ❌ | 无 | 与宪章冲突的附加约束无效——宪章优先 |

## 示例

**最小派发(全部缺省):**

```text
/implement-spec SPEC-003
```

**完整派发:**

```text
/implement-spec SPEC-008

范围     :AC-1, AC-2, AC-4
排除     :AC-3(R4 升档链依赖 SPEC-002 的 failed_attempts 计数,等其先合入)
红-绿    :测试名 spec008_acM_*;先红后绿
验收命令 :cargo test spec008 && cargo test --test anticorruption_single_router
边界提醒 :规则表数据驱动,不写死模型名(宪章 5.2);收益话术不进代码注释(F1)
附加约束 :只动 seek-router 与 seek-config,不碰 kernel
```

## 完成定义(所有任务统一,不随任务变)

1. 圈定的 AC 逐条勾销(未做的如实列为"本次未做");
2. `/implement-spec` 第 6 步宪章自查 6 项全过;
3. 红证据已入 `.claude/tdd-evidence/`;
4. `git commit` 通过 commit-gate(fmt/clippy/test/覆盖率/分层/治理组/spec↔test)。
