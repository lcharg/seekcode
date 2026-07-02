# SPEC-012:成本累计与预算硬上限

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §7 成本失控行、§10(P6)| 依赖:SPEC-001(Usage 事件)、SPEC-007(单价)

## 意图

成本失控的确定性防线:只基于**实际发生**的 token 用量计费(`Usage` 事件 × 画像单价),累计达到会话预算硬上限即挂起询问。不做任何预估性决策(预估降档为待裁定 D2)。

## 契约

```rust
pub struct SpendLedger { /* 会话级累计,含子 agent(SPEC-006) */ }

impl SpendLedger {
    /// 每个 Usage 事件调用一次;单价来自该次调用的 ModelProfile
    pub fn record(&mut self, spec: &ModelSpec, usage: &Usage, profile: &ModelProfile) -> f32; // 返回新累计
    pub fn total_usd(&self) -> f32;
}

pub enum BudgetState { Under, Exceeded { total: f32, budget: f32 } }
pub fn check_budget(total: f32, budget: Option<f32> /*P6,None=无上限*/) -> BudgetState;  // 纯函数
```

## 行为规格

1. **计费口径**:`cost = in_tokens × cost_in / 1e6 + out_tokens × cost_out / 1e6`;单价取**发起该调用时**生效的画像值(重载配置不追溯已记账条目)。
2. **归并范围**:父会话 + 全部子 agent 的 Usage 合并入同一 ledger(SPEC-006 第 2 条)。
3. **检查时点**:每次 `RouteAndCall` 之前;`check_budget == Exceeded` → 内核挂起,发挂起询问事件(经 `PermissionRequest` 通道语义:用户选择「继续(上调预算)/终止」),**不发起**新模型调用。
4. **进行中的调用不截断**:超限只阻止新调用,正在流式返回的调用允许完成并记账。
5. **可观察**:每次记账后发 `AgentEvent::SpendUpdate`;面板显示实付累计(SPEC-011 AC-5)。
6. **P6 未配置(None)**:无上限,但 SpendUpdate 照常发出——可见性不依赖上限存在。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 单测:父 2 次 + 子 agent 1 次 Usage(mock 单价) | `total_usd` 等于三笔手算之和(浮点容差断言) |
| AC-2 | 边界单测:total = P6 − ε / = P6 | 前者 Under,后者 Exceeded(含等号) |
| AC-3 | 集成:mock 流程中 total 越过 P6 | 下一次模型调用未发起(provider mock 调用计数不变);挂起询问事件发出 |
| AC-4 | 单测:超限时有进行中的流 | 该流完成并记账;仅新调用被阻止 |
| AC-5 | 单测:用户回答「继续」并上调预算 | 循环恢复,新调用发起 |
| AC-6 | 单测:P6 = None | 永不 Exceeded;SpendUpdate 事件仍逐笔发出 |
| AC-7 | 单测:记账后重载画像改单价 | 已记账条目金额不变(不追溯) |

## Non-goals

- **预估**成本与预估性降档:待裁定 D2,禁止实现。
- 按任务/按模型的细分预算、月度预算:MVP 只有会话级单一上限。
- 缓存/折扣价目:MVP 按画像标称单价计,不建模 prompt cache 计费差异。

## 开放关联

D2。P6 见 §10(用户配置,无默认承诺)。挂起询问复用 `PermissionRequest` 通道语义——若最终以独立事件变体实现,同 SPEC-011 开放关联的契约变更流程处理。
