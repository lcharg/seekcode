# SPEC-004:Tool trait、内置四工具与执行调度

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §2.3、§1.4 | 宪章:5.1 | 依赖:SPEC-003

## 意图

极小内核只带 4 个工具(Read/Write/Edit/Bash,pi 理念①);工具经统一 trait 注册,执行调度遵守「并行只读 / 串行写」,Pre/Post hooks 运行在模型上下文之外。

## 契约

```rust
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn readonly(&self) -> bool;                    // 调度依据
    fn schema(&self) -> ToolDef;                   // 暴露给模型的参数 schema
    // execute 的可见性为 pub(in crate::dispatcher):只能经 dispatcher 调用(SPEC-003 第5条)
}

pub struct ToolResult { pub ok: bool, pub content: String, pub exit_code: Option<i32> }

pub trait PreToolHook:  Fn(&ToolCall) -> HookDecision;   // Continue | Block{reason} | Rewrite(ToolCall)
pub trait PostToolHook: Fn(&ToolCall, &ToolResult);      // 观察,不可变更结果
```

**内置工具行为契约:**

| 工具 | readonly | 行为 | 错误语义 |
|---|---|---|---|
| Read | 是 | 读文件,支持 offset/limit | 文件不存在 → `ok=false` 明确消息 |
| Write | 否 | 整文件覆盖写 | 父目录不存在 → 创建或报错(配置项) |
| Edit | 否 | `old` 在文件中**唯一**匹配时替换为 `new` | 0 或 ≥2 处匹配 → `ok=false`,不做部分修改 |
| Bash | 否 | 执行命令,带超时参数 | 超时 → 终止进程并返回超时错误;退出码原样回传 |

## 行为规格

1. **调度**:同一批 tool_use 中,readonly 工具以 `tokio::join!` 并发;非 readonly 严格串行,且在同批只读全部完成之后执行。
2. **hooks**:PreToolHook 在 `check`(SPEC-003)之后、执行之前运行,可 Block/Rewrite;PostToolHook 在结果回流内核之前运行,只读。hook 逻辑在模型上下文之外——模型无法指示跳过。
3. **结果回流**:每个 ToolResult 作为 tool_result 追加进会话,并发 `AgentEvent::ToolStatus`。
4. **Bash 退出码**是 SPEC-002 机械验证的判据来源,不得吞掉或改写。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 时间线单测:一批 2 读 1 写(mock 工具记录起止时刻) | 两读时间区间重叠;写的开始时刻晚于两读的结束时刻 |
| AC-2 | 单测:Edit 的 `old` 出现 0 次 / 2 次 | 均返回 `ok=false`,目标文件内容不变 |
| AC-3 | 单测:Bash 超时(睡眠命令 + 短超时) | 返回超时错误,子进程被终止,不挂起 |
| AC-4 | 单测:PreToolHook 返回 Block | 工具未执行;回流结果为拒绝说明;PostToolHook 未触发 |
| AC-5 | 单测:PreToolHook 返回 Rewrite | 实际执行的是改写后参数(以 mock 工具捕获断言) |
| AC-6 | trybuild:非 dispatcher 模块调用 `execute` | 编译失败(同 SPEC-003 AC-6,双向引用) |
| AC-7 | 单测:Bash 返回码 3 | 回流的 `exit_code == Some(3)`,未被归一化 |

## Non-goals

- 第 5 个及以上内置工具、网络工具、MCP:不做;能力扩展走 Extension(未来 spec,登记于架构文档后再立项)。
- 自定义工具的 `readOnlyHint` 信任问题:MVP 仅 4 个内置工具,readonly 由实现方声明并经代码评审。
- 工具级重试:重试语义属 SPEC-009。

## 开放关联

无 D/F 直接关联。
