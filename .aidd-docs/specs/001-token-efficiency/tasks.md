---
spec: ./spec.md
status: done   # draft → approved → in-progress → done
approved: 2026-08-22
progress: 17/17  # 完了数/総数
current:
---

# タスクリスト: トークン効率を既定にするハーネス整備

## フェーズ0: 環境セットアップ【人間承認枠】 (spec §7)

**なし**（spec §7 のとおり環境変更・依存追加は発生しない。`bash` と POSIX 標準コマンドのみを使う）

## フェーズ1: SessionStart フックスクリプト (spec §4.3, design §D2〜§D6)

- [x] 1.1 [RED] `session-context.sh` のテスト作成 (spec §4.3, design §D4, §D6)
  - 作成: `.aidd-docs/scripts/session-context.test.sh`（一時ディレクトリに fixture を作り、`cd` して実行し標準出力を期待値と比較する）
  - ケース（design §D6 のカバー範囲）:
    - `.aidd-docs/specs/` が無い → 無出力・exit 0
    - specs はあるが `NNN-*` ディレクトリが無い → `[aidd] 進行中のループはありません` の1行のみ（`branch:` 行を出さない）
    - `_template` だけがある → 上と同じ（名前規則で除外される）
    - ブランチ名 `spec/001-foo` からループを特定する
    - ブランチが `main` → frontmatter フォールバックで「`status` が `done` でない最大番号」を選ぶ
    - `done` のループしかない → 「進行中のループはありません」
    - `next:` 判定表（design §D5-F2）の各行: spec `done` / spec `draft` / spec approved かつ `design: required` かつ design.md 無し / design `draft` / tasks.md 無し / tasks `draft` / tasks `approved` / tasks `in-progress` / tasks `done`
    - frontmatter のコメント付き値 `status: draft   # draft → approved → done` を `draft` と読む
    - `progress` が空 → `(x/y)` を出さない。`current` が空 → `| current:` を出さない
    - 壊れた frontmatter（先頭が `---` でない / キーが無い） → 無出力または安全な既定で exit 0
    - 出力行がすべて `[aidd] ` で始まり、5行を超えない
    - 終了コードが常に 0
  - 検証: `bash .aidd-docs/scripts/session-context.test.sh` を実行し、スクリプト未実装のため**期待どおり失敗する**ことを確認する（テストランナー自体はエラー終了せず、失敗件数を報告すること）
- [x] 1.2 [GREEN] `session-context.sh` の実装 (spec §4.3, design §D3, §D4, §D5-F1, §D5-F2)
  - 作成: `.aidd-docs/scripts/session-context.sh`
  - design §D3 のパース規則（`#` 以降の除去・前後空白の除去）、§D5-F1 の処理順、§D5-F2 の判定表を実装する
  - 標準入力を読まない / 書き込みをしない / 常に exit 0 / `git` は任意依存（無ければ `branch:` 行のみ省略）
  - 検証: 1.1 のテストが全件通る
- [x] 1.3 [REFACTOR] スクリプトの堅牢化と整理 (design §D6)
  - `set -e` を使わない・未定義変数を `${var:-}` で参照する・改行を含む値を空として扱う・出力を一括で書く、を満たす形に整える
  - 検証: 1.1 のテストが全件通ったまま
- [x] 1.4 `.claude/settings.json` へのフック登録と実環境での動作確認 (spec §4.3, design §D4)
  - 既存の `permissions` を保持したまま `hooks.SessionStart` を追加する（`matcher` なし＝全発火条件）
  - 検証: 登録するコマンド文字列そのものをシェルで実行し（`CLAUDE_PROJECT_DIR` を設定した場合／設定しない場合の両方）、期待どおりの `[aidd]` 行が出て終了コードが 0 になることを確認する。JSON として妥当であることも確認する

## フェーズ2: 停止点とフェーズ境界の運用 (spec §4.1, §4.2, design §D5-F3, §D5-F4)

- [x] 2.1 `flows/README.md` の表記規約を追加 (spec §4.2, design §D1, §D2)
  - 「次の一手」行の書式（軽い境界=1行 / 重い境界=2行、ループ名は具体名を埋める）を1箇所に定義する
  - 「同一セッション内で既に読んだルールファイルを再読しない」を追加する
  - 検証: 書式定義が1箇所だけであること（`grep -rn "次:" .aidd-docs/flows/` で他フローに書式の複製が無い）
- [x] 2.2 `flows/approve.md` の承認後動作を変更 (spec §4.1, design §D5-F3)
  - tasks 承認の行を「自動継続しない。`/clear` → `/aidd-implement` を案内して停止」に変更する
  - `go` 引数の節を追加し、`stop` と同時指定なら `stop` を優先すると明記する
  - 検証: テーブルの4行が spec §4.1 の表と一致する。`go` と `stop` の優先順位が明記されている
- [x] 2.3 `flows/implement.md` の完了時動作を変更 (spec §4.1, design §D5-F3)
  - 手順3の「`/aidd-review` の手順に進む」を「`/clear` → `/aidd-review` を案内して停止」に変更する
  - 検証: 旧文言が残っていない（`grep -n "aidd-review" .aidd-docs/flows/implement.md`）
- [x] 2.4 停止点への「次の一手」行と決定事項の書き戻しを追加 (spec §4.2, §4.6, design §D5-F3, §D5-F4)
  - 対象: `flows/spec.md` `design.md` `tasks.md` `implement.md` `review.md`
  - 各レビュー依頼・完了報告の最終行に「次の一手」行を出す指示（書式は `flows/README.md` を参照）を追加する
  - 停止前にチャット上の決定事項を design §D5-F4 の書き戻し先へ反映する指示を追加する（新しい欄・ファイルは作らない）
  - 検証: 対象5ファイルすべてに両方の指示があること
