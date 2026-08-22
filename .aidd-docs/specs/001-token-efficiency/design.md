---
spec: ./spec.md
status: approved   # draft → approved → done
created: 2026-08-22
approved: 2026-08-22
---

# 設計書: トークン効率を既定にするハーネス整備

## §D1 設計方針サマリ

3つの構造で実現する:

1. **「常時読み込み」を「フェーズごとに1回読む」へ移す** — `rules/` は削除も分割もせず、読み込む主体を `CLAUDE.md`（毎ターン課金）から各フロー手順書（フェーズあたり1回）へ移す。効果は `/clear` によるフェーズ分割と組み合わさって初めて出るため、§D5 の停止点変更と一体で入れる
2. **新規コードは読み取り専用スクリプト1本に閉じる** — 状態を持たず、`tasks.md` を含む既存ファイルの frontmatter を機械的に読むだけ。「進捗の真実は tasks.md」原則を侵さない
3. **重複する文言は1箇所に置いて参照させる** — 「次の一手」行の書式は `flows/README.md` の表記規約に1回だけ定義し、各フローは「§記載の書式で出す」と参照する

**代替案と採らなかった理由**:

- *`rules/` を要約版と詳細版に分割する* → ファイルが2倍になり一貫性マトリクスの管理対象が増える。読み込みタイミングを変えるだけで同じ削減が得られるため不採用
- *フック用スクリプトを `.claude/hooks/` に置く* → 「本体は `.aidd-docs/`、エージェント固有ディレクトリは薄い参照のみ」の原則（設計原則6）に反する。スクリプト自体はエージェント中立なので `.aidd-docs/` に置き、`.claude/settings.json` は登録だけを持つ
- *進捗の復帰用に専用の state ファイルを作る* → 「進捗を別の場所にも持たせない」原則（設計原則5）に反する。既存 frontmatter から導出できるため不要
- *「次の一手」行を各フローに直書きする* → 5箇所に同じ書式が散り、変更時にずれる。表記規約への集約を採用

## §D2 モジュール構成・配置

### 新規ファイル

| パス | 層 | 責務 |
|---|---|---|
| `.aidd-docs/scripts/session-context.sh` | テンプレート層 | SessionStart で現在地3行を標準出力に書く。読み取り専用 |
| `.aidd-docs/scripts/session-context.test.sh` | テンプレート層 | 上記の契約（§D4）を検証するテスト。`bash .aidd-docs/scripts/session-context.test.sh` で実行 |

`.aidd-docs/scripts/` はテンプレート層の新規ディレクトリ。テンプレート更新時は丸ごと上書き対象になる。

### 変更するファイル（依存の方向）

```
.claude/settings.json  ──登録──▶  .aidd-docs/scripts/session-context.sh  ──読取──▶  .aidd-docs/specs/NNN-*/{spec,design,tasks}.md
CLAUDE.md              ──@import──▶  AGENTS.md, .aidd-docs/project/context.md
各 flows/*.md          ──読込指示──▶  .aidd-docs/rules/{workflow,implementation}.md
各 flows/*.md          ──参照──▶  .aidd-docs/flows/README.md（「次の一手」行の書式）
```

依存は常に一方向（アダプタ → 本体、フロー → ルール）で、逆流させない。

### ルール読み込みの割り当て（spec §4.4 の確定）

「必須」= 手順の冒頭で読む。「条件付き」= 記載の判断に迷ったときだけ読む。「不要」= 手順書だけで完結する。

