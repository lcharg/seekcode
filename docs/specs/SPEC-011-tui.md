# SPEC-011:TUI 事件协调与五区布局

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §4 | 宪章:5.4(层间契约)| 依赖:SPEC-001(事件契约定型同步)

## 意图

Ratatui + crossterm 的异步 TUI:渲染节奏与输入/后台完全解耦(60fps 门控),内核↔TUI 只经 `AgentEvent` 通信;路由决策面板使每次选模对用户可见。

## 契约

```rust
/// 内核 → TUI(层间唯一契约;变更须同步 serde 快照,宪章 5.4)
pub enum AgentEvent {
    MessageDelta { node_id: NodeId, text: String },
    ToolStatus { call: ToolCallId, state: ToolState, elapsed: Duration },   // Running|Ok|Failed
    RouteDecision { task: TaskId, spec: ModelSpec, rule_id: RuleId },
    PermissionRequest { call: ToolCallId, reply: oneshot::Sender<Decision> },
    ContextUsage(f32),
    ProfileStale { spec: ModelSpec, as_of: NaiveDate },     // SPEC-007 AC-4 黄标
    SpendUpdate { session_total_usd: f32 },                 // SPEC-012
}
```

**五区布局**(§4.2 版图为准):对话流 / 任务步骤树 / 工具调用日志 / Diff 预览(similar)/ 模型路由决策面板(规则 id、模型、实付累计)。

## 行为规格

1. **Terminal 单一所有者**:`terminal.draw()` 唯一同步边界,每循环迭代至多一次。
2. **渲染门控**:独立事件源 task 以 `tokio::select!` 复用 crossterm EventStream + tick(1Hz)+ render(60fps);**仅** `Event::Render` 触发 draw,事件到达只置脏标记。
3. **单 EventStream**:全部终端输入经一个 crossterm EventStream;禁止混用阻塞 `read()/poll()`(官方文档:非线程安全)。
4. **跨任务通信只走 mpsc/oneshot**:Terminal 上无共享可变状态;`PermissionRequest` 经 oneshot 回答,内核阻塞等待,TUI 不阻塞渲染。
5. **取消**:Ctrl+C 发取消信号给内核(SPEC-002 AC-2),UI 保持响应。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | `TestBackend` 快照:给定固定 `AgentEvent` 序列 | 五区渲染缓冲逐一匹配 insta 快照 |
| AC-2 | 计数器单测:注入 100 个 MessageDelta + 3 个 Render | `draw` 恰被调用 3 次 |
| AC-3 | 时间线单测:流式事件持续到达时注入按键 | 按键处理延迟 < 门控周期上限;无饿死 |
| AC-4 | oneshot 往返:PermissionRequest → TUI 回答 Allow/Deny | 内核收到对应 Decision;超时路径有明确行为(挂起提示,不 panic) |
| AC-5 | 快照:RouteDecision 面板行 | 含 rule_id、模型名、实付累计(SpendUpdate 后更新) |
| AC-6 | 快照:ProfileStale 事件后 | 决策面板对应模型行出现黄标标记 |
| AC-7 | serde 快照:`AgentEvent` 全变体 | 锁定;变更即契约 diff(与 SPEC-001 AC-4 同规则) |

## Non-goals

- Web/WASM 前端:非目标(report_v2 §0.2);本契约不为其做预留设计,仅保证事件消费端可替换。
- Elm 叠加框架(boba/tears):可选项,不进规格。
- 主题/配色/鼠标支持:MVP 不承诺。

## 开放关联

`AgentEvent` 相比 report_v2 §4.3 新增 `ProfileStale`/`SpendUpdate` 两个变体(SPEC-007/012 的可观察性要求)——**属层间契约变更,须经 spec-reviewer 后同步回 report_v2 §4.3**。
