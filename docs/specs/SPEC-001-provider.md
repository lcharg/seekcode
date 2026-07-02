# SPEC-001:Provider trait 与 ProviderEvent 流契约

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §1.4、§4.3、§6.2 步 1 | 宪章:2.3(依赖分层)、5.4(契约快照)| 依赖:无

## 意图

为所有 LLM 厂商提供**唯一**的进出口抽象:内核只认识 `Provider` trait 与 `ProviderEvent` 枚举,厂商 SDK(rig/genai)只出现在实现侧。这是「模型无关为一等公民」(pi 理念④)与宪章 5.2「内核零模型专属知识」的类型学落点。

## 契约

```rust
pub trait Provider: Send + Sync {
    /// 发起一次流式补全。返回的 Receiver 产出满足 §行为规格 事件文法的序列。
    /// cancel 触发后,实现须在 T_cancel 内结束任务并关闭通道。
    fn stream(
        &self,
        req: CompletionRequest,
        cancel: CancellationToken,
    ) -> mpsc::Receiver<ProviderEvent>;
}

pub struct CompletionRequest {
    pub system: Option<String>,
    pub messages: Vec<Message>,       // 会话历史(角色 + 内容块)
    pub tools: Vec<ToolDef>,          // 可为空
    pub spec: ModelSpec,              // 见 SPEC-007
}

pub enum ProviderEvent {
    TextDelta(String),
    ToolUse { id: ToolCallId, name: String, args_json: String },
    Usage { in_tokens: u32, out_tokens: u32 },
    Done(StopReason),                 // EndTurn | ToolUse | MaxTokens | Other(String)
    Error(ProviderError),
}
```

## 行为规格

1. **事件文法**:`(TextDelta | ToolUse | Usage)* (Done | Error)` ——恰好一个终止事件,终止后通道关闭,不再产出任何事件。
2. **args_json 责任边界**:Provider 原样转发模型输出的工具参数,**不做**语义校验;校验属 SPEC-009。
3. **取消**:`cancel` 触发后,后台任务在 T_cancel(默认 5s,可配置)内退出,无 panic,通道关闭(终止事件可有可无)。
4. **零厂商泄漏**:`ProviderEvent`/`CompletionRequest` 的任何字段不得携带厂商专属类型;厂商差异由 compat flags(SPEC-007)在实现内部吸收。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 单测:mock Provider 发 `TextDelta×3 + Done` | 消费端按发送顺序收到全部 4 个事件 |
| AC-2 | 属性测试:对 mock 与 rig 后端的录制流校验事件文法 | 任意会话的事件序列匹配文法;`Done/Error` 后通道关闭 |
| AC-3 | 单测:流中途触发 `cancel` | 任务 ≤ T_cancel 结束、无 panic、通道关闭 |
| AC-4 | insta 快照:`ProviderEvent` 全变体的 serde 序列化 | 快照锁定;变更即 diff(宪章 5.4 契约变更信号) |
| AC-5 | 集成(feature-gated,需 API key,CI 允许 skip 标记):rig 后端真实流式一轮 | 事件文法成立且至少收到 1 个 `TextDelta` 与 1 个 `Usage` |
| AC-6 | 编译期/依赖断言:kernel crate 依赖树不含 rig/genai | `cargo metadata` 白名单脚本通过(宪章 2.3) |

## Non-goals

- 厂商请求体格式与重试:属 SPEC-009(适配层)与实现内部。
- 多模态内容块、prompt cache 控制:MVP 不承诺。
- Provider 侧的成本估算:见 report_v2 §9 D2,不实现。

## 开放关联

无 D/F 直接关联。rig 版本 pin 与升级流程见宪章 2.3。
