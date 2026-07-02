# SPEC-009:适配转换层(模板 / 校验 / fallback)

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §3.4、§10(P4)| 依赖:SPEC-001、SPEC-007

## 意图

坐在 Router 与 Provider 之间,吸收"同一逻辑请求 × 不同模型"的表达差异:渲染提示模板、校验输出格式、失败时确定性降级——保证多模型协作不把格式故障泄漏给内核。

## 契约

```rust
pub struct Adapter { /* 持有模板注册表 + fallback 链配置(全部外置) */ }

impl Adapter {
    /// 渲染:同一逻辑请求按 ModelSpec 绑定的模板产出最终 CompletionRequest
    pub fn render(&self, logical: &LogicalRequest, spec: &ModelSpec) -> CompletionRequest;
    /// 校验:对结构化输出(含 ToolUse.args_json)做 schema 校验
    pub fn validate(&self, ev: &ProviderEvent, expected: &Schema) -> Result<(), FormatError>;
}

pub enum AdapterOutcome { Ok(ProviderEvent), Retried { attempt: u8 }, FellBack { to: ModelSpec }, Suspended { reason: String } }
```

## 行为规格

1. **模板**:每 `ModelSpec` 绑定一个模板(Chat/JSON/XML 渲染形态);模板外置于配置,带 `rationale`/`as_of`。
2. **校验失败处理链**(确定性):同一任务内 ① 重试当前模型(1 次)→ ② fallback 到链上下一模型 → 累计 fallback 达 **P4** → ③ `Suspended`:发挂起询问事件等用户,**绝不静默死循环**。
3. **fallback 链**:来自配置(默认按 `code_gen` 档降序 → 兜底模型);链为空时直接 `Suspended`。
4. **system-message tools 路径**(R6 触发):对 `!supports_tools` 模型,把 `Vec<ToolDef>` 序列化为 XML 注入系统提示,解析模型输出中的 XML 工具调用为标准 `ToolUse` 事件。编解码必须往返等价。
5. **透明性**:每次 retry/fallback/suspend 发对应事件并进 tracing;内核只见标准 `ProviderEvent`。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | insta 快照:同一 `LogicalRequest` × 3 模板(Chat/JSON/XML) | 三份渲染结果锁定;模板变更即 diff |
| AC-2 | 单测:畸形输出样例集(截断 JSON、错字段名、非法枚举值) | 每例进入 retry 分支,`FormatError` 携带定位 |
| AC-3 | 单测:mock provider 连续失败 P4+1 次 | 输出序列 = Retried → FellBack×(P4−1) → Suspended;无死循环(调用次数上限断言) |
| AC-4 | 单测:fallback 链为空 + 首次失败 | 直接 Suspended,不重试第二轮 |
| AC-5 | 往返属性测试:任意合法 `Vec<ToolDef>` → XML → 解析 | 与原始 ToolDef/ToolCall 结构等价 |
| AC-6 | 单测:R6 场景端到端(mock 无工具模型) | 工具经系统提示注入;模型 mock 输出 XML 调用被还原为标准 `ToolUse` |
| AC-7 | 事件断言:AC-3 全程 | 每次状态迁移各有一条事件与 tracing 记录 |

## Non-goals

- 真实弱模型对 XML 工具格式的**遵从率**:待裁定 D6——往返测试只证编解码自洽,遵从率需真实数据,本 spec 不承诺。
- 语义级输出质量校验:FUTURE F4。
- Provider 内部的传输层重试(网络抖动):属 Provider 实现细节,与本层 P4 计数分离。

## 开放关联

D6、F4。P4 见 §10。
