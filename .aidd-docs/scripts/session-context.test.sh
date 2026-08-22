#!/usr/bin/env bash
# session-context.sh の契約テスト。
# 実行: bash .aidd-docs/scripts/session-context.test.sh
# 失敗件数を報告し、1件でも失敗したら終了コード 1 を返す。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/session-context.sh"

PASS=0
FAIL=0
TMP_ROOTS=()

cleanup() {
  local d
  for d in "${TMP_ROOTS[@]}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ---- fixture ヘルパー ----

# 空のプロジェクトルート（.aidd-docs すら無い）
new_bare_root() {
  local d
  d="$(mktemp -d)"
  TMP_ROOTS+=("$d")
  printf '%s' "$d"
}

# .aidd-docs/specs/ まで作ったプロジェクトルート
new_root() {
  local d
  d="$(new_bare_root)"
  mkdir -p "$d/.aidd-docs/specs"
  printf '%s' "$d"
}

# spec_file <root> <ループ名> <status> [design値]
# design値を省略すると design: 行自体を書かない（欠損時の扱いを検証するため）
spec_file() {
  local dir="$1/.aidd-docs/specs/$2"
  mkdir -p "$dir"
  {
    echo '---'
    echo "status: $3   # draft → approved → done"
    echo 'created: 2026-08-22'
    if [ "$#" -ge 4 ]; then
      echo "design: $4    # skip / required"
    fi
    echo '---'
    echo ''
    echo '# 仕様書: テスト用'
  } >"$dir/spec.md"
}

# design_file <root> <ループ名> <status>
design_file() {
  local dir="$1/.aidd-docs/specs/$2"
  mkdir -p "$dir"
  {
    echo '---'
    echo 'spec: ./spec.md'
    echo "status: $3   # draft → approved → done"
    echo '---'
    echo ''
    echo '# 設計書: テスト用'
  } >"$dir/design.md"
}

# tasks_file <root> <ループ名> <status> <progress> <current>
# progress / current は空文字を渡すと値なしの行を書く
tasks_file() {
  local dir="$1/.aidd-docs/specs/$2"
  mkdir -p "$dir"
  {
    echo '---'
    echo 'spec: ./spec.md'
    echo "status: $3   # draft → approved → in-progress → done"
    echo "progress: $4  # 完了数/総数"
    echo "current: $5"
    echo '---'
    echo ''
    echo '# タスクリスト: テスト用'
  } >"$dir/tasks.md"
}

# git_repo <root> <ブランチ名>
git_repo() {
  git -C "$1" init -q -b main >/dev/null 2>&1
  git -C "$1" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m init >/dev/null 2>&1
  if [ "$2" != "main" ]; then
    git -C "$1" checkout -q -b "$2" >/dev/null 2>&1
  fi
}

# ---- アサーション ----

# check <テスト名> <期待する標準出力> <root> [標準入力に流す文字列]
check() {
  local name="$1" expected="$2" root="$3" stdin_data="${4-}"
  local actual code
  actual="$(cd "$root" && printf '%s' "$stdin_data" | bash "$SCRIPT" 2>/dev/null)"
  code=$?
  if [ "$actual" = "$expected" ] && [ "$code" -eq 0 ]; then
    PASS=$((PASS + 1))
    return 0
  fi
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$name"
  printf '  期待した終了コード: 0 / 実際: %s\n' "$code"
  printf '  期待した出力:\n'
  printf '%s\n' "$expected" | sed 's/^/    | /'
  printf '  実際の出力:\n'
  printf '%s\n' "$actual" | sed 's/^/    | /'
}

# ---- テストケース ----

# .aidd-docs/specs/ が存在しない
t_no_specs_dir() {
  local root
  root="$(new_bare_root)"
  check 'specs ディレクトリが無い場合_無出力で終了する' '' "$root"
}

# specs はあるがループディレクトリが無い
t_no_loops() {
  local root
  root="$(new_root)"
  check 'ループディレクトリが無い場合_進行中なしを1行で報告する' \
    '[aidd] 進行中のループはありません' "$root"
}

# _template は NNN-* の命名規則に一致しないので除外される
t_only_template() {
  local root
  root="$(new_root)"
  spec_file "$root" '_template' 'draft' 'skip'
  check '_template だけがある場合_進行中なしを報告する' \
    '[aidd] 進行中のループはありません' "$root"
}

# 完了済みループしかなく、ブランチも指していない
t_all_done() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'done' 'skip'
  check '完了済みループしかない場合_進行中なしを報告する' \
    '[aidd] 進行中のループはありません' "$root"
}

