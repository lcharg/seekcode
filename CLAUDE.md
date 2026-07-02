@AGENTS.md

# seekcode 项目常驻规则

Rust 终端编码 Agent(pi 理念 + 模型路由机制)。治理文档优先级:`docs/CONSTITUTION.md`(宪章)> `docs/report_v2.md` + `docs/specs/`(规格)> `docs/ARCHITECTURE.md`(架构,非规范)。

## 不可协商(宪章第 1 章)

- **无 spec 不写实现**:每个跨 crate `pub` 项的 rustdoc 首行必须有 `Spec: SPEC-0xx` 锚点,且该 spec 存在于 `docs/specs/`。没有对应 spec → 先补 spec(经 spec-reviewer),再写代码。
- **FUTURE 禁区**:`docs/FUTURE.md` 的 F1–F4(路由收益主张、学习型路由、能力探针、LLM 评审员)一律不实现,除非已毕业为正式 spec。
- **D 系列禁区**(`report_v2.md §9`):D1–D6 只允许各条标注的"裁定前行为"。速记:TaskKind 自动打标只有 `Summarize` + `failed_attempts`;预算只做实付硬上限;无热插件;无文件系统回滚;无 L2 sandbox;XML 工具调用只保证编解码往返。
- 对外文本(README/help)不得把路由说成"省成本/保质量"——只能说"机制可用"。

## 工作顺序(宪章 3.1 / 4.1,不可颠倒)

**spec → 失败测试(确认红)→ 实现(绿)→ 重构 → 验收命令。** 编码任务一律走 `/implement-spec <spec路径>`;任务派发格式见 `docs/TASK_TEMPLATE.md`。测试名遵循 `specNNN_acM_描述` 约定(可 grep 审计)。强制"先失败测试"的层:权限 dispatcher、路由器、compat/models.json、压缩、SessionTree、适配层(宪章 4.2)。

## Rust 工程约束(宪章第 2 章)

- 错误:库 crate 用 `thiserror`,`anyhow` **只在 bin**;非测试代码禁 `unwrap/expect/panic!/todo!/unimplemented!`;唯一豁免写法:`#[allow(clippy::expect_used)]` + `expect("invariant: 为何不可能失败")`。
- 全 crate `#![forbid(unsafe_code)]`、`#![deny(missing_docs)]`(库);MSRV 1.85;`cargo fmt` + clippy 零警告是提交前置(commit-gate 会拦)。
- 阈值/魔法数字不硬编码:一律引用 `report_v2.md §10` 参数表(T1/T2/P1–P6/N),入配置。
- 新依赖:先查 `deny.toml` 允许表 + ARCHITECTURE §1.1 分层,PR 里答"四问"。

## crate 依赖方向(违反即 commit-gate 失败)

```
seek-contract ← 所有人(唯一交集:两事件枚举 + 三 trait)
seek-kernel   → 只准 contract, session + std/tokio/serde/thiserror/tracing
                禁:rig/genai/ratatui/crossterm/rusqlite/任何厂商名(词表 grep)
seek-tui      → 禁 import kernel(只认 AgentEvent)
seek-provider-rig → rig 只准出现在这里(pin =x.y.z)
bin(seekcode) → 唯一允许 anyhow 的地方
```

工具执行必经 `kernel::exec` 的 dispatcher(`Tool::execute` 是 `pub(in crate::exec)`,绕过 = 编译失败)。

## 文件红线

- `docs/report_v1.md` 只读存档,永不修改(permissions 已 deny)。
- 改 `docs/CONSTITUTION.md` 须走宪章 6.2(独立变更 + 修订记录行),permissions 会 ask。
- 偏离宪章的唯一方式:`docs/DEVIATIONS.md` 留档(带到期条件)。