| フロー | rules/workflow.md | rules/implementation.md |
|---|---|---|
| `/aidd-spec` | **必須**（承認ゲート・履歴参照禁止・ビジョン整合・1ループ=1ブランチ・draft をコミットしない） | 不要 |
| `/aidd-design` | **必須**（設計フェーズの責任分界・承認ゲート） | 不要 |
| `/aidd-tasks` | 条件付き（`design:` の扱い・draft のコミット可否で迷ったとき） | **必須**（フェーズ0・TDD 順序・コミット粒度をタスクに落とすため） |
| `/aidd-implement` | 条件付き（ビジョン乖離・履歴参照の可否で迷ったとき） | **必須**（進捗可視化・TDD・環境変更・並列規約） |
| `/aidd-review` | **必須**（承認後の後処理: ビジョン実現の記録・docs 再生成・1ループ=1PR） | 条件付き（コミット粒度・PR 単位で迷ったとき） |
| `/aidd-approve` | 条件付き（承認と言えるかの判断・status 遷移で迷ったとき） | 不要 |
| `/aidd-check` | 条件付き（ビジョン整合・spec ループへ誘導すべきかで迷ったとき） | 不要 |
| `/aidd-vision` | 条件付き（ビジョンと spec ループの関係で迷ったとき） | 不要 |
| `/aidd-status` `/aidd-docs` `/aidd-docs-fix` | 不要 | 不要 |

- 各フローの「事前準備」節に、知識ファイルと同じ形式でルールファイルの読み込み指示を追加する
- **同一セッション内で既に読んだルールファイルは再読しない**旨を `flows/README.md` の表記規約に1回だけ書き、各フローはそれに従う

## §D3 データ構造

### スクリプトが読む frontmatter キー（読み取り契約）

| ファイル | キー | 用途 | 欠損時 |
|---|---|---|---|
| `spec.md` | `status` | 出力の `spec:` / next 判定 | ループ対象外として扱う |
| `spec.md` | `design` | 設計フェーズ要否の判定 | `skip` とみなす |
| `design.md` | `status` | 出力の `design:` / next 判定 | ファイル無しは `-` |
| `tasks.md` | `status` | 出力の `tasks:` / next 判定 | ファイル無しは `-` |
| `tasks.md` | `progress` | 出力の進捗 | 表示を省略 |
| `tasks.md` | `current` | 出力の `current:` | 表示を省略 |

**パース規則**（`jq` 等の外部依存を使わないため、以下に限定する）:

- frontmatter = ファイル先頭行が `---` の場合の、2行目から次の `---` までの範囲
- `^<キー>:` に一致する最初の行を採用する
- 値は `:` 以降を取り、**最初の `#` 以降を削除**し、前後の空白を除去する（雛形の `status: draft   # draft → approved → done` を正しく `draft` と読むため）
- 値が空文字なら「欠損」として扱う

**書き込みは一切しない。** `progress` がチェックボックスの実数と食い違っていてもスクリプトは訂正しない（訂正は `/aidd-status` の責務のまま）。

### ループディレクトリの判定

`.aidd-docs/specs/` 直下で、名前が `NNN-*`（数字3桁 + ハイフン + 任意）に一致するディレクトリのみを対象にする。`_template` は名前規則から自動的に除外される。

## §D4 インターフェース

### `session-context.sh` の契約

| 項目 | 契約 |
|---|---|
| 起動 | `bash .aidd-docs/scripts/session-context.sh`。引数なし |
| 作業ディレクトリ | プロジェクトルート。`.aidd-docs/specs/` が無ければ無出力で終了 |
| 標準入力 | Claude Code が渡す JSON。**読まずに無視する**（`jq` 依存を避けるため） |
| 標準出力 | 0〜5行。各行は `[aidd] ` で始まる。仕様書 §4.3 の3形式のみ |
| 標準エラー | 出力しない |
| 終了コード | **常に 0** |
| 副作用 | なし（ファイル・環境を変更しない） |
| 外部依存 | `bash` と POSIX 標準コマンドのみ。`git` は**任意**（無い/リポジトリでない場合は `branch:` 行を省略し、残りは出力する） |

**出力形式**:

```
[aidd] branch: spec/001-token-efficiency
[aidd] loop: 001-token-efficiency | spec: approved | design: approved | tasks: in-progress (5/12) | current: 2.1
[aidd] next: /aidd-implement 001-token-efficiency
```

- `design:` は design.md が無ければ `-`、`tasks:` も同様
- `(5/12)` は `progress` があるときのみ、`| current: 2.1` は `current` が空でないときのみ付ける
- 対象ループが無い場合は `[aidd] 進行中のループはありません` の1行のみ（`branch:` 行も出さない）

