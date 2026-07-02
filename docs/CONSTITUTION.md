# seekcode 项目宪章(CONSTITUTION)

> 地位:本文件是仓库的最高治理文档。文档优先级:**宪章 > 核心规格([report_v2.md](report_v2.md))> 架构/实现文档 > 代码注释**。低层文档与宪章冲突时,以宪章为准;修改宪章走第 6 章变更控制。
> 收录标准与核心规格一致:每条原则必须**可执行、可检查**——条文本身给出规则,紧随的「检查」给出验证方法。无法给出检查方法的表述不得写入本宪章。
> AGENTS.md 中的宪章摘要是本文件的指针;两者不一致时以本文件为准。

---

## 第 1 章 不可协商原则

### 1.1 无 spec 不写实现

任何公开 API(workspace 内 `pub` 且被跨 crate 使用,或对用户可见的行为)必须能追溯到核心规格的具体条目(如 `report_v2.md §3.3.2`)。规格中不存在的能力,先补规格再写代码;规格补入的前提是满足「先失败的测试 + 通过条件」收录标准。

**检查**:
- PR 模板含必填项「对应 spec 条目:SPEC-0xx 或 §___」;无法填写的 PR 不予合并。
- 公开 API 的 rustdoc 首行注明规格锚点(格式 `Spec: SPEC-0xx`,指向 `docs/specs/`;`docs/specs/README.md` 索引提供 SPEC ↔ report_v2 § 的双向映射);CI 以脚本 grep 校验所有 `pub` trait/struct/fn 的文档含 `Spec:` 标记(kernel/router/provider crate 强制,bin crate 豁免)。
- `#![deny(missing_docs)]` 于库 crate 生效(missing_docs 是 rustc 内建 lint,`cargo check` 即可验证)。

### 1.2 FUTURE 内容不得进入实现(毕业条款)

[FUTURE.md](FUTURE.md) 登记的任何条目不得实现。唯一例外路径,三步缺一不可:
1. 按该条目「毕业标准」补齐证据;
2. 提升为核心规格的正式条目(带验收标准);
3. 通过 spec-reviewer 评审(评审记录落在对应 PR)。

**检查**:
- PR 模板含必答项「本 PR 是否涉及 FUTURE.md 条目?若是,附毕业 PR 链接与 spec-reviewer 评审记录」。
- CI 脚本维护 FUTURE 条目关键词表(如 `learned router` / `probe` / `llm judge` / 决策门指标名),对 `src/` 新增代码命中即失败,豁免须引用毕业记录。关键词表随 FUTURE.md 更新。

### 1.3 未验证主张不得作为事实对外表述

FUTURE 条目的效果主张(如「省成本保质量」)在毕业前不得出现在 README、发布说明、帮助文本中作为结论;只能以「机制可用/假设待验证」表述。

**检查**:发布物(README、`--help` 输出、release notes)进 PR 评审清单;CI 对 README 与 help 文本 grep 禁用语(「节省成本」「保持质量」等断言句式绑定路由特性),名单随 FUTURE.md 维护。

### 1.4 待裁定项(D 系列)不得据以实现

`report_v2.md §9` 的 D1–D6 在裁定前只允许其中明确标注的「裁定前行为」进入代码(如 D1 的 `Summarize`/`failed_attempts` 打标)。

**检查**:PR 引用 D 条目时,评审核对实现是否超出「裁定前行为」的字面范围;裁定完成的标志是该条从 §9 移入正式规格条目(git 历史可查)。

---

## 第 2 章 Rust 工程约束

### 2.1 错误处理

- 库 crate(kernel/router/provider/tools/tui 组件)错误类型用 `thiserror` 定义,禁止对外暴露 `anyhow::Error`;`anyhow` 仅允许出现在 bin crate。
- 非测试代码禁止 `unwrap()`/`expect()`/`panic!()`/`todo!()`/`unimplemented!()`。唯一豁免:表达程序不变量,且 `expect()` 消息以 `invariant:` 开头说明为何不可能失败。
- 主循环、权限 dispatcher、Provider 适配路径必须 panic-free:错误一律转为 `ProviderEvent::Error` / `Deny` / 用户可见的失败事件。

