# seekcode 开发验证 Harness 总纲(HARNESS)

> 定位:**非规范性**文档(宪章 7.1)——描述宪章约束如何落到 Claude Code 原生机制上,不新增任何约束。约束本体在 [CONSTITUTION.md](CONSTITUTION.md),本文只是执行布线图。
> 机制事实依据:2026-07-02 对 code.claude.com 官方文档的核对(hooks 事件与阻断语义、subagent frontmatter、skills/commands 合并、settings 权限字段)。

---

## 1. 四机制分工(设计原则)

| 机制 | 性质 | 用于 | 落点(全部入版本控制) |
|---|---|---|---|
| **CLAUDE.md** | 软约束:注入每次会话的上下文,模型引导,**无强制力** | 常驻认知:原则、顺序、依赖方向 | `./CLAUDE.md`(团队共享) |
| **hooks** | **硬门禁:确定性 shell 检查,exit 2 阻断**,模型无法说服它 | 可机械判定的违章:格式/lint/测试/依赖方向/spec 存在性 | `.claude/settings.json` + `.claude/hooks/*.sh` |
| **subagents** | 判断:独立上下文 + 受限工具集,产出结论供采纳 | 需要理解力的检查:spec 可测试性、红绿顺序合规、架构语义 | `.claude/agents/*.md` |
| **commands(skill)** | 流程:固化多步工作流,减少顺序漂移 | spec → 红 → 绿 → 重构 → 验收的编码任务流 | `.claude/skills/implement-spec/SKILL.md` |
| permissions(辅助) | 硬门禁:settings 的 deny/ask 规则 | 保护只读存档、敏感文件 | `.claude/settings.json` |

**判定规则**:一条约束若能写成"输入 → 确定性判定"的 shell 脚本 → hook;若需要读懂代码/文档才能判定 → subagent;若是"先后顺序"类纪律 → command 流程 + hook 兜底;其余 → CLAUDE.md。

**与 CI 的关系**:hooks 是宪章 7.2 CI 清单的**左移子集**——在写码/提交时拦截,CI 仍是最终强制层(三平台矩阵、MSRV、Miri 等本地跑不了的仍归 CI)。Harness 挂了不能替代 CI 过,CI 过了不豁免 harness。

## 2. 机制语义备忘(来自官方文档核对,设计依据)

- `PreToolUse` hook:exit 2 或 JSON `permissionDecision: deny` → **工具调用不发生**(真·预防)。
- `PostToolUse` hook:工具已执行,**不能撤销**;exit 2 → stderr 回灌给模型,模型被要求修复(确定性**检出**+强制修复,非预防)。
- `PreToolUse` 带 `if: "Bash(git commit*)"` 可精确匹配提交命令 → 提交前门禁的挂点。
- hooks 默认超时 600s(够跑 test+coverage);同事件并行执行。
- subagent frontmatter 支持 `tools`(allowlist)/`disallowedTools`/`model`/`memory`;`description` 决定自动委派时机。
- 自定义 slash command 已并入 skills;`.claude/skills/<name>/SKILL.md` 生成 `/name`,`disable-model-invocation: true` 限手动触发。

## 3. 宪章约束 → 机制映射表(核心交付)

图例:🔒 确定性阻断(hook/permissions/编译期)| 🔍 判断(subagent)| 📖 模型引导(CLAUDE.md)| ▶ 流程(command)| ☁ CI 独任(本地不可行)

