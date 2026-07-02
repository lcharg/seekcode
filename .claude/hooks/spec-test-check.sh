#!/usr/bin/env bash
# ============================================================================
# spec-test-check —— 宪章 1.1/4.2 硬门禁(spec ↔ test 一致性)
# 触发方式 : commit-gate.sh 调用 + CI governance job 调用(可手动执行)
# 执行命令 : 双向一致性:
#            ① 已进入实现的 spec(源码中存在 `Spec: SPEC-0xx` 锚点)必须有
#               至少一个 `specNNN_acM_*` 命名的测试 —— 有 spec 有实现无测试 → FAIL
#            ② 测试名引用的 specNNN 必须存在于 docs/specs/ —— 悬空引用 → FAIL
#            (spec 存在但尚未实现 → 仅 INFO,不算失败)
# 失败信息 : 缺测试的 SPEC 清单 / 悬空的测试名
# 为何硬门禁: "锚点存在 ∧ 测试命名匹配存在" 是纯 grep 判定;这是 TDD 纪律的
#             事后审计线——测试【质量】归 tdd-guard,不在此。
# ============================================================================
set -uo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

SPECS_DIR="docs/specs"
[ -d "$SPECS_DIR" ] || { echo "WARN(spec-test-check): $SPECS_DIR 不存在,跳过" >&2; exit 0; }

# 待扫描的源码根(存在才扫)
SRC_ROOTS=""
[ -d crates ] && SRC_ROOTS="$SRC_ROOTS crates"
[ -d src ]    && SRC_ROOTS="$SRC_ROOTS src"
[ -d tests ]  && SRC_ROOTS="$SRC_ROOTS tests"
[ -n "$SRC_ROOTS" ] || { echo "WARN(spec-test-check): 无源码目录,跳过" >&2; exit 0; }

FAIL=0

# ① 有实现锚点的 spec 必须有对应测试
for spec in "$SPECS_DIR"/SPEC-[0-9][0-9][0-9]-*.md; do
  [ -f "$spec" ] || continue
  id="$(basename "$spec" | grep -oE 'SPEC-[0-9]{3}')"
  n="${id#SPEC-}"
  if grep -rq --include='*.rs' "Spec: $id" $SRC_ROOTS 2>/dev/null; then
    if ! grep -rqE --include='*.rs' "fn spec${n}_ac[0-9]+_" $SRC_ROOTS 2>/dev/null; then
      echo "FAIL(spec-test-check/宪章 1.1): $id 已有实现锚点但无 spec${n}_acM_* 测试——TDD 顺序被颠倒或测试未按约定命名" >&2
      FAIL=1
    fi
  else
    echo "INFO(spec-test-check): $id 尚未进入实现(无锚点),跳过" >&2
  fi
done

# ② 测试引用的 spec 必须存在
for n in $(grep -rhoE --include='*.rs' 'fn spec[0-9]{3}_' $SRC_ROOTS 2>/dev/null | grep -oE '[0-9]{3}' | sort -u); do
  if ! ls "$SPECS_DIR"/SPEC-"$n"-*.md >/dev/null 2>&1; then
    echo "FAIL(spec-test-check/宪章 1.1): 测试 spec${n}_* 引用的 SPEC-$n 不存在于 $SPECS_DIR" >&2
    FAIL=1
  fi
done

exit $FAIL
