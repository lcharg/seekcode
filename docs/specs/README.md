# docs/specs/ — 功能规格集索引

> 本目录是核心规格 [report_v2.md](../report_v2.md) 的**逐能力分解**:每个核心能力一份独立 spec,含意图、输入/输出契约、可直接转成测试的验收标准(AC)、明确的 non-goals。
> **冲突规则**:与 report_v2.md 不一致时,以 report_v2.md 为准。本目录已由宪章 v1.1 修订承认为规范性逐能力规格(宪章 7.1)。
> **追溯约定**:实现代码的 rustdoc 锚点写 `Spec: SPEC-0xx`,本索引表提供 SPEC ↔ report_v2 § 的双向映射,满足宪章 1.1。
> 全部待标定参数(T1/T2/P1–P6/N)引用 [report_v2.md §10](../report_v2.md),spec 内不复制数值。

| ID | 能力 | 上游锚点(report_v2) | 依赖 | MVP 步骤 | 状态 |
|---|---|---|---|---|---|
| [SPEC-001](SPEC-001-provider.md) | Provider trait 与 ProviderEvent 流契约 | §1.4, §4.3, §6.2 步1 | — | 1 | Draft |
| [SPEC-002](SPEC-002-kernel-loop.md) | 编排内核主循环(gather→act→verify) | §2.1, §2.4 | 001, 003, 008 | 1 | Draft |
| [SPEC-003](SPEC-003-permission-dispatcher.md) | L1 权限 dispatcher | §2.2.1 | — | 2 | Draft |
| [SPEC-004](SPEC-004-tools.md) | Tool trait、内置四工具与执行调度 | §2.3, 宪章 5.1 | 003 | 2 | Draft |
| [SPEC-005](SPEC-005-context-compaction.md) | 上下文自动压缩 | §2.3 | 002, 008, 010 | 6 | Draft |
| [SPEC-006](SPEC-006-subagent.md) | 子 agent 隔离 | §2.3 | 002, 012 | 6 | Draft |
| [SPEC-007](SPEC-007-model-registry.md) | ModelSpec/compat/models.json 与能力画像 | §1.4, §3.2, §6.2 步4 | 001 | 4 | Draft |
| [SPEC-008](SPEC-008-router.md) | 规则路由器(机制) | §3.3, §3.5 | 007 | 5 | Draft |
| [SPEC-009](SPEC-009-adapter.md) | 适配转换层(模板/校验/fallback) | §3.4 | 001, 007 | 6 | Draft |
| [SPEC-010](SPEC-010-session-tree.md) | SessionTree 与持久化 | §1.4, §6.2 步6 | — | 6 | Draft |
| [SPEC-011](SPEC-011-tui.md) | TUI 事件协调与五区布局 | §4 | 001(事件契约) | 3 | Draft |
| [SPEC-012](SPEC-012-budget.md) | 成本累计与预算硬上限 | §7 成本行, §10 P6 | 001, 007 | 5–6 | Draft |

**统一文件结构**:意图 → 契约(类型/签名)→ 行为规格 → 验收标准(AC-n,可直接转测试)→ Non-goals → 开放关联(D/F 条目)。
**AC 编号即测试名约定**:`spec001_ac3_cancellation_no_panic` 这类命名使覆盖可 grep 审计。
