#!/usr/bin/env bash
# ============================================================================
# spec-anchor-check —— 宪章 1.1 硬门禁(无 spec 不写实现)
# 触发事件 : PostToolUse(matcher: Edit|Write)→ 写入【之后】检出。
#            注意语义:PostToolUse 无法撤销已写入的文件;exit 2 将 stderr 回灌
#            给模型并强制其修复(补锚点或补 spec)——是"写得进但过不了",
#            不是"写不进去"(该语义已在 docs/HARNESS.md §5 声明)。
# 执行命令 : 对刚写入的 crates/**/src/**/*.rs:
#            ① 每个顶层 `pub fn|struct|enum|trait` 上方 doc 注释须含 `Spec: SPEC-0xx`
#            ② 文件中引用的每个 SPEC-0xx 必须真实存在于 docs/specs/
#            ③ (告警不阻断)§10 参数疑似硬编码启发式
# 失败信息 : 缺锚点的行号清单 / 悬空 SPEC 引用
# 为何硬门禁: "锚点存在 + spec 文件存在" 是纯文本判定;这是 SDD 的最后一道
#             机械防线——spec 的【质量】判断归 spec-reviewer,不在此。
# ============================================================================
set -uo pipefail

# 双模式:CI/手动传文件路径参数;hook 模式读 stdin JSON
if [ "$#" -ge 1 ]; then
  FILE_PATH="$(printf '%s' "$1" | sed 's#\\#/#g')"
else
  INPUT="$(cat)"
  FILE_PATH="$(printf '%s' "$INPUT" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
    | sed 's/^.*:[[:space:]]*"//; s/"$//; s#\\\\#/#g; s#\\#/#g')"
fi

# 适用范围:crates/**/src/**/*.rs;豁免:tests/、benches/、bin/、build.rs(宪章 1.1:bin 豁免)
case "$FILE_PATH" in
  */crates/*/src/*.rs|crates/*/src/*.rs) ;;
  *) exit 0 ;;
esac
case "$FILE_PATH" in
  */tests/*|*/benches/*|*/src/bin/*|*/build.rs|tests/*) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SPECS_DIR="$PROJECT_DIR/docs/specs"

# ① 顶层 pub 项须带锚点(pub(crate)/pub(in ...) 非公开 API,不要求)
MISSING="$(awk '
  /^[[:space:]]*\/\/\// { if ($0 ~ /Spec: SPEC-[0-9][0-9][0-9]/) has=1; next }
  /^[[:space:]]*#\[/    { next }
  /^pub (async )?(fn|struct|enum|trait) / {
      if (!has) printf "  L%d: %s\n", NR, $0
      has=0; next
  }
  { has=0 }
' "$FILE_PATH")"

# ② 引用的 SPEC 必须存在
DANGLING=""
for id in $(grep -oE 'SPEC-[0-9]{3}' "$FILE_PATH" | sort -u); do
  if ! ls "$SPECS_DIR"/"$id"-*.md >/dev/null 2>&1; then
    DANGLING="$DANGLING $id"
  fi
done

if [ -n "$MISSING" ] || [ -n "$DANGLING" ]; then
  {
    echo "BLOCKED(宪章 1.1):$FILE_PATH 未通过 spec 锚点检查。"
    if [ -n "$MISSING" ]; then
      echo "以下公开项缺少 doc 首部锚点(格式:/// Spec: SPEC-0xx):"
      echo "$MISSING"
    fi
    [ -n "$DANGLING" ] && echo "以下 SPEC 引用在 docs/specs/ 中不存在:$DANGLING"
    echo "处理:为每个公开项补 \`/// Spec: SPEC-0xx\` 并确认 spec 存在;无对应 spec → 先走宪章 3.1 补 spec,再实现。"
  } >&2
  exit 2
fi

# ③ 参数硬编码启发式(宪章 3.3;仅告警,exit 0)
SUSPECT="$(grep -nE '(^|[^0-9._])(4000|0\.8|0\.5)([^0-9]|$)' "$FILE_PATH" | grep -v '^\s*//' | head -5 || true)"
if [ -n "$SUSPECT" ]; then
  echo "WARN(宪章 3.3):疑似 §10 参数硬编码(应从配置读取):" >&2
  echo "$SUSPECT" >&2
fi

exit 0
