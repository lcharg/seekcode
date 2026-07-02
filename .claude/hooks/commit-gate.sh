#!/usr/bin/env bash
# ============================================================================
# commit-gate —— 提交前硬门禁(宪章 7.2 CI 清单的本地左移子集)
# 触发事件 : PreToolUse(matcher: Bash)→ 仅当命令是 `git commit` 时生效,
#            exit 2 = 拒绝执行提交命令(真·预防,提交不会发生)。
# 执行命令 : fmt → clippy → test → 覆盖率 → cargo-deny → 分层 → 厂商词表 →
#            forbid(unsafe) → rust-version → DEVIATIONS 过期 → 禁用语 →
#            宪章修订记录行
# 失败信息 : 逐项列出未过的检查与对应宪章条款
# 为何硬门禁: 全部是命令退出码/文本匹配的确定性判定;"提交前质量线"依赖
#             模型自觉必然漂移。检查对象尚不存在时(脚手架期)响亮 WARN 后
#             跳过——但 fmt/clippy/test 永不跳过。
# 逃生阀    : SKIP_COV=1 跳过覆盖率(打印在案,CI 仍必查);其余无逃生阀,
#             偏离走 docs/DEVIATIONS.md(宪章 6.1)。
# ============================================================================
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
# 仅拦 git commit;其余 Bash 命令放行(matcher 已是 Bash,这里做语义过滤)。
# 提取必须处理 JSON 转义引号(如 cd \"path\" && git commit):
# `"[^"]*` 会在第一个 \" 处截断导致静默放行(验证报告缺陷 A,已修复)。
CMD="$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1)"
# 提取失败(异常转义形态)时退回全文匹配——宁可对非提交命令多跑一遍检查,
# 也不可让真提交静默漏过(fail-closed)。
[ -n "$CMD" ] || CMD="$INPUT"
printf '%s' "$CMD" | grep -qE 'git([[:space:]]|\\+[nt])+commit' || exit 0

# 自测短路:GATE_SELFTEST=1 时只验证"匹配判定"本身,不跑真实检查。
# 供 selftest.sh 回归缺陷 A(转义引号旁路)使用,勿在正常提交时设置。
if [ "${GATE_SELFTEST:-0}" = "1" ]; then echo "GATE-MATCHED"; exit 0; fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

FAILED=()
warn() { echo "WARN(commit-gate): $*" >&2; }
fail() { FAILED+=("$1"); echo "FAIL(commit-gate): $1" >&2; }

# --- 1. cargo fmt(宪章 2.4)------------------------------------------------
cargo fmt --all --check >/dev/null 2>&1 || fail "cargo fmt --check 未过(宪章 2.4)——先跑 cargo fmt"

# --- 2. clippy 零警告(宪章 2.1/2.4)---------------------------------------
if ! cargo clippy --all-targets -- -D warnings >/dev/null 2>&1; then
  fail "cargo clippy -D warnings 未过(宪章 2.1)——含 unwrap/expect/panic deny 集"
fi

# --- 3. 测试全绿(宪章 4.4 防腐测试随 test 覆盖)---------------------------
if ! cargo test --workspace --quiet >/dev/null 2>&1; then
  fail "cargo test 未全绿(宪章 4.1/4.4)"
fi

# --- 4. 覆盖率门槛(宪章 4.3;SKIP_COV=1 降级为告警,CI 必查)--------------
if [ "${SKIP_COV:-0}" = "1" ]; then
  warn "覆盖率检查被 SKIP_COV=1 跳过(在案;CI 仍强制 70/80)"
elif ! command -v cargo-llvm-cov >/dev/null 2>&1; then
  fail "cargo-llvm-cov 未安装(宪章 4.3)——安装:cargo install cargo-llvm-cov;或本次 SKIP_COV=1(在案)"
else
  if ! cargo llvm-cov --workspace --fail-under-lines 70 --quiet >/dev/null 2>&1; then
    fail "workspace 行覆盖率 < 70%(宪章 4.3)"
  fi
  for c in seek-kernel seek-router seek-config seek-session seek-adapter; do
    [ -d "crates/$c" ] || continue
    if ! cargo llvm-cov -p "$c" --fail-under-lines 80 --quiet >/dev/null 2>&1; then
      fail "$c 行覆盖率 < 80%(宪章 4.3 强制名单)"
    fi
  done
fi

# --- 5. cargo-deny(宪章 2.3)----------------------------------------------
if [ -f deny.toml ]; then
  if command -v cargo-deny >/dev/null 2>&1; then
    cargo deny check >/dev/null 2>&1 || fail "cargo deny check 未过(宪章 2.3:license/bans/advisories)"
  else
    fail "deny.toml 存在但 cargo-deny 未安装(宪章 2.3)——cargo install cargo-deny"
  fi
else
  warn "deny.toml 不存在(脚手架期),cargo-deny 跳过;首个外部依赖引入前必须补上"
fi

# --- 6. 依赖分层(宪章 2.3/5.4)--------------------------------------------
bash "$(dirname "$0")/layer-check.sh" || fail "依赖分层检查未过(宪章 2.3/5.4,详见上方 layer-check 输出)"

# --- 7. 治理检查组(宪章 1.2/1.3/2.2/2.4/5.2/6.1;与 CI 共用同一脚本)------
bash "$(dirname "$0")/governance-lite.sh" || fail "治理检查组未过(详见上方 governance 输出)"

# --- 8. spec ↔ test 一致性(宪章 1.1/4.2)-----------------------------------
bash "$(dirname "$0")/spec-test-check.sh" || fail "spec↔test 一致性未过(有实现锚点的 SPEC 缺 specNNN_acM_* 测试,或测试引用悬空)"

# --- 9. 宪章修订记录行(宪章 6.2)-------------------------------------------
if git diff --cached --name-only 2>/dev/null | grep -q '^docs/CONSTITUTION.md$'; then
  if ! git diff --cached docs/CONSTITUTION.md | grep -E '^\+\|' | grep -qE '^\+\| *[0-9]+\.[0-9]+ *\|'; then
    fail "本次提交改了 CONSTITUTION.md 但修订记录表无新增行(宪章 6.2)"
  fi
fi

# --- 汇总 --------------------------------------------------------------------
if [ "${#FAILED[@]}" -gt 0 ]; then
  {
    echo ""
    echo "BLOCKED:提交被 commit-gate 拒绝,共 ${#FAILED[@]} 项未过:"
    for f in "${FAILED[@]}"; do echo "  ✗ $f"; done
    echo "修复后重试;确需偏离走 docs/DEVIATIONS.md(宪章 6.1)。"
  } >&2
  exit 2
fi
exit 0
