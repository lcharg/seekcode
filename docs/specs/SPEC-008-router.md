# SPEC-008:规则路由器(机制)

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §3.3、§3.5、§10(T1/T2)| 宪章:4.4(防腐①)、1.3 | 依赖:SPEC-007

## 意图

按任务特征在已注册模型中做确定性选择,决策全程可见(面板/日志/落盘)。**本 spec 承诺的是「路由器忠实执行规则表」这一机制;「路由省成本保质量」是 FUTURE F1 假设,毕业前不得作为事实表述。**

## 契约

```rust
pub enum TaskKind { Plan, Draft, Refine, ToolFollowup, Summarize }

pub struct TaskFeatures {
    pub prompt_tokens: u32,
    pub ctx_files: u32,
    pub has_code: bool,
    pub failed_attempts: u8,
    pub kind: TaskKind,
    pub needs_tools: bool,
    pub current_model: Option<ModelSpec>,   // R4 升档的基准
}

pub trait Router: Send + Sync {
    fn route(&self, reg: &Registry, f: &TaskFeatures) -> Result<RouteDecision, RouteError>;
}
pub struct RouteDecision { pub spec: ModelSpec, pub rule_id: RuleId }
pub enum RouteError { EmptyRegistry, NoEligibleModel { rule_id: RuleId } }

pub struct SingleModelRouter(pub ModelSpec);   // 空实现:恒定返回,防腐①的替换体
```

## 行为规格

1. **规则表 v0**(默认 RuleSet,外置配置,每条带 `rationale`/`as_of`):

| 规则 | 条件 | 决策 |
|---|---|---|
| R1 | `kind == Summarize` | `supports_streaming` 中成本最低者 |
| R2 | `kind == Draft && prompt_tokens < T1 && ctx_files <= T2 && failed_attempts == 0` | `code_gen >= Mid` 档中成本最低者 |
| R3 | `kind == Draft && (prompt_tokens >= T1 \|\| ctx_files > T2)` | `code_gen == High` 档中成本最低者 |
| R4 | `failed_attempts >= 1`(任意 kind,优先级最高) | 较 `current_model` 的 code_gen 高一档中成本最低;已是 High → 维持并发告警事件 |
| R5 | `kind == Plan \|\| kind == Refine` | `reasoning == High` 档中成本最低者 |
| R6(后置约束) | 选出模型 `!supports_tools` 且 `needs_tools` | 改走适配层 system-message tools 路径(SPEC-009),或 fallback 至满足条件的最近档 |

2. **确定性平局裁决**:"成本最低" = `cost_in + cost_out` 最小;仍并列 → `model` 字符串字典序最小。同输入必同输出。
3. **规则优先级**:R4 > R1/R2/R3/R5;R6 恒为后置检查。无规则命中(如 `ToolFollowup` 且无失败)→ 沿用 `current_model`,`rule_id = R0_KEEP`。
4. **决策可见三落点**:每次决策发 `AgentEvent::RouteDecision`、写 SessionTree 节点元数据(SPEC-010)、进 tracing 结构化日志。
5. **纯函数**:`route` 无 IO、无时钟、无随机。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 表驱动单测:上表逐行一用例(注册表含 Low/Mid/High 三档 mock 画像) | 每行返回预期 `(spec, rule_id)` |
| AC-2 | 边界单测:`prompt_tokens == T1`、`ctx_files == T2` | 按 §3.3.2 不等号方向落入 R3/R2,断言与规格一致 |
| AC-3 | 单测:空注册表 / 全部 `!supports_tools` 且 `needs_tools` | 分别返回 `EmptyRegistry` / R6 fallback 或 `NoEligibleModel`,不 panic |
| AC-4 | 单测:R4 升档链——current 已是 High | 返回维持 + 告警事件发出 |
| AC-5 | 属性测试:任意 `(reg, features)` 重复调用 | 结果恒等(确定性,含平局裁决) |
| AC-6 | 集成:mock 上「R2 低档 → 验证失败 → R4 升档」端到端 | 两次 RouteDecision 依次为 R2、R4;面板与日志各出现两条 |
| AC-7 | 防腐①(CI 常驻):`SingleModelRouter` 替换后跑全部内核测试 | 全绿 |

## Non-goals

- **效果主张**(省成本/保质量):FUTURE F1,毕业前禁止在任何对外文本中作为结论。
- 学习型路由:FUTURE F2。
- `Plan`/`Draft`/`Refine` 的自动打标:待裁定 D1(kind 是本 spec 的**输入**,其生产来源见 SPEC-002 第 5 条)。
- T1/T2 的"正确性":未校准默认值(§10),本 spec 只保证忠实执行。

## 开放关联

D1、F1、F2。规则配置文件的 `as_of` 超期黄标同 SPEC-007 AC-4 机制。
