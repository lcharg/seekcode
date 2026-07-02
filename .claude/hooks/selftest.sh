#!/usr/bin/env bash
# ============================================================================
# selftest —— 门禁自身的回归测试(验证报告缺陷 A 的固化用例)
# 触发方式 : 手动执行 / CI governance job
# 断言     : P1 带转义引号的 git commit(cd \"path\" && git commit)必须被匹配
#            P2 非提交命令必须静默放行
#            P3 description 提及 commit 但 command 不是 → 必须放行(提取精确性)
# 为何存在 : 2026-07-02 验证发现旧提取正则被 JSON 转义引号截断导致静默放行;
#            本自测防止该缺陷在后续改动中复发。
# ============================================================================
set -uo pipefail
GATE="$(dirname "$0")/commit-gate.sh"
FAIL=0

t() { # t <名称> <期望:match|pass> <payload>
  name="$1"; expect="$2"; payload="$3"
  out="$(printf '%s' "$payload" | GATE_SELFTEST=1 bash "$GATE" 2>&1)"; rc=$?
  case "$expect" in
    match) [ "$out" = "GATE-MATCHED" ] || { echo "SELFTEST FAIL[$name]: 期望匹配 git commit,实际未匹配(缺陷 A 复发?)" >&2; FAIL=1; } ;;
    pass)  { [ $rc -eq 0 ] && [ -z "$out" ]; } || { echo "SELFTEST FAIL[$name]: 期望静默放行,实际 rc=$rc out=$out" >&2; FAIL=1; } ;;
  esac
}

# P1:真实形态——cd 带引号路径 + git commit(旧正则在 \" 处截断而漏放)
t "P1-quoted-commit" match '{"tool_input":{"command":"cd \"d:/some path/repo\" && git commit -m \"msg\""}}'
# P1b:朴素形态
t "P1b-plain-commit" match '{"tool_input":{"command":"git commit --amend"}}'
# P2:非提交命令
t "P2-non-commit" pass '{"tool_input":{"command":"cargo build --workspace"}}'
# P3:description 提及 commit,command 不是——验证按字段提取而非全文误判
t "P3-desc-mention" pass '{"tool_input":{"command":"ls -la","description":"list files before running git commit later"}}'

[ $FAIL -eq 0 ] && echo "selftest: 4/4 通过"
exit $FAIL