- [x] 2.5 `rules/workflow.md` にフェーズ境界の運用を反映 (spec §4.1, §4.2)
  - 「承認の扱い」に自動継続の範囲（軽い境界のみ）と重い境界での停止を追記する
  - 全体フロー図に `/clear` を挟む位置を反映する
  - 検証: `flows/approve.md` のテーブルと矛盾しないこと

## フェーズ3: 常駐コンテキストの削減 (spec §4.4, §4.6, design §D2)

- [x] 3.1 `CLAUDE.md` の `@import` 削減と Compact instructions 節の追加 (spec §4.4, §4.6)
  - `@import` を `@AGENTS.md` と `@.aidd-docs/project/context.md` の2本にする
  - 「Compact instructions」節を追加し、残すもの（ループ名・ブランチ・各 status・未完了タスクと `current:`・人間の決定と未決事項・直近の検証結果）と捨ててよいもの（ファイル全文・探索過程・書き戻し済みの内容）を書く
  - 検証: `grep -n "^@" CLAUDE.md` が2行であること。Compact instructions 節が存在すること
- [x] 3.2 `AGENTS.md` のルール読み込みタイミングを変更 (spec §4.4)
  - 「詳細ルールも読み込むこと」を「各フロー手順書が指定するタイミングで読む。コマンド外の作業で該当する判断が必要になったときも同じファイルを読む」の趣旨に改める
  - 絶対ルールの要約11箇条は常駐のまま維持する（削らない）
  - 検証: 11箇条が残っていること。常時読み込みを指示する文言が残っていないこと
- [x] 3.3 各フローの「事前準備」にルール読み込み指示を追加 (spec §4.4, design §D2 割り当て表)
  - design §D2 の表どおりに「必須」「条件付き」「不要」を書き分ける（不要のフローには何も足さない）
  - 検証: `grep -rn "rules/workflow.md\|rules/implementation.md" .aidd-docs/flows/` の結果が design §D2 の割り当て表と1対1で一致する
- [x] 3.4 常駐削減の検証 (spec §4.4)
  - 検証: `wc -l CLAUDE.md AGENTS.md .aidd-docs/project/context.md` の合計が **120行以下**であること。`grep -rn "@.aidd-docs/rules/" .` の結果が0件であること
  - **結果**: 324行（22+56+121+86+46 の旧構成）→ **124行**（削減率62%）。旧 `@import` の残骸は0件。**目標120行に対し4行超過**。原因は spec 執筆時に `project/context.md` の雛形を薄いと見積もったが実際は46行（うち30行が人間向けの運用ガイドコメント）だったこと。**人間の判断で4行の超過を許容**（2026-08-22）。雛形の圧縮は行わない

## フェーズ4: 大量出力のサブエージェント委任基準 (spec §4.5)

- [x] 4.1 委任基準の明文化 (spec §4.5)
  - `rules/implementation.md` の並列規約7（読み取り専用の並列化）に、節約目的の委任対象（テスト全体の実行・横断調査・大規模差分/ログの確認）と目安（想定出力が数百行超、または複数ファイルの全文読みが必要）を追記する
  - `knowledge/subagent-orchestration.md` に同じ判断基準を追記する
  - `AGENTS.md` ルール11の「(a) 委任が明らかに割に合うと判断したとき」の具体例としてこれを参照させる
  - 検証: 3ファイルの記述が矛盾しないこと。書き込みを伴う実装の委任基準（独立な機能単位が2つ以上）が**変更されていない**こと

## フェーズ5: ドキュメントと一貫性の担保 (spec §4.7, §4.8)

- [x] 5.1 `README.md` の更新 (spec §4.7)
  - 「トークン運用」の節を追加する（フェーズ境界での `/clear`、SessionStart フックによる復帰、`/context` `/usage`、Opus/Sonnet の使い分け、具体的なプロンプト、大きい調査の委任）
  - ディレクトリ構成図に `.aidd-docs/scripts/` を追加する
  - 「承認の仕組み」の自動継続の説明を新しい挙動（重い境界では停止、`go` 引数）に合わせる
  - 検証: 構成図・承認の仕組み・コマンド一覧が `flows/approve.md` と `.aidd-docs/` の実体に一致すること
- [x] 5.2 `knowledge/template-maintenance.md` の一貫性マトリクスと設計原則を更新 (spec §4.8)
  - マトリクスに3行追加: フェーズ境界の運用 / SessionStart フック・スクリプト / 常駐コンテキストの構成
  - 設計原則に「節約のために承認ゲート・TDD 順序・進捗可視化を犠牲にしない」を追加する
  - 検証: 追加した3行の「更新が必要なファイル」が、このループで実際に触ったファイル集合と一致すること

## 最終フェーズ: 仕上げ

- [x] 9.1 全体の整合チェック (design §D6)
  - 検証:
    - `bash .aidd-docs/scripts/session-context.test.sh` が全件通る
    - `grep -rn "@.aidd-docs/rules/" .` が0件（旧 `@import` の残骸なし）
    - `grep -rn "rules/workflow.md\|rules/implementation.md" .aidd-docs/flows/` が design §D2 の表と一致
    - `wc -l CLAUDE.md AGENTS.md .aidd-docs/project/context.md` の合計が120行以下
    - 停止点を持つ5フローすべてに「次の一手」行の指示がある
    - `.claude/settings.json` が妥当な JSON である
