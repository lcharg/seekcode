# SPEC-006:子 agent 隔离

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §2.3、§2.4 | 依赖:SPEC-002、SPEC-012

## 意图

把大体量副任务(搜索、批量读取)隔离到独立上下文,父会话只增加最终结果——把父上下文增长界定在"摘要"而非"全量转录"。

## 契约

```rust
pub struct SubagentHandle { pub id: SubagentId, /* join → SubagentResult */ }

impl Kernel {
    /// 派生独立 agent-loop task:全新上下文,仅注入 sub_task 描述与必要环境
    pub fn spawn_subagent(&self, sub_task: SubTask) -> SubagentHandle;
}
pub struct SubagentResult { pub final_output: String, pub usage: UsageTotals }
```

## 行为规格

1. **上下文隔离**:子 agent 以全新消息历史启动,不携带父会话转录;父会话在子 agent 结束后仅追加一条 tool_result(`final_output`)。
2. **资源归并**:子 agent 的全部 `Usage` 计入**同一会话**的成本累计(SPEC-012);预算硬上限对父子合并生效。
3. **取消传播**:父取消 → 全部存活子 agent 收到取消,遵守 SPEC-002 AC-2 时限。
4. **安全同边界**:子 agent 的 tool_use 走同一 dispatcher(SPEC-003),无独立宽松策略。
5. **落盘**:子 agent 转录以独立分支存入 SessionTree(SPEC-010),父的活动路径不包含它。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 单测:子 agent 执行含 5 次工具调用的任务 | 父上下文差分 == 单条 tool_result;5 次调用的转录不在父活动路径 |
| AC-2 | 单测:子 agent 产生 Usage | 会话累计花费包含子 agent 部分(联动 SPEC-012 AC-1) |
| AC-3 | 单测:父取消时子 agent 在跑 | 子任务 ≤ T_cancel 结束,无 panic |
| AC-4 | 单测:子 agent 发起越权路径写 | 被同一 dispatcher 拒绝(策略无差异) |
| AC-5 | 持久化断言:会话文件重开 | 子分支存在且不在 active 路径上 |

## Non-goals

- side-quest 的**文件系统**隔离(快照/worktree):待裁定 D4,禁止实现。
- 子 agent 间通信、递归深度 >1 的嵌套策略:MVP 允许深度 1,更深不承诺。
- 子 agent 独立预算:预算是会话级(SPEC-012),不拆分。

## 开放关联

D4(文件系统隔离)。