### `.claude/settings.json` への登録

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR:-.}/.aidd-docs/scripts/session-context.sh\" 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

- `matcher` を指定しない = SessionStart の全発火条件（startup / resume / clear / compact）で動く（spec §4.3 の決定）
- `${CLAUDE_PROJECT_DIR:-.}` と `|| true` で、環境変数が無い場合・スクリプトが存在しない場合でもセッション開始を妨げない
- 既存の `permissions` キーは保持する。`settings.json` はプロジェクト層のため、テンプレート更新時は手動マージが必要（README の既存の注意書きに沿う）

## §D5 主要フロー

### F1. SessionStart フックの処理順

```
1. .aidd-docs/specs/ が無い → 無出力・exit 0
2. git rev-parse --abbrev-ref HEAD が成功 → branch を取得（失敗しても続行）
3. 対象ループの決定:
     branch が spec/NNN-slug 形式         → その NNN-slug
     そうでない                            → specs/NNN-* のうち spec.md の status が done でないもので最大番号
     どちらでも決まらない                  → 「進行中のループはありません」を出力して exit 0
4. spec.md / design.md / tasks.md の frontmatter を §D3 の規則で読む
5. next を §D5-F2 の表で決定する
6. branch 行（取得できたときのみ）→ loop 行 → next 行 の順に出力し、exit 0
   （どの段階で失敗しても最終的に exit 0。ループ名が空なら無出力）
```

### F2. `next:` 判定（上から順に最初に一致したものを採用）

| 条件 | next |
|---|---|
| spec.md が無い | （対象外。ループ決定で除外される） |
| spec.md が `done` | `/aidd-status` |
| spec.md が `draft` | `/aidd-approve <ループ名>` |
| spec が `approved` かつ `design: required` かつ design.md が無い | `/aidd-design <ループ名>` |
| design.md が `draft` | `/aidd-approve <ループ名>` |
| tasks.md が無い | `/aidd-tasks <ループ名>` |
| tasks.md が `draft` | `/aidd-approve <ループ名>` |
| tasks.md が `approved` / `in-progress` | `/aidd-implement <ループ名>` |
| tasks.md が `done` | `/aidd-review <ループ名>` |
| 上記いずれにも該当しない | `/aidd-status` |

### F3. 停止点の変更（spec §4.1・§4.2 の反映先）

| 箇所 | 変更 |
|---|---|
| `flows/approve.md` の承認後動作テーブル | tasks 承認の行を「自動継続しない。`/clear` → `/aidd-implement` を案内して停止」に変更。`go` 引数の節を追加（`stop` と同時指定なら `stop` 優先） |
| `flows/implement.md` 手順3 | 「`/aidd-review` の手順に進む」→「`/clear` → `/aidd-review` を案内して停止」 |
| `flows/README.md` 表記規約 | 「次の一手」行の書式（軽い境界=1行 / 重い境界=2行）とルール再読の禁止を追加 |
| `flows/spec.md` `design.md` `tasks.md` `review.md` `implement.md` | レビュー依頼・完了報告の最終行に「次の一手」行を出す指示を追加（書式は README を参照） |

### F4. 決定事項の書き戻し（spec §4.6）

各フローの停止前に、チャット上で確定した内容を既存の欄へ書き戻す:

| フロー | 書き戻し先 |
|---|---|
| `/aidd-spec` | spec.md の「§8 未決事項」「変更履歴」 |
| `/aidd-design` | design.md の「未決事項」「変更履歴」 |
| `/aidd-tasks` | tasks.md のタスク本文（ケース列挙・検証方法） |
| `/aidd-implement` | tasks.md のチェックボックス・`current:`・`progress:`（既存規定のまま） |
| `/aidd-review` | spec.md の「変更履歴」（仕様変更を伴う修正のみ） |

新しい欄・新しいファイルは作らない。

## §D6 エラー処理・横断的関心事

### スクリプトの堅牢性

