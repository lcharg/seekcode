# SPEC-010:SessionTree 与持久化

> 状态:Draft(待 spec-reviewer)| 上游:report_v2.md §1.2、§1.4、§6.2 步 6 | 依赖:无

## 意图

树状会话(pi 理念③):消息带 `id/parent_id`,支持分支、rewind、分支摘要注回主线;崩溃后可恢复到同一活动位置。session 是追加式事件日志(Managed Agents 虚拟化第一件套)。

## 契约

```rust
pub struct NodeId(Uuid);
pub struct Node {
    pub id: NodeId,
    pub parent_id: Option<NodeId>,        // None = 根
    pub payload: NodePayload,             // Message | ToolCall | ToolResult | Summary | RouteDecision
    pub meta: NodeMeta,                   // 时间戳、扩展状态(pi 理念②:extension 状态可持久化)
}

pub struct SessionTree { /* 节点表 + active_leaf: NodeId */ }

impl SessionTree {
    pub fn append(&mut self, payload: NodePayload) -> NodeId;      // 挂在 active_leaf 下并推进
    pub fn branch_from(&mut self, at: NodeId) -> NodeId;           // 新分支,active 切换
    pub fn rewind_to(&mut self, at: NodeId);                       // active 回退;旧分支保留不删
    pub fn reinject_summary(&mut self, branch: NodeId, s: Summary) -> NodeId;  // 分支摘要注回主线
    pub fn active_path(&self) -> Vec<&Node>;                       // 根→active_leaf,即当前上下文来源
}

pub trait SessionStore {                   // 持久化后端抽象:JSONL 或 SQLite
    fn persist(&mut self, event: &TreeEvent) -> Result<(), StoreError>;   // 追加式
    fn load(&self) -> Result<SessionTree, StoreError>;
}
```

## 行为规格

1. **追加式**:所有变更(含 rewind、branch)以事件追加落盘,不改写历史;`load` 重放事件重建树。
2. **rewind 语义**:仅移动 `active_leaf`;被离开的分支完整保留(对话状态回滚,**不**回滚文件系统——D4 边界,与 pi 一致)。
3. **摘要注回**:`reinject_summary` 在主线 active 位置追加 Summary 节点,其 meta 引用来源分支 id,链路可审计。
4. **RouteDecision 落盘**:每次路由决策作为节点(或节点元数据)入树,与消息同源可回放(SPEC-008 第 4 条)。
5. **崩溃恢复**:进程任意时刻被杀,重开后 `load()` 得到的 `active_leaf` 等于最后一次成功持久化的值;半写事件被检测并丢弃(不损坏整个文件)。

## 验收标准

| AC | 测试(先失败) | 通过条件 |
|---|---|---|
| AC-1 | 单测:append×5 → branch_from(节点2)→ append×2 | `active_path` 长度与内容正确;原分支节点仍可访问 |
| AC-2 | 往返单测:任意操作序列 → persist → load | 重建树与内存树逐节点相等(含 meta) |
| AC-3 | 崩溃注入:持久化中途截断文件(模拟 kill) | `load` 成功,恢复到截断前最后完整事件;半写记录被丢弃且有日志 |
| AC-4 | 单测:rewind_to 后 append | 新节点挂在 rewind 目标下;被离开分支节点数不变 |
| AC-5 | 单测:reinject_summary | 主线出现 Summary 节点且 meta 含来源分支 id |
| AC-6 | 单测:RouteDecision 入树 | 重放后决策序列与 tracing 日志一致 |
| AC-7 | 属性测试:随机操作序列(append/branch/rewind)后不变量 | 无环;所有节点可达根;active_leaf 恒存在 |

## Non-goals

- 文件系统状态回滚(side-quest 真隔离):待裁定 D4。
- 跨机同步、多会话合并:单机单用户(report_v2 §0.2)。
- JSONL 与 SQLite 双后端同时交付:MVP 实现 `SessionStore` 的一个后端即可(建议 JSONL 先行),第二后端为后续 spec 变更。

## 开放关联

D4。