| 宪章条款 | 约束 | 机制与落点 | 性质 | 说明 |
|---|---|---|---|---|
| 1.1 | 无 spec 不写实现 | ① hook `spec-anchor-check`(PostToolUse: Edit\|Write 于 `crates/**`,检查文件内 `pub` 项带 `Spec: SPEC-0xx` 且该 spec 文件存在,否则 exit 2 回灌)② CLAUDE.md 常驻规则 ③ /implement-spec 首步载入 spec | 🔒+📖+▶ | 存在性是机械判定 → 硬;spec **质量**归 1.1→3.2 的 spec-reviewer |
| 1.2 | FUTURE 不得实现 | ① hook `future-guard`(PreToolUse: Edit\|Write 于 `crates/**`,内容命中 FUTURE 关键词表 → deny)② CLAUDE.md 禁区清单 | 🔒+📖 | 关键词表是机械判定 → PreToolUse 真预防;语义级绕写由 spec-reviewer 兜底 |
| 1.3 | 未验证主张不对外 | hook `commit-gate` 内含 README/帮助文本禁用语 grep | 🔒 | 禁用语名单机械可查 |
| 1.4 | D 系列裁定前行为 | ① spec-reviewer 评审(判断"是否超出裁定前行为字面范围")② CLAUDE.md 列出 D1–D6 一句话边界 | 🔍+📖 | "超出范围"需理解力,无法 shell 判定 |
| 2.1 | 错误处理(禁 unwrap 等) | ① workspace.lints(编译期)② `commit-gate` 跑 `cargo clippy -D warnings` ③ CLAUDE.md 记 invariant 豁免格式 | 🔒+📖 | clippy deny 集是宪章检查方法原文 |
| 2.2 | unsafe 政策 | ① `#![forbid(unsafe_code)]`(编译期)② `commit-gate` 断言各 lib.rs 含该行 | 🔒 | 纯机械 |
| 2.3 | 依赖门槛与分层 | ① `commit-gate` 跑 `cargo deny check` + `layer-check.sh`(cargo metadata 对白名单)② 新依赖"四问"由 arch-checker 评审 ③ CLAUDE.md 记依赖方向简表 | 🔒+🔍+📖 | 分层是图判定 → 硬;"是否功能重复/维护状态"是判断 |
| 2.4 | MSRV 1.85 | ① `commit-gate` 校验 Cargo.toml `rust-version = "1.85"` 字段存在 ② 实际 1.85 编译验证 | 🔒(字段)+☁(编译) | 本地不装第二工具链,MSRV 编译归 CI |
| 2.5 | 三平台矩阵 | CI 独任;CLAUDE.md 提示"路径代码须写平台用例" | ☁+📖 | 本地单平台,无法硬门禁 |
| 3.1 | spec → test → impl 顺序 | ① /implement-spec 固化顺序 ② tdd-guard 检查会话内顺序 ③ CI commit 顺序核查 | ▶+🔍+☁ | 顺序是过程属性,本地 hook 无法回溯 commit 历史意图 |
| 3.2 | 规格收录标准前置 | spec-reviewer(判定"验收标准能否直接转测试") | 🔍 | 本质是理解力判断 |
| 3.3 | 参数与规格分离 | ① CLAUDE.md 规则"阈值只引用 §10,不硬编码" ② hook `spec-anchor-check` 附带 grep 裸魔法数字于强制名单层(告警不阻断) | 📖+🔒(弱) | 数字是否"参数"需上下文,只做启发式告警 |
| 4.1 | 红-绿-重构 | ① /implement-spec:写测试 → **强制先跑并确认失败**(红证据存 `.claude/tdd-evidence/`)→ 实现 → 绿 ② tdd-guard 抽查 | ▶+🔍 | "先红"是时序事实,command 流程内可确定性留痕;事后无法机械回溯 → 辅以 tdd-guard |
| 4.2 | 强制名单层先失败测试 | ① tdd-guard(diff 触碰名单层而无测试变更 → 报告)② CLAUDE.md 列名单 | 🔍+📖 | "行为变更 vs 重构"需判断;CI diff 检查兜底 |
| 4.3 | 覆盖率底线 70/80 | `commit-gate` 跑 `cargo llvm-cov --fail-under-lines 70`(强制名单 crate 单独 80) | 🔒 | 机械数值;注意:全量跑较慢,gate 内允许 `SKIP_COV=1` 时降级为告警并强制 CI 必查(降级本身打印在案) |
| 4.4 | 防腐测试①②常驻 | 属 `cargo test` 用例 → `commit-gate` 自然覆盖;删除/跳过由 spec-reviewer 盯宪章 6.2 | 🔒+🔍 | 测试存在性可 grep 断言 |
| 5.1 | 模型零直接副作用 | ① `pub(in crate::exec)` 可见性(编译期)② trybuild 用例(cargo test 内)③ 对抗用例集(cargo test 内) | 🔒 | 全部编译期/测试期,harness 只需保证 gate 跑 test |
| 5.2 | 内核零厂商知识 | `commit-gate` 内 `vendor-grep.sh`(kernel crate 源码 grep 词表) | 🔒 | 词表机械可查 |
| 5.3 | 路由层可摘除 | 防腐①(cargo test 覆盖,同 4.4) | 🔒 | — |
| 5.4 | 层间契约唯事件枚举 | ① crate 依赖图断言(同 2.3 layer-check)② serde 快照测试(cargo test 内) | 🔒 | — |
| 6.1 | 豁免留档 | ① hook `deviation-scan`(commit-gate 内:DEVIATIONS.md 过期条目 → exit 2)② 豁免格式完整性 grep | 🔒 | 日期比较机械可查 |
| 6.2 | 宪章修订流程 | ① permissions:`Edit(docs/CONSTITUTION.md)` 设 **ask**(改宪章先过人)② `commit-gate`:CONSTITUTION 有 diff 时断言修订记录表新增行 | 🔒 | 修订"合理性"归 spec-reviewer+用户 |
| 7.1 | 文档归属(report_v1 只读等) | permissions:`Edit(docs/report_v1.md)` 与 `Write(docs/report_v1.md)` 设 **deny** | 🔒 | 存档只读是机械规则 |
| 7.2 | CI 清单完整性 | ☁ CI 自查(配置注释映射);harness 不重复 | ☁ | — |

