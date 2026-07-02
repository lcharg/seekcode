#!/usr/bin/env bash
# ============================================================================
# future-guard —— 宪章 1.2 硬门禁(FUTURE 内容不得进入实现)
# 触发事件 : PreToolUse(matcher: Edit|Write)→ 写入发生【之前】,exit 2 = 拒绝写入
# 执行命令 : 对 stdin 的工具入参 JSON 做 FUTURE 关键词表匹配(仅守护实现代码路径)
# 失败信息 : 命中的关键词 + 毕业流程指引(stderr 回灌给模型)
# 为何硬门禁: "内容含关键词 X" 是确定性判定,不依赖模型自觉;FUTURE 条目
#             一旦写进代码就形成事实,必须在写入前拦截(PostToolUse 无法撤销)。
#             语义级绕写(换名实现)本脚本不防,由 spec-reviewer 评审兜底。
# 依赖      : Git Bash(Windows 由 Git for Windows 提供)
# ============================================================================
set -uo pipefail

INPUT="$(cat)"

# 提取 file_path 并把 Windows 反斜杠(JSON 中为 \\)归一为 /
FILE_PATH="$(printf '%s' "$INPUT" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
  | sed 's/^.*:[[:space:]]*"//; s/"$//; s#\\\\#/#g; s#\\#/#g')"

# 只守护实现代码;文档、配置、测试夹具不拦(FUTURE.md 本身允许登记)
case "$FILE_PATH" in
  */crates/*|*/src/*.rs|src/*.rs) ;;
  *) exit 0 ;;
esac

KW_FILE="$(dirname "$0")/future-keywords.txt"
[ -f "$KW_FILE" ] || { echo "WARN(future-guard): 关键词表缺失 $KW_FILE,本次放行" >&2; exit 0; }

while IFS= read -r kw; do
  case "$kw" in ''|\#*) continue ;; esac
  if printf '%s' "$INPUT" | grep -qiE -- "$kw"; then
    {
      echo "BLOCKED(宪章 1.2 / 1.4):写入内容命中禁区关键词「$kw」(目标:$FILE_PATH)。"
      echo "FUTURE.md 条目与 D 系列待裁定项在毕业/裁定前不得实现。"
      echo "例外路径:① 按 FUTURE 条目毕业标准补证据 → 提升为正式 spec → spec-reviewer 通过;"
      echo "         ② 或在 docs/DEVIATIONS.md 留档豁免(带到期条件)。"
      echo "若属误报(合法用途撞词),请在 .claude/hooks/future-keywords.txt 调整词表并在 commit 说明。"
    } >&2
    exit 2
  fi
done < "$KW_FILE"

exit 0