# ブランチ名が番号の小さいループを指す場合、番号の大きいループより優先される
t_branch_selects_loop() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'draft' 'skip'
  spec_file "$root" '002-bar' 'draft' 'skip'
  git_repo "$root" 'spec/001-foo'
  check 'ブランチ名がループを指す場合_番号が小さくてもそのループを対象にする' \
    '[aidd] branch: spec/001-foo
[aidd] loop: 001-foo | spec: draft | design: - | tasks: -
[aidd] next: /aidd-approve 001-foo' "$root"
}

# ブランチが spec/NNN-slug 形式でないときは frontmatter からフォールバックする
t_fallback_selects_highest_unfinished() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'done' 'skip'
  spec_file "$root" '002-bar' 'draft' 'skip'
  git_repo "$root" 'main'
  check 'ブランチが spec 形式でない場合_未完了の最大番号を対象にする' \
    '[aidd] branch: main
[aidd] loop: 002-bar | spec: draft | design: - | tasks: -
[aidd] next: /aidd-approve 002-bar' "$root"
}

# Git リポジトリでない場合は branch 行だけを落とす
t_no_git() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'draft' 'skip'
  check 'Git リポジトリでない場合_branch 行を省略して残りを出力する' \
    '[aidd] loop: 001-foo | spec: draft | design: - | tasks: -
[aidd] next: /aidd-approve 001-foo' "$root"
}

# design: required で design.md が未作成
t_next_design() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'required'
  check 'design required で design.md が無い場合_設計フェーズを次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: -
[aidd] next: /aidd-design 001-foo' "$root"
}

# design.md が draft
t_next_approve_design() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'required'
  design_file "$root" '001-foo' 'draft'
  check 'design.md が draft の場合_承認を次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: draft | tasks: -
[aidd] next: /aidd-approve 001-foo' "$root"
}

# design: 行が欠損している場合は skip とみなし、tasks.md が無ければタスク分解へ
t_next_tasks_when_design_key_missing() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved'
  check 'design 行が欠損し tasks.md が無い場合_skip とみなしタスク分解を次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: -
[aidd] next: /aidd-tasks 001-foo' "$root"
}

# tasks.md が draft
t_next_approve_tasks() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'skip'
  tasks_file "$root" '001-foo' 'draft' '0/17' ''
  check 'tasks が draft の場合_承認を次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: draft (0/17)
[aidd] next: /aidd-approve 001-foo' "$root"
}

# tasks.md が approved
t_next_implement_approved() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'skip'
  tasks_file "$root" '001-foo' 'approved' '0/17' ''
  check 'tasks が approved の場合_実装を次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: approved (0/17)
[aidd] next: /aidd-implement 001-foo' "$root"
}

# tasks.md が in-progress（progress と current の両方が出る形）
t_next_implement_in_progress() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'required'
  design_file "$root" '001-foo' 'approved'
  tasks_file "$root" '001-foo' 'in-progress' '5/12' '2.1'
  git_repo "$root" 'spec/001-foo'
  check 'tasks が in-progress の場合_進捗と現在タスクを添えて実装を次に示す' \
    '[aidd] branch: spec/001-foo
[aidd] loop: 001-foo | spec: approved | design: approved | tasks: in-progress (5/12) | current: 2.1
[aidd] next: /aidd-implement 001-foo' "$root"
}

# tasks.md が done
t_next_review() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'skip'
  tasks_file "$root" '001-foo' 'done' '17/17' ''
  check 'tasks が done の場合_レビューを次に示す' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: done (17/17)
[aidd] next: /aidd-review 001-foo' "$root"
}

# 完了済みループをブランチが指している場合
t_next_status_when_done() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'done' 'skip'
  tasks_file "$root" '001-foo' 'done' '17/17' ''
  git_repo "$root" 'spec/001-foo'
  check 'ブランチが完了済みループを指す場合_status を次に示す' \
    '[aidd] branch: spec/001-foo
[aidd] loop: 001-foo | spec: done | design: - | tasks: done (17/17)
[aidd] next: /aidd-status' "$root"
}