**硬/软边界的两句话总结**:凡是"文件内容/命令输出的确定性判定"全部走 hook 或编译期,模型说什么都拦;凡是"这算不算违章"需要读懂意图的,走 subagent 出报告、人做终裁;CLAUDE.md 只负责让模型**少犯**,从不负责**拦住**。

## 4. 交付物清单(已全部产出)

| 文件 | 内容 |
|---|---|
| `.claude/settings.json` | hooks 布线(PreToolUse: future-guard、commit-gate;PostToolUse: spec-anchor-check)+ permissions(report_v1 deny、CONSTITUTION ask)|
| `.claude/hooks/spec-anchor-check.sh` | 写入 `crates/**` 后:pub 项锚点 + spec 文件存在性;缺失 → exit 2。支持 CI 文件参数模式 |
| `.claude/hooks/future-guard.sh` | 写入前:内容对 FUTURE 关键词表(`future-keywords.txt`);命中 → deny |
| `.claude/hooks/commit-gate.sh` | `git commit` 前 9 步:fmt → clippy → test → coverage(`SKIP_COV=1` 在案降级)→ cargo-deny → layer-check → 治理组 → spec↔test → 宪章修订行;任一失败 → exit 2 |
| `.claude/hooks/layer-check.sh` | cargo tree 对 ARCHITECTURE §1.1 白名单(正向+反向断言) |
| `.claude/hooks/governance-lite.sh` | 治理检查组:厂商词表/forbid(unsafe)/rust-version/DEVIATIONS 过期/禁用语/FUTURE 源码扫描——**commit-gate 与 CI 共用,防漂移** |
| `.claude/hooks/spec-test-check.sh` | spec↔test 双向一致性:有实现锚点的 SPEC 必须有 `specNNN_acM_*` 测试;测试引用的 SPEC 必须存在 |
| `deny.toml` | license 允许表 + ban 清单(rusqlite/async-openai;anyhow 仅 bin) |
| `.github/workflows/ci.yml` | 宪章 7.2 全清单的最终强制层(6 jobs,顶部含条款号→job 映射注释);governance job 复用 `.claude/hooks/` 脚本 |
| `.claude/agents/spec-reviewer.md` | 工具:Read/Grep/Glob(只读)。职责:spec 完整性/可测试性/收录标准;不写码、不改文件 |
| `.claude/agents/tdd-guard.md` | 工具:Read/Grep/Glob/Bash(只读 git 命令)。职责:红绿顺序与名单层测试先行;不修测试 |
| `.claude/agents/arch-checker.md` | 工具:Read/Grep/Glob/Bash(cargo metadata/tree)。职责:依赖方向与模块边界语义;不改架构 |
| `.claude/skills/implement-spec/SKILL.md` | `/implement-spec <spec>`:载入 → 红(留痕)→ 绿 → 重构 → 验收命令 → 宪章自查清单 |
| `.claude/tdd-evidence/` | 红证据留痕目录(入库,git 可审计) |
| `docs/TASK_TEMPLATE.md` | 派发编码任务的标准格式(SPEC 引用/范围/红绿/验收命令/完成定义) |
| `CLAUDE.md` | 项目常驻记忆 |