- `set -e` は**使わない**（途中の非ゼロ終了で出力が欠けるのを防ぐ）。代わりに各外部コマンドを `|| true` / 条件分岐でガードする
- `set -u` は使わず、未定義変数は空文字として扱う（`${var:-}` 形式で参照する）
- ファイル読み取りは存在チェックしてから行う
- 出力は組み立て終えてから一括で書く（途中失敗による半端な行を出さない）
- **ループ名・パスを出力に埋め込む際、改行を含む値は空として扱う**（複数行出力による契約違反を防ぐ）

### テスト方針

`session-context.test.sh` は一時ディレクトリに `.aidd-docs/specs/NNN-*` の fixture を作り、`cd` してスクリプトを実行し、標準出力を期待値と比較する。最低限カバーする分岐:

- specs ディレクトリ無し → 無出力・exit 0
- ループ無し → 「進行中のループはありません」1行
- ブランチ名からのループ特定 / frontmatter からのフォールバック特定
- `next:` 判定表（F2）の各行
- frontmatter のコメント付き値（`status: draft   # ...`）を正しく読む
- `design: required` で design.md が無い場合
- 壊れた frontmatter（`---` が無い・キーが無い）→ 無出力または安全な既定で exit 0
- `progress` / `current` が空のときの出力省略

Git が無い環境の分岐は、`PATH` を制御したケースで確認する（不可能なら「branch 行が無い場合も loop/next 行が出る」ことをブランチ非 `spec/` ケースで代替検証する）。

### ドキュメント変更の検証方法

コード以外の変更（§4.1・§4.2・§4.4〜§4.8）はテストではなく `grep` ベースの整合チェックで検証する:

- `CLAUDE.md` の `@import` が2本であること、`wc -l CLAUDE.md AGENTS.md .aidd-docs/project/context.md` の合計が120行以下であること
- 停止点を持つ全フローに「次の一手」行の指示があること
- `grep -rn "rules/workflow.md\|rules/implementation.md" .aidd-docs/flows/` が §D2 の割り当て表と一致すること
- 旧表記（`@.aidd-docs/rules/`、implement 完了時の自動継続文言）が残っていないこと

### 秘密情報・セキュリティ

スクリプトはリポジトリ内の frontmatter だけを読み、ネットワークアクセス・コマンド実行（`git rev-parse` を除く）を行わない。出力にファイル本文を含めないため、秘密情報が新たにコンテキストへ載ることはない。ユーザー入力を解釈しないためインジェクションの経路もない。

## 未決事項

| 事項 | 仮決めした内容 | 理由 |
|---|---|---|
| スクリプトの配置 | `.aidd-docs/scripts/`（新規ディレクトリ） | 「本体は `.aidd-docs/`」原則に従う。`.claude/hooks/` はアダプタに本体を置くことになるため不可 |
| テストの同梱 | `session-context.test.sh` をテンプレートに同梱する | スクリプトは実コードなので TDD 対象。契約のドキュメントも兼ねる。テンプレート利用者がフックの動作確認にも使える |
| `/aidd-tasks` が workflow.md を読むか | 条件付き（必須にしない） | タスク分解で必要なのは実装ルール。承認まわりは手順書に完結しているため、必須にすると削減効果が薄れる |
| `/aidd-approve` が workflow.md を読むか | 条件付き（必須にしない） | 承認後動作テーブルは approve.md に完結。ただし「曖昧な返事は承認ではない」の判断が要るときだけ読む |
| フック登録のコマンド文字列 | `${CLAUDE_PROJECT_DIR:-.}` + `2>/dev/null \|\| true` | 環境変数が無い場合・他プロジェクトでの誤発火時にセッション開始を妨げないため。実装時に実環境で1回動作確認する |
| `git` 非依存の扱い | `git` が使えないときは `branch:` 行のみ省略 | ループ特定は frontmatter からのフォールバックで成立するため、機能全体を落とす必要がない |

## 変更履歴

| 日付 | 変更内容 |
|---|---|
| 2026-08-22 | 初版作成 |