**检查**:
- workspace `Cargo.toml` 的 `[workspace.lints.clippy]` 设 `unwrap_used = "deny"`、`expect_used = "deny"`、`panic = "deny"`、`todo = "deny"`、`unimplemented = "deny"`;测试代码以 `#[cfg(test)]` 局部 `allow`。CI 跑 `cargo clippy --all-targets -- -D warnings`。
- 豁免的 `expect("invariant: ...")` 处加 `#[allow(clippy::expect_used)]`;CI 脚本核对每个该 allow 的下一行消息含 `invariant:` 前缀。
- `anyhow` 依赖边界由 2.3 的依赖分层检查覆盖(只允许 bin crate 引入)。

### 2.2 unsafe 政策

- 全 workspace 默认 `#![forbid(unsafe_code)]`(每个库 crate 根)。
- 引入 unsafe 需:① 走第 6 章变更控制留档;② 收敛到独立模块;③ 每个 unsafe 块带 `// SAFETY:` 注释;④ 该模块进 Miri CI job。

**检查**:CI 脚本断言每个库 crate 的 `lib.rs` 含 `#![forbid(unsafe_code)]`;例外 crate 必须出现在 `docs/DEVIATIONS.md` 的对应记录中,且 CI 配置里存在其 Miri job。`cargo geiger` 报告作为 PR 参考件。

### 2.3 依赖引入门槛与分层

- 新增依赖须在 PR 描述中回答四问:与现有依赖是否功能重复;维护状态(最近一次发版 < 12 个月,否则说明理由);license 在允许表内(MIT / Apache-2.0 / BSD-2/3 / Zlib / Unicode);是否只进入其所属层。
- **依赖分层(硬约束)**:kernel crate 不得依赖 rig / genai / ratatui / crossterm / rusqlite——它只依赖 workspace 内部契约/会话 crate(seek-contract、seek-session)与 std/tokio/serde/thiserror/tracing;厂商 SDK 只进 provider 后端 crate;TUI 库只进 tui crate。完整依赖方向表见 `docs/ARCHITECTURE.md` §1.1(人类可读版;机检以入库白名单为准)。
- 版本策略:`Cargo.lock` 入库;厂商 SDK(rig/genai)pin 精确版本(`=x.y.z`),升级走独立 PR。

**检查**:
- `cargo deny check`(licenses / bans / advisories / sources)为 CI 必过项,允许表写在 `deny.toml`。
- CI 脚本用 `cargo metadata` 断言 kernel crate 的直接依赖集合是声明白名单的子集(白名单文件入库,改动即触发评审)。
- `cargo tree -i rig` / `-i ratatui` 结果只含各自所属 crate,脚本断言。

### 2.4 MSRV 与工具链

- MSRV = **1.85**(Edition 2024 基线,当前 `Cargo.toml` 已声明 edition 2024)。提高 MSRV 走第 6 章变更控制。
- 格式与 lint 以 pinned 工具链执行,消除环境漂移。

**检查**:`Cargo.toml` 声明 `rust-version = "1.85"`;CI 矩阵含一个 `1.85` job 跑 `cargo check --all-targets`;另有 stable job 跑完整测试。`cargo fmt --check` 与 clippy 均为必过项。

### 2.5 平台矩阵

MVP 支持 Linux / macOS / Windows 三平台(权限 dispatcher 的路径规则须处理各平台差异,如 Windows 符号链接语义;L2 sandbox 依 D5 裁定,不在承诺内)。

**检查**:CI 测试矩阵含 ubuntu / macos / windows;§2.2.1 权限用例集(含平台特定路径样例)在三平台全绿。

---

## 第 3 章 SDD 流程约束

### 3.1 顺序不可颠倒:spec → test → implementation

新能力的合并顺序:规格条目(含验收标准)先行合入或与实现同 PR 但独立 commit 在前;测试 commit 先于或同于实现 commit;不存在「先实现后补 spec」。

**检查**:
- PR 评审清单首项:「spec 条目存在且含验收标准?」——引用不存在的 §号直接打回。
- PR 内 commit 顺序核查:规格/测试类改动(`docs/`、`tests/`、`#[cfg(test)]`)在实现改动之前;做不到时(如重构)在 PR 描述声明理由,评审裁量。

### 3.2 规格收录标准前置

向核心规格新增条目时,条目本身必须携带「先失败的测试(或可执行检验)+ 通过条件」;写不出的,按 `report_v2.md` 序言分流(FUTURE / §9 待裁定 / 舍弃)。

**检查**:spec PR 的评审模板含单选:「该条目的验收标准我能照着直接写出测试:是/否」——评审人勾"否"即打回。

### 3.3 参数与规格分离

