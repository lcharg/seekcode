# SPEC-005:上下文自动压缩

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §2.3、§10(P1/P2/N)| 依赖:SPEC-002、SPEC-008(R1)、SPEC-010

## 意图

会话逼近上下文上限时自动摘要旧历史,使长任务可持续;压缩以**机械判据**验收(占用与结构完整性),摘要语义保真明示不作规格。

## 契约

```rust
pub struct CompactionConfig { pub trigger: f32 /*P1*/, pub target: f32 /*P2*/, pub keep_turns: u32 /*N*/ }

pub trait Context {
    fn usage(&self) -> f32;                                  // used_tokens / context_window
    fn compact(&mut self, summary: SummaryNode) -> CompactReport;
}
pub struct CompactReport { pub before: f32, pub after: f32, pub summarized_range: NodeRange }
```

## 行为规格

1. **触发时点**:每次 `RouteAndCall` 前评估;`usage() >= P1` → 触发压缩,先于本次模型调用完成。
2. **保留集**(不可被摘要):系统提示;最近 N 轮完整消息;**所有未完成的 tool_use/tool_result 配对**。
3. **摘要生成**:被摘要区段作为一次内核自发任务(`TaskKind::Summarize`,经 SPEC-008 R1 选模)生成单条 `SummaryNode`,在 SessionTree 中替代该区段(树结构由 SPEC-010 保证 parent 链接完好)。
4. **后置条件**:`usage() <= P2`;若一次压缩后仍 > P2,允许再压缩一轮,两轮后仍超 → 发告警事件并继续(不死循环)。
5. **可观察**:压缩前后各发 `AgentEvent::ContextUsage`;压缩发生记入 tracing。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 边界单测:构造 usage=P1−ε / =P1 | 前者不触发,后者触发(阈值含等号) |
| AC-2 | 单测:压缩后(mock 摘要注入) | `usage() <= P2` |
| AC-3 | 单测:构造含未完成 tool_use(无配对 result)的历史 | 压缩后该配对完整保留,未被拆散或摘要 |
| AC-4 | 单测:最近 N 轮 | 逐字保留,不在 summarized_range 内 |
| AC-5 | 单测:摘要任务打标 | 该任务 `kind == Summarize`(联动 SPEC-002 AC-7、SPEC-008 R1) |
| AC-6 | 单测:两轮压缩仍 > P2(极端构造) | 发出告警事件,循环继续,无死循环(迭代上限断言) |
| AC-7 | 事件断言:压缩前后 | 两次 `ContextUsage` 事件,数值与 report 一致 |

## Non-goals

- 摘要的**语义保真**:无机械判据,有意不作规格(report_v2 §2.3 明示)。
- pi 式 `compact_boundary` 与外部可见的压缩协议:MVP 不对外暴露。
- 跨会话记忆:不在本 spec。

## 开放关联

P1/P2/N 为待标定参数(§10);标定途径为实际会话数据回归。