## 4.1 检查阶段总览(哪个检查、何时触发、失败如何处理)

| 阶段 | 检查 | 失败处理 |
|---|---|---|
| **写入前**(PreToolUse) | future-guard:FUTURE/D 关键词 | 写入被拒绝(deny),模型收到毕业/豁免指引 |
| **写入后**(PostToolUse) | spec-anchor-check:锚点+spec 存在性;§10 参数硬编码(仅告警) | stderr 回灌,模型被强制补锚点/补 spec(文件已写入,须修复) |
| **提交前**(PreToolUse: git commit) | commit-gate 9 步全量 | 提交被拒绝,逐项列出未过检查与宪章条款;修复或走 DEVIATIONS |
| **CI**(push/PR) | ci.yml 6 jobs = 宪章 7.2 全清单(含本地跑不了的三平台/MSRV) | PR 不可合并;本地 gate 绿 ≠ CI 绿 |
| **按需**(判断类) | spec-reviewer / tdd-guard / arch-checker | 产出 PASS/FAIL 报告,修复由主会话执行,终裁在用户 |

## 5. 诚实边界(harness 做不到的)

1. **PostToolUse 不能撤销写入**——spec-anchor-check 是"写后必改",不是"写不进去";真预防只有 PreToolUse(future-guard 用之)。
2. **红证据无法事后机械验证**——只有 /implement-spec 流程内的当场留痕可信;绕过 command 手写代码时,红绿合规只剩 tdd-guard 的判断与 CI 抽查。
3. **本地是单平台**——2.5 三平台、2.4 MSRV 编译、Miri 全归 CI;commit-gate 绿不等于 CI 绿。
4. **hooks 可被用户以 `disableAllHooks` 关闭**——harness 防模型漂移,不防人;防人的层是 CI 分支保护。

## 修订记录

| 版本 | 日期 | 变更 |
|---|---|---|
| 1.0 | 2026-07-02 | 初版:四机制分工、宪章逐条映射、交付物清单、诚实边界 |
| 1.1 | 2026-07-02 | 交付物全部落地;新增 §4.1 检查阶段总览;新增 spec-test-check、governance-lite(本地/CI 共用)、deny.toml、ci.yml、TASK_TEMPLATE |
| 1.2 | 2026-07-02 | 门禁红队验证后修复:A) commit-gate 命令提取改为转义感知 + 全文兜底(修复引号旁路),B) layer-check 增加 Cargo.toml 文本级检查、未注册 crate 响亮 FAIL(修复静默盲区);新增 selftest.sh 固化缺陷 A 回归用例并接入 CI;三 subagent 经会话重载后实测在线(tdd-guard 真实派发产出违规判定) |
