---
name: implement-spec
description: 按宪章 SDD/TDD 流程实现一个 spec:载入 spec → 写失败测试并确认红(留痕)→ 最小实现至绿 → 重构 → 跑验收命令 → 宪章自查。seekcode 所有编码任务的唯一入口。
disable-model-invocation: true
argument-hint: [SPEC-0xx 或 docs/specs/ 路径]
---

# /implement-spec —— spec 驱动的编码任务流程

按以下步骤执行,**顺序不可颠倒,步骤不可跳过**(宪章 3.1/4.1)。用 TodoWrite 为每个步骤建条目,逐步推进。

目标 spec:`$ARGUMENTS`

## 第 0 步:载入并核验 spec

1. 解析参数:若形如 `SPEC-0xx`,glob `docs/specs/SPEC-0xx-*.md`;否则按路径读取。找不到 → **停**,报告用户。
2. 通读 spec,同时读 `docs/report_v2.md` 对应章节核对无冲突。
3. 核验资格:该条目不属于 FUTURE.md(F 系列)且不超出 report_v2 §9 的 D 系列"裁定前行为"。违反 → **停**,告知用户需先走毕业/裁定流程。
4. spec 的 AC(验收标准)如有含糊到写不出测试的项 → **停**,建议先派 spec-reviewer 评审,不要带着坏 spec 硬写。

## 第 1 步:圈定本次范围

列出 spec 的全部 AC,与用户确认(或按参数指示)本次实现哪些 AC。逐条 AC 写入 TodoWrite。

## 第 2 步:写失败测试并确认红(宪章 4.1,核心步骤)

1. 按 AC 写测试,命名遵循 `specNNN_acM_描述`(如 `spec003_ac2_reject_parent_traversal`),放入对应 crate 的 `tests/` 或 `#[cfg(test)]` 模块。
2. **运行测试,必须亲眼确认失败**:`cargo test specNNN --no-fail-fast 2>&1`。
3. 把失败输出存为红证据:写入 `.claude/tdd-evidence/SPEC-0xx-<日期>-red.txt`(含完整 cargo test 输出)。此文件入库,tdd-guard 与 CI 依赖它。
4. **若测试直接通过 → 停**:要么测试无效(没测到新行为),要么行为已存在(不该重复实现)。回到 spec 分析,不许直接进第 3 步。

## 第 3 步:最小实现至绿

1. 写**最小**实现让红测试转绿,不做超出本次 AC 范围的功能。
2. 每个新增跨 crate `pub` 项的 rustdoc 首行写 `/// Spec: SPEC-0xx`(spec-anchor-check hook 会拦缺失)。
3. 阈值/魔法数字一律从配置读取,引用 report_v2 §10 参数名(T1/T2/P1–P6/N)。
4. `cargo test` 全绿后才进下一步。

## 第 4 步:重构

1. 在测试保护下整理实现:去重、命名、模块归位(对照 ARCHITECTURE §1.1——逻辑放对 crate)。
2. **不改测试语义**:断言值不许动;动了就是行为变更,回到第 2 步。
3. 重跑 `cargo test` 确认仍绿。

## 第 5 步:验收

1. 跑 spec 声明的验收命令(通常 `cargo test` 全量;spec 有专门命令则用之)。
2. `cargo fmt` + `cargo clippy --all-targets -- -D warnings` 清零。
3. 逐条勾销第 1 步的 AC 清单;未覆盖的 AC 如实报告为"本次未做"。

## 第 6 步:宪章自查(提交前)

对照回答并在总结中列出:

- [ ] 所有新 `pub` 项带 `Spec: SPEC-0xx` 锚点?
- [ ] 无 `unwrap/expect/panic!/todo!/unimplemented!`(或豁免格式 `expect("invariant: ...")`)?
- [ ] `anyhow` 只在 bin?新依赖过了"四问"并在分层白名单内?
- [ ] 未触碰 FUTURE(F1–F4)与 D 系列禁区?
- [ ] 红证据已存 `.claude/tdd-evidence/`?
- [ ] 触碰强制名单层(dispatcher/路由器/compat/压缩/SessionTree/适配层)时测试先行?

自查通过后建议用户提交——commit-gate hook 会做最终机械把关(fmt/clippy/test/覆盖率/分层等)。若涉及架构边界改动,先派 arch-checker;若过程中改了 spec,先派 spec-reviewer。

## 中途失败处理

- 实现反复不能转绿(≥3 次推倒):停下来向用户报告障碍,不要降低测试标准迁就实现。
- 发现 spec 本身有错:**停**,记录问题,走宪章 3.1 先修 spec(经 spec-reviewer),再回来继续。
- 任何一步想跳过:不允许;确有理由走 docs/DEVIATIONS.md 留档。