`report_v2.md §10` 参数表中的默认值调整不算规格变更(改配置 + 更新参数表即可);新增参数或改变参数语义算规格变更,走 3.1。

**检查**:PR diff 只动参数值 → 快速通道;diff 涉及参数表行的增删或「用处」列 → 要求 spec 条目更新。

---

## 第 4 章 TDD 约束

### 4.1 红-绿-重构

每个功能 PR 必须能展示"测试先失败":新增测试在实现前的 commit 上运行应失败(红),实现后通过(绿),重构不改变测试语义。

**检查**:PR 描述必填「红证据」:粘贴测试在无实现状态下的失败输出,或 CI 提供 `git checkout <test-commit> && cargo test <name>` 的失败记录。评审抽查:revert 实现 commit 后对应测试必须转红。

### 4.2 必须"先有失败测试"的层(强制名单)

以下层的任何行为变更,先写失败测试,无豁免:

| 层 | 测试形态(规格出处) |
|---|---|
| 权限 dispatcher | 表驱动纯函数测试 + 对抗用例集(§2.2.1) |
| 路由器 | 规则表逐行 + 边界用例(§3.3.2) |
| compat flags / models.json 解析 | 反序列化用例集 + 逐 flag 行为(§6.2 步 4) |
| 上下文压缩 | 触发阈值 + tool_use/tool_result 配对完整性(§2.3) |
| SessionTree | 分支/rewind/崩溃恢复往返(§6.2 步 6) |
| 适配层(模板/校验/fallback) | 快照 + 畸形样例集 + fallback 终止(§3.4) |

豁免层:bin 入口、纯 UI 排版微调(仍须更新 `TestBackend` 快照)、文档。

**检查**:PR 触碰上表对应 crate/模块而无新增或修改测试 → CI 脚本(diff 路径匹配)标记,评审必须显式批注豁免理由才可合并。

### 4.3 覆盖率底线

- 行覆盖率:强制名单各层 ≥ 80%,workspace 总体 ≥ 70%。bin crate 与生成代码除外。
- 覆盖率只作底线不作目标:禁止为凑数写无断言测试。

**检查**:CI 跑 `cargo llvm-cov --fail-under-lines 70`,并对强制名单 crate 单独 `--fail-under-lines 80`。无断言测试由评审清单项「新测试是否都含实质断言」把关。底线数值的调整走第 6 章。

### 4.4 CI 防腐测试为常驻必过项

规格定义的两条防腐测试(`report_v2.md §3.5`)是 CI 永久必过项:① `SingleModelRouter` 替换 Router 跑全部内核测试;② mock 厂商仅通过 `models.json` 接入的集成测试。

**检查**:CI 配置中两 job 存在且必过;删除或跳过这两个 job 的 PR 视同宪章变更(第 6 章)。

---

## 第 5 章 Harness 与 Agent(模型)职责分离

### 5.1 模型零直接副作用

模型(经 Provider 层)对进程外世界的唯一表达是 `tool_use` 事件;文件/shell/网络副作用只能由工具执行路径产生,且该路径必经权限 dispatcher 的 `check()`。

**检查**:结构性强制——`Tool::execute` 的可见性限定为 dispatcher 模块内(`pub(in ...)`),内核其它代码无法直接调用(编译期保证);Provider crate 依赖白名单中无文件/进程类 crate(2.3 分层检查覆盖);对抗用例集 0 逃逸(§2.2.1)持续回归。

### 5.2 内核零模型专属知识

编排内核不含任何模型/厂商专属常量(模型名、API 格式、提示模板、路由规则);差异全部由 Provider compat flags 与路由层配置吸收。

**检查**:CI 脚本对 kernel crate 源码 grep 厂商与模型名词表(`anthropic|openai|gemini|claude|gpt|ollama` 等,词表入库维护),命中即失败;CI 防腐测试 ①② 通过;新增模型只改 `models.json` 的集成测试常绿。

### 5.3 路由层可整体摘除

路由层是插件:摘除(替换为 `SingleModelRouter`)后,harness 全部功能不减,仅失去多模型选择。

**检查**:CI 防腐测试 ①;发布物提供 `--router none` 等价的运行模式,冒烟测试覆盖。

### 5.4 层间契约只经事件枚举

`ProviderEvent`(Provider→内核)与 `AgentEvent`(内核→TUI)是层间唯一契约;TUI 不得反向 import 内核内部类型,内核不得 import TUI 类型。

