# SPEC-007:ModelSpec、compat flags、models.json 与能力画像

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §1.4、§3.2、§6.2 步 4 | 宪章:5.2 | 依赖:SPEC-001

## 意图

新增模型 = 只改配置,零代码改动(防腐②)。`(provider, model, api)` 工厂 + compat flags 吸收厂商差异;`ModelProfile` 为路由器提供离散能力档位,数值全部带来源与时效标注。

## 契约

```rust
pub struct ModelSpec { pub provider: String, pub model: String, pub api: ApiKind, pub compat: CompatFlags }
pub enum ApiKind { OpenAiCompat, Anthropic, Ollama /* 扩展经配置注册 */ }

pub struct CompatFlags {
    pub system_role_name: Option<String>,   // 覆盖 system 角色名
    pub max_tokens_field: Option<String>,   // 覆盖 max_tokens 字段名
    pub supports_tools: bool,
    pub supports_streaming: bool,
    pub custom_headers: Vec<(String, String)>,
}

pub trait ProviderFactory { fn resolve(&self, name: &str) -> Result<Arc<dyn Provider>, ConfigError>; }

pub enum ProfileSource { Static, VendorApi }
pub enum CapabilityTier { Low, Mid, High }
pub struct Sourced<T> { pub value: T, pub source: ProfileSource, pub as_of: NaiveDate, pub provenance: String }

pub struct ModelProfile {
    pub spec: ModelSpec,
    pub reasoning: Sourced<CapabilityTier>,
    pub code_gen: Sourced<CapabilityTier>,
    pub context_window: Sourced<u32>,
    pub cost_in: Sourced<f32>, pub cost_out: Sourced<f32>,   // $/Mtok
    pub supports_tools: bool, pub supports_streaming: bool,
}
```

`models.json`:`ModelProfile` 数组的直接序列化;`provenance` 与 `as_of` 必填。

## 行为规格

1. **工厂解析**:`resolve` 按 `(provider, model, api)` 构造 Provider 实例;未知 `api` / 缺字段 → 带定位信息的 `ConfigError`,不 panic。
2. **compat 生效点**:各 flag 在 Provider 实现内改写请求(角色名、字段名、headers);`supports_*` 供路由(SPEC-008 R6)与适配层查询。
3. **画像填充顺序**:静态 `models.json` 兜底(必有)→ provider 元数据查询覆盖同名字段(context_window、supports_*)。仅此两级。
4. **保鲜**:`as_of` 距今 > P5 → 发画像过期事件(路由决策面板黄标,SPEC-011)。
5. **重载**:配置外置,重载生效(重启或显式 reload);**无**运行时热替换承诺(D3)。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 反序列化用例集:合法配置、缺 `provenance`、未知 `api`、tier 拼写错误 | 合法通过;非法各返回含字段路径的 `ConfigError` |
| AC-2 | wiremock 逐 flag 断言:`system_role_name`/`max_tokens_field`/`custom_headers` | 实际 HTTP 请求体/头逐项符合 flag 定义 |
| AC-3 | 防腐②(CI 常驻):新增 mock 厂商**仅**追加 models.json 条目 | 集成测试端到端通过,代码 diff 为零 |
| AC-4 | 单测:`as_of` 超 P5 的画像加载 | 画像过期事件发出(联动 SPEC-011 面板) |
| AC-5 | 单测:元数据查询返回 context_window | 覆盖静态同名字段,`source` 变为 `VendorApi` |
| AC-6 | 单测:重载含错误的新配置 | 拒绝并保留旧配置生效,报错可见 |

## Non-goals

- 在线能力探针(code_gen/latency 实测):FUTURE F3,禁止实现。
- 运行时热替换:待裁定 D3。
- tier 数值的"正确性":tier 是维护者依据 `provenance` 手填的序数配置,本 spec 只校验其存在与格式。

## 开放关联

D3(热替换)、F3(探针)。P5 见 §10。
