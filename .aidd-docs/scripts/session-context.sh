#!/usr/bin/env bash
# 新しいセッションの冒頭に「いまどのループのどの段階にいるか」を数行だけ出力する。
# 読み取り専用。判定に失敗しても常に終了コード 0 で終わる（セッション開始を妨げないため）。
# 契約とテストは同ディレクトリの session-context.test.sh を参照。

SPECS_DIR=".aidd-docs/specs"

[ -d "$SPECS_DIR" ] || exit 0

report_no_loop() {
  printf '[aidd] 進行中のループはありません\n'
  exit 0
}

# frontmatter から1つの値を読む。
# 先頭行が --- でなければ frontmatter 無しとみなし、空を返す。
# 値は最初の # 以降を落として前後の空白を除去する。改行を含む値は空として扱う。
fm_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0

  local first
  IFS= read -r first <"$file" 2>/dev/null || return 0
  first="${first%$'\r'}"
  [ "$first" = "---" ] || return 0

  local line found="" n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then
      continue
    fi
    line="${line%$'\r'}"
    if [ "$line" = "---" ]; then
      break
    fi
    case "$line" in
      "$key":*)
        found="${line#*:}"
        break
        ;;
    esac
  done <"$file"

  [ -n "$found" ] || return 0
  found="${found%%#*}"
  found="${found#"${found%%[![:space:]]*}"}"
  found="${found%"${found##*[![:space:]]}"}"
  case "$found" in
    *$'\n'*) return 0 ;;
  esac
  printf '%s' "$found"
}

# 現在のブランチ名（Git が使えない場合は空）
branch=""
if command -v git >/dev/null 2>&1; then
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
fi
case "$branch" in
  *$'\n'*) branch="" ;;
esac

# 対象ループの決定: ブランチ名が優先、なければ未完了の最大番号
loop=""
case "$branch" in
  spec/[0-9][0-9][0-9]-*)
    candidate="${branch#spec/}"
    if [ -d "$SPECS_DIR/$candidate" ]; then
      loop="$candidate"
    fi
    ;;
esac

if [ -z "$loop" ]; then
  best=""
  for dir in "$SPECS_DIR"/*; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    case "$name" in
      [0-9][0-9][0-9]-*) ;;
      *) continue ;;
    esac
    candidate_status="$(fm_value "$dir/spec.md" status)"
    [ -n "$candidate_status" ] || continue
    [ "$candidate_status" = "done" ] && continue
    if [ -z "$best" ] || [[ "${name%%-*}" > "${best%%-*}" ]]; then
      best="$name"
    fi
  done
  loop="$best"
fi

[ -n "${loop:-}" ] || report_no_loop

loop_dir="$SPECS_DIR/$loop"
spec_status="$(fm_value "$loop_dir/spec.md" status)"

# ブランチが指していても仕様が読めないディレクトリは対象にしない
[ -n "${spec_status:-}" ] || report_no_loop

design_required="$(fm_value "$loop_dir/spec.md" design)"

design_status=""
has_design=0
if [ -f "$loop_dir/design.md" ]; then
  has_design=1
  design_status="$(fm_value "$loop_dir/design.md" status)"
fi

tasks_status=""
progress=""
current=""
has_tasks=0
if [ -f "$loop_dir/tasks.md" ]; then
  has_tasks=1
  tasks_status="$(fm_value "$loop_dir/tasks.md" status)"
  progress="$(fm_value "$loop_dir/tasks.md" progress)"
  current="$(fm_value "$loop_dir/tasks.md" current)"
fi

# 次に実行すべき操作（上から順に最初に一致したものを採る）
if [ "$spec_status" = "done" ]; then
  next="/aidd-status"
elif [ "$spec_status" = "draft" ]; then
  next="/aidd-approve $loop"
elif [ "$spec_status" = "approved" ] && [ "$design_required" = "required" ] && [ "$has_design" -eq 0 ]; then
  next="/aidd-design $loop"
elif [ "$design_status" = "draft" ]; then
  next="/aidd-approve $loop"
elif [ "$has_tasks" -eq 0 ]; then
  next="/aidd-tasks $loop"
elif [ "$tasks_status" = "draft" ]; then
  next="/aidd-approve $loop"
elif [ "$tasks_status" = "approved" ] || [ "$tasks_status" = "in-progress" ]; then
  next="/aidd-implement $loop"
elif [ "$tasks_status" = "done" ]; then
  next="/aidd-review $loop"
else
  next="/aidd-status"
fi

design_display="-"
[ "$has_design" -eq 1 ] && design_display="${design_status:--}"
tasks_display="-"
[ "$has_tasks" -eq 1 ] && tasks_display="${tasks_status:--}"

loop_line="[aidd] loop: $loop | spec: $spec_status | design: $design_display | tasks: $tasks_display"
[ -n "$progress" ] && loop_line="$loop_line ($progress)"
[ -n "$current" ] && loop_line="$loop_line | current: $current"

out=""
[ -n "$branch" ] && out="[aidd] branch: $branch"$'\n'
out="$out$loop_line"$'\n'"[aidd] next: $next"

printf '%s\n' "$out"
exit 0