# 値の前後に余分な空白があり、末尾にコメントが付く
t_frontmatter_comment_and_spaces() {
  local dir root
  root="$(new_root)"
  dir="$root/.aidd-docs/specs/001-foo"
  mkdir -p "$dir"
  {
    echo '---'
    echo 'status:    approved      # draft → approved → done'
    echo 'design:   skip     # skip / required'
    echo '---'
  } >"$dir/spec.md"
  check 'frontmatter の値に余分な空白とコメントが付く場合_値だけを読む' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: -
[aidd] next: /aidd-tasks 001-foo' "$root"
}

# progress / current が空
t_empty_progress_and_current() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'skip'
  tasks_file "$root" '001-foo' 'approved' '' ''
  check 'progress と current が空の場合_該当部分を出力しない' \
    '[aidd] loop: 001-foo | spec: approved | design: - | tasks: approved
[aidd] next: /aidd-implement 001-foo' "$root"
}

# frontmatter が壊れている（先頭が --- でない）
t_broken_frontmatter() {
  local dir root
  root="$(new_root)"
  dir="$root/.aidd-docs/specs/001-foo"
  mkdir -p "$dir"
  {
    echo '# 仕様書: 壊れた frontmatter'
    echo 'status: approved'
  } >"$dir/spec.md"
  check 'frontmatter が壊れている場合_対象外として扱う' \
    '[aidd] 進行中のループはありません' "$root"
}

# spec.md 自体が無いディレクトリ
t_loop_without_spec() {
  local root
  root="$(new_root)"
  mkdir -p "$root/.aidd-docs/specs/001-foo"
  check 'spec.md が無いループディレクトリ_対象外として扱う' \
    '[aidd] 進行中のループはありません' "$root"
}

# 標準入力の JSON は無視される
t_stdin_ignored() {
  local root
  root="$(new_root)"
  spec_file "$root" '001-foo' 'draft' 'skip'
  check '標準入力に JSON を渡しても_無視して同じ出力になる' \
    '[aidd] loop: 001-foo | spec: draft | design: - | tasks: -
[aidd] next: /aidd-approve 001-foo' "$root" \
    '{"session_id":"abc","source":"clear","cwd":"/tmp"}'
}

# 出力の形式的な制約（接頭辞・行数）
t_output_contract() {
  local root actual code lines bad line
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'required'
  design_file "$root" '001-foo' 'approved'
  tasks_file "$root" '001-foo' 'in-progress' '5/12' '2.1'
  git_repo "$root" 'spec/001-foo'

  actual="$(cd "$root" && bash "$SCRIPT" </dev/null 2>/dev/null)"
  code=$?
  lines="$(printf '%s\n' "$actual" | wc -l | tr -d ' ')"
  bad=0
  while IFS= read -r line; do
    case "$line" in
      '[aidd] '*) ;;
      *) bad=1 ;;
    esac
  done <<<"$actual"

  if [ "$code" -eq 0 ] && [ "$lines" -le 5 ] && [ "$bad" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: 出力は全行が [aidd] 接頭辞付きで5行以内である\n'
    printf '  終了コード: %s / 行数: %s / 接頭辞違反: %s\n' "$code" "$lines" "$bad"
    printf '%s\n' "$actual" | sed 's/^/    | /'
  fi
}

# スクリプトはファイルを書き換えない
t_no_side_effects() {
  local root before after
  root="$(new_root)"
  spec_file "$root" '001-foo' 'approved' 'skip'
  tasks_file "$root" '001-foo' 'in-progress' '5/12' '2.1'
  before="$(find "$root" -type f -exec cksum {} \; | sort)"
  (cd "$root" && bash "$SCRIPT" </dev/null >/dev/null 2>&1)
  after="$(find "$root" -type f -exec cksum {} \; | sort)"
  if [ "$before" = "$after" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: スクリプトはファイルを書き換えない\n'
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/    | /'
  fi
}

# ---- 実行 ----

t_no_specs_dir
t_no_loops
t_only_template
t_all_done
t_branch_selects_loop
t_fallback_selects_highest_unfinished
t_no_git
t_next_design
t_next_approve_design
t_next_tasks_when_design_key_missing
t_next_approve_tasks
t_next_implement_approved
t_next_implement_in_progress
t_next_review
t_next_status_when_done
t_frontmatter_comment_and_spaces
t_empty_progress_and_current
t_broken_frontmatter
t_loop_without_spec
t_stdin_ignored
t_output_contract
t_no_side_effects

printf '\n成功: %s / 失敗: %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
