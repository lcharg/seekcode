#!/usr/bin/env bash
# ============================================================================
# layer-check —— 宪章 2.3 / 5.4 硬门禁(依赖分层与方向)
# 触发方式 : 由 commit-gate.sh 调用(也可手动执行)
# 执行命令 : ① cargo tree 逐 crate 断言直接依赖 ⊆ 白名单(ARCHITECTURE §1.1 机检版)
#            ② 反向断言:rig-core/ratatui/crossterm/rusqlite 的消费者 ⊆ 允许集
# 失败信息 : 越界的 crate → 依赖对
# 为何硬门禁: 依赖图是 cargo 的确定性输出;架构腐化最常见路径就是"顺手加
#             一个依赖",必须机器拦截。语义级边界(模块内类型泄漏)归
#             arch-checker 判断,不在此。
# 白名单来源: docs/ARCHITECTURE.md §1.1(人类可读版);不一致时以宪章仲裁。
# ============================================================================
set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

if [ ! -d crates ]; then
  echo "WARN(layer-check): crates/ 不存在(脚手架期),分层检查跳过" >&2
  exit 0
fi

FAIL=0

allow_for() {
  case "$1" in
    seek-contract)     echo "serde thiserror tokio uuid chrono" ;;
    seek-kernel)       echo "seek-contract seek-session tokio serde thiserror tracing" ;;
    seek-session)      echo "seek-contract serde serde_json thiserror uuid" ;;
    seek-router)       echo "seek-contract serde thiserror tracing" ;;
    seek-adapter)      echo "seek-contract serde serde_json jsonschema thiserror tracing" ;;
    seek-config)       echo "seek-contract serde figment thiserror" ;;
    seek-provider-rig) echo "seek-contract rig-core tokio tracing" ;;
    seek-tui)          echo "seek-contract ratatui crossterm tui-textarea similar tokio" ;;
    seek-testkit)      echo "seek-contract tokio serde serde_json" ;;
    *)                 echo "__UNKNOWN__" ;;
  esac
}

for dir in crates/*/; do
  crate="$(basename "$dir")"
  allow="$(allow_for "$crate")"
  if [ "$allow" = "__UNKNOWN__" ]; then
    echo "FAIL(layer-check): 未登记的 crate「$crate」——先在 ARCHITECTURE §1.1 与本脚本白名单登记" >&2
    FAIL=1; continue
  fi

  # ① 文本级检查:直接读 Cargo.toml 的 [dependencies] 段。
  #    不依赖 workspace 注册——堵住验证报告缺陷 B(未注册 crate 曾是盲区)。
  manifest="${dir}Cargo.toml"
  if [ -f "$manifest" ]; then
    depsec="$(awk '/^\[dependencies\]/{f=1;next} /^\[/{f=0} f' "$manifest")"
    deps_txt="$(printf '%s\n' "$depsec" | awk '/^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/{sub(/[[:space:]]*=.*/,""); sub(/^[[:space:]]+/,""); print}')"
    renames="$(printf '%s\n' "$depsec" | grep -oE 'package[[:space:]]*=[[:space:]]*"[^"]+"' | sed 's/.*"\(.*\)"/\1/')"
    for d in $deps_txt $renames; do
      if ! printf ' %s ' $allow | grep -q " $d "; then
        echo "FAIL(layer-check/宪章 2.3): $crate → $d 不在白名单(Cargo.toml 文本级检出;见 ARCHITECTURE §1.1,确需新增走 PR 四问)" >&2
        FAIL=1
      fi
    done
  fi

  # ② 图级检查:cargo tree 解析真实依赖图。
  #    未注册进 workspace = 响亮 FAIL(缺陷 B 修复:此前 2>/dev/null 静默跳过)。
  if tree_out="$(cargo tree -p "$crate" -e normal --depth 1 --prefix none 2>&1)"; then
    deps_graph="$(printf '%s\n' "$tree_out" | tail -n +2 | awk '{print $1}' | sort -u)"
    for d in $deps_graph; do
      if ! printf ' %s ' $allow | grep -q " $d "; then
        echo "FAIL(layer-check/宪章 2.3): $crate → $d 不在白名单(依赖图检出;见 ARCHITECTURE §1.1)" >&2
        FAIL=1
      fi
    done
  else
    echo "FAIL(layer-check/宪章 2.3): $crate 存在于 crates/ 但 cargo tree 无法解析(通常=未注册进 workspace members)——注册后再过检,否则依赖图是盲区。cargo 输出:$(printf '%s' "$tree_out" | head -1)" >&2
    FAIL=1
  fi
done

check_inverse() {
  lib="$1"; allowed="$2"
  consumers="$(cargo tree -i "$lib" -e normal 2>/dev/null | sed 's/[│├└─]//g' | awk '{print $1}' | grep -E '^(seek|seekcode)' | sort -u || true)"
  for c in $consumers; do
    if ! printf ' %s ' $allowed | grep -q " $c "; then
      echo "FAIL(layer-check/宪章 2.3): $lib 被 $c 依赖——只允许:${allowed:-无人}" >&2
      FAIL=1
    fi
  done
}
check_inverse rig-core  "seek-provider-rig seekcode"
check_inverse ratatui   "seek-tui seekcode"
check_inverse crossterm "seek-tui seekcode"
check_inverse rusqlite  ""   # MVP 为 JSONL(ADR-005),rusqlite 出现即违章

exit $FAIL
