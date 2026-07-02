# SPEC-003:L1 权限 dispatcher

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §2.2.1 | 宪章:5.1(模型零直接副作用)、2.5(平台矩阵)| 依赖:无

## 意图

MVP 的唯一安全边界:模型发出的每个 `tool_use` 在执行前必经确定性校验,deny-first。被攻陷/被注入的模型无法绕过——推理与执行占据不同代码路径。

## 契约

```rust
pub struct PermissionPolicy {
    pub workspace_root: PathBuf,          // 文件操作默认边界
    pub bash_allowlist: Vec<CommandRule>, // 命令白名单(前缀/模式)
    pub default: DefaultAction,           // Ask | Deny(deny-first;无 Allow 默认)
}

pub enum Decision { Allow, Deny { reason: String }, Ask { prompt: String } }

/// 两阶段:
/// ① 解析(允许 IO):路径 canonicalize——解 symlink、规范化 `..`、Windows 盘符/UNC 归一
pub fn resolve(call: &ToolCall) -> Result<ResolvedCall, ResolveError>;
/// ② 判定(纯函数,零 IO):同输入必同输出
pub fn check(policy: &PermissionPolicy, call: &ResolvedCall) -> Decision;
```

## 行为规格

1. **文件规则**:解析后路径在 `workspace_root` 之下 → 按工具读写性放行;之外 → `Deny`。symlink 以**解析后目标**判定。`resolve` 失败(悬空链接、非法路径)→ `Deny`。
2. **Bash 规则**:命令匹配 allowlist → `Allow`;否则 → `default`(Ask/Deny)。匹配基于解析后的 argv 前缀,不对原始字符串做子串匹配(防 `rm -rf; npm test` 注入)。
3. **网络**:MVP 工具集无网络工具;出现网络类工具调用 → `Deny`。
4. **deny-first**:任何未被明确规则覆盖的调用 → `default`,且 `default` 不可配置为 Allow。
5. **执行闭环**:`Tool::execute` 可见性限定在 dispatcher 模块内(`pub(in ...)`),内核其它代码无法绕过 `check` 直接执行(编译期保证,宪章 5.1)。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 表驱动单测(每行一用例):工作区内读/写、`../` 出根、绝对路径外部、symlink 指外部、悬空 symlink、Windows `C:\` 与 UNC、macOS `/tmp` 链接 | 逐行匹配预期 Decision;三平台 CI 全绿 |
| AC-2 | 单测:`Bash("npm test")` 在 allowlist / `Bash("curl x")` 不在 | 前者 Allow,后者为 default(Ask/Deny),绝非 Allow |
| AC-3 | 单测:复合命令注入样例(`a && rm -rf /`、`; curl`、`$(...)`) | 均不因前缀部分匹配而 Allow |
| AC-4 | 属性测试:`check` 纯度 | 同一 `(policy, resolved_call)` 重复调用结果恒等 |
| AC-5 | 集成(CI 常驻,持续扩充):对抗性提示注入用例集 | **已知用例集 0 逃逸**——每例最终 Decision ∈ {Deny, Ask},无一 Allow |
| AC-6 | 编译期:在 kernel 非 dispatcher 模块调用 `Tool::execute` | 编译失败(trybuild 用例) |

## Non-goals

- L2 OS 级隔离(landlock/AppContainer 等):待裁定 D5,不承诺。
- 防恶意本地进程:L1 为进程内边界,明示不防。
- TOCTOU 完全消除:`resolve→check→execute` 间隙的竞态属 L2 范畴,MVP 仅以立即执行缩窄窗口并在文档声明。

## 开放关联

D5(L2 平台矩阵)。对抗用例集文件随本 spec 演进,位于 `tests/adversarial/`。
