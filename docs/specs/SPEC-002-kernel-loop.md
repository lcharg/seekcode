# SPEC-002:编排内核主循环

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §2.1、§2.4 | 宪章:5.1、5.2、4.4(防腐①)| 依赖:SPEC-001、SPEC-003、SPEC-008

## 意图

实现「简单 while-loop」内核:调模型 → 解析 tool_use → 权限校验 → 执行工具 → 结果回流 → 检查停止条件。内核只依赖三个 trait(`Provider`/`Tool`/`Router`),不含任何模型专属常量——这是极小内核(pi 理念①)与推理/执行分离(§2.2)的执行主体。

## 契约

```rust
pub struct Kernel {                       // 依赖全部注入,内核零具体类型
    provider_factory: Arc<dyn ProviderFactory>,   // SPEC-007
    router: Arc<dyn Router>,                      // SPEC-008
    dispatcher: Dispatcher,                       // SPEC-003/004
    session: SessionTree,                         // SPEC-010
    events_tx: mpsc::Sender<AgentEvent>,          // → TUI,SPEC-011
}

// 回合状态机(内部,不对外暴露具体类型):
// Idle → RouteAndCall → Streaming → { ToolPhase → RouteAndCall | Verify → { Done | RouteAndCall(failed_attempts+1) } }
// 任意状态可被取消 → Cancelled(不 panic)
```

## 行为规格

1. **回合推进**:收到 `UserInput` 后进入 `RouteAndCall`:构造 `TaskFeatures`(SPEC-008)→ `router.route()` → 经适配层调 `provider.stream()`;`ToolUse` 事件送 dispatcher,`tool_result` 追加进上下文后再次 `RouteAndCall`。
2. **verify(机械验证,穷尽定义)**:
   - Edit 类工具执行后,内核重读目标区域,断言编辑已应用;
   - Bash 类以退出码判定;
   - 任务携带声明式验证命令时,其退出码为该任务通过判据;非 0 → `failed_attempts += 1`,回到 `RouteAndCall`(R4 升档由 SPEC-008 负责)。
3. **停止条件**(满足其一):`Done(EndTurn)` 且无待执行 tool_use;用户取消;fallback 上限到达(SPEC-009 移交挂起);预算硬上限到达(SPEC-012 移交挂起)。
4. **可取消**:任意状态收到取消信号,≤ T_cancel 停止全部子任务,session 状态落盘完好。
5. **打标边界(D1 裁定前)**:内核仅机械打标 `Summarize`(内核自发任务)与维护 `failed_attempts`;其余任务默认 `ToolFollowup`,或采用用户显式指定的 kind。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 单测:mock Provider 注入 `TextDelta×N + ToolUse + Done` | 循环按序消费;tool_result 回流后发起第二次模型调用(调用计数=2) |
| AC-2 | 单测:流式中途取消 | ≤ T_cancel 停止、无 panic、session 可重新打开 |
| AC-3 | 单测:mock 工具返回非零退出码(任务带验证命令) | 下一次 `router.route()` 收到的 `TaskFeatures.failed_attempts == 1` |
| AC-4 | 单测:Edit 后目标区域与预期不符(mock 注入) | verify 判失败,`failed_attempts` 递增,不静默通过 |
| AC-5 | 防腐①(CI 常驻):以 `SingleModelRouter` 替换 Router 跑全部内核测试 | 全绿——内核不依赖路由层 |
| AC-6 | 词表 grep(CI):kernel crate 源码 | 不含厂商/模型名词表任何词(宪章 5.2) |
| AC-7 | 单测:内核自发压缩任务 | 该任务 `TaskFeatures.kind == Summarize`(D1 裁定前唯一自动打标) |

## Non-goals

- `Plan`/`Draft`/`Refine` 自动判定状态机:待裁定 D1,禁止实现。
- 语义验证(LLM 自评):FUTURE F4,禁止实现。
- planner/状态图式决策脚手架:与极小内核原则冲突,不做。

## 开放关联

D1(打标状态机)——本 spec 第 5 条为裁定前的全部允许行为。