**检查**:2.3 的依赖分层断言(crate 依赖图无反向边);两枚举的变更必须同 PR 更新其序列化快照测试(§6.2 步 1),快照 diff 即契约变更信号。

---

## 第 6 章 变更控制

### 6.1 允许偏离宪章的唯一形式:留档豁免

满足全部条件方可偏离:① 偏离是临时的且有到期条件;② 在 `docs/DEVIATIONS.md` 追加记录;③ 对应 PR 链接该记录。记录格式(每条必填):

```markdown
## DEV-<序号>
- 日期:
- 偏离条款:(如 宪章 2.2)
- 内容与理由:
- 影响范围:(crate/模块)
- 到期条件:(某 PR 合入 / 某裁定完成 / 具体日期)
- 批准人:
```

**检查**:CI 中被豁免的检查项必须在配置里引用 `DEV-<序号>`;CI 定期 job 扫描 DEVIATIONS.md,到期条件含日期且已过期的记录 → CI 失败,强制清理。

### 6.2 宪章修订

修订本文件需:独立 PR、PR 描述说明动机与影响、spec-reviewer 评审通过、文末修订记录表追加一行。数值类条款(MSRV、覆盖率底线)的修改同样走此流程。

**检查**:CI 对触碰 `docs/CONSTITUTION.md` 的 PR 校验修订记录表是否新增行;AGENTS.md 摘要与本文件的一致性列入该 PR 评审清单。

### 6.3 什么不算偏离

- §10 参数表默认值调整(见 3.3);
- FUTURE.md 新增登记条目(登记本身不受限,实现才受限);
- 测试与文档的补强。

**检查**:评审按此清单分流,避免把常规改动误升级为豁免流程。

---

## 第 7 章 文档体系与本宪章的执行落地

### 7.1 文档层级与归属

| 文档 | 角色 | 变更流程 |
|---|---|---|
| `docs/CONSTITUTION.md` | 宪章(本文件) | 6.2 |
| `docs/report_v2.md` | 核心规格(总纲与索引级规范) | 3.1 / 3.2 |
| `docs/specs/SPEC-*.md` | 规范性功能规格(逐能力分解;与 report_v2 冲突时以 report_v2 为准) | 3.1 / 3.2 |
| `docs/ARCHITECTURE.md` | 架构文档(非规范性;不得含"必须/不得"级新约束) | 普通 PR;涉宪章条款时走 6.2 |
| `docs/FUTURE.md` | 未来特性登记册(非规范) | 登记自由,实现受 1.2 |
| `docs/DEVIATIONS.md` | 豁免台账 | 6.1 |
| `AGENTS.md` | agent 入口指引(含宪章指针) | 与宪章同步,见 6.2 检查 |
| `report_v1.md` | 调研存档(只读) | 不再修改 |

**检查**:上述文件存在性由 CI 脚本断言(DEVIATIONS.md 允许为空模板);规范性表述只允许出现在宪章与核心规格——评审发现其它文档出现"必须/不得"级条款时要求迁移。

### 7.2 CI 检查项清单(本宪章的机检落点汇总)

CI 必过项:`cargo fmt --check`;`cargo clippy --all-targets -- -D warnings`(含 2.1 lint 集);`cargo test`(三平台矩阵);MSRV job(2.4);`cargo deny check`(2.3);依赖分层断言脚本(2.3/5.4);kernel 词表 grep(5.2);防腐测试 ①②(4.4);覆盖率门槛(4.3);`#![forbid(unsafe_code)]` 断言(2.2);`Spec:` 文档标记校验(1.1);FUTURE 关键词扫描(1.2);DEVIATIONS 过期扫描(6.1)。

**检查**:本清单与 CI 配置的对应关系在 CI 配置文件顶部以注释映射(条款号 → job 名);删改任何一项视同宪章修订。

---

## 修订记录

| 版本 | 日期 | 变更 | 评审 |
|---|---|---|---|
| 1.0 | 2026-07-02 | 初版,依据 report_v2.md(隔离修订后)起草 | 待 spec-reviewer |
| 1.1 | 2026-07-02 | 承认 `docs/specs/` 为规范性逐能力规格(7.1);rustdoc 锚点格式改为 `Spec: SPEC-0xx`(1.1);依赖分层措辞明确内部 crate 白名单并链接 ARCHITECTURE §1.1(2.3);7.1 增补 ARCHITECTURE.md 条目 | 用户批准(会话内) |
