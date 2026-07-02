#!/usr/bin/env bash
# ============================================================================
# governance-lite —— 治理检查组(纯文本判定,commit-gate 与 CI 共用防漂移)
# 触发方式 : commit-gate.sh 第 7 步调用;CI governance job 调用;可手动执行
# 覆盖条款 : 5.2 厂商词表 / 2.2 forbid(unsafe) / 2.4 rust-version /
#            6.1 DEVIATIONS 过期 / 1.3 对外禁用语 / 1.2 FUTURE 关键词扫描
# 失败信息 : 逐项列出命中位置与宪章条款
# 为何硬门禁: 六项全部是 grep/字段级确定性判定;抽成独立脚本使本地门禁与
#             CI 跑的是同一份逻辑,不会各改各的产生漂移。
# ============================================================================
set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

FAIL=0
fail() { echo "FAIL(governance): $1" >&2; FAIL=1; }
warn() { echo "WARN(governance): $1" >&2; }

# --- 5.2 kernel 厂商词表 -----------------------------------------------------
if [ -d crates/seek-kernel/src ]; then
  HITS="$(grep -rniE 'anthropic|openai|gemini|claude|gpt-|ollama|mistral|deepseek' crates/seek-kernel/src --include='*.rs' | grep -vE ':[[:space:]]*//' || true)"
  [ -n "$HITS" ] && { echo "$HITS" >&2; fail "kernel 源码含厂商/模型名(宪章 5.2)"; }
fi

# --- 2.2 forbid(unsafe_code) -------------------------------------------------
if [ -d crates ]; then
  for lib in crates/*/src/lib.rs; do
    [ -f "$lib" ] || continue
    grep -q '#!\[forbid(unsafe_code)\]' "$lib" || fail "$lib 缺 #![forbid(unsafe_code)](宪章 2.2;例外须 DEVIATIONS 留档)"
  done
fi

# --- 2.4 rust-version --------------------------------------------------------
grep -q 'rust-version *= *"1.85"' Cargo.toml || fail "Cargo.toml 缺 rust-version = \"1.85\"(宪章 2.4)"

# --- 6.1 DEVIATIONS 过期 -----------------------------------------------------
if [ -f docs/DEVIATIONS.md ]; then
  TODAY="$(date +%F)"
  while IFS= read -r line; do
    d="$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
    [ -n "$d" ] && [ "$d" \< "$TODAY" ] && fail "DEVIATIONS.md 有已过期豁免(到期 $d,宪章 6.1)——清理或续期"
  done < <(grep '到期条件' docs/DEVIATIONS.md | grep -v '^<!--' || true)
fi

# --- 1.3 对外禁用语(F1 毕业前不得宣称路由收益)-----------------------------
for f in README.md; do
  [ -f "$f" ] || continue
  BAD="$(grep -nE '(路由|routing).{0,60}((节省|省|降低).{0,10}成本|保(持|住).{0,6}质量)|((节省|省|降低).{0,10}成本).{0,60}(路由|routing)' "$f" || true)"
  [ -n "$BAD" ] && { echo "$BAD" >&2; fail "$f 含未验证的路由收益主张(宪章 1.3;F1 毕业前只能说'机制可用')"; }
done

# --- 1.2 FUTURE 关键词扫描(已提交源码;写入时另有 future-guard 拦截)-------
KW_FILE="$(dirname "$0")/future-keywords.txt"
if [ -f "$KW_FILE" ] && [ -d crates ]; then
  while IFS= read -r kw; do
    case "$kw" in ''|\#*) continue ;; esac
    HITS="$(grep -rniE --include='*.rs' -- "$kw" crates/*/src src 2>/dev/null | grep -vE ':[[:space:]]*//' || true)"
    [ -n "$HITS" ] && { echo "$HITS" >&2; fail "源码命中 FUTURE/D 禁区关键词「$kw」(宪章 1.2/1.4)"; }
  done < "$KW_FILE"
fi

exit $FAIL
