---
status: approved   # draft → approved → done
created: 2026-08-22
approved: 2026-08-22
design: required  # skip / required — 設計フェーズ（design.md）の要否。/aidd-spec が判定基準から提案し、人間が仕様承認までに確定する
---

# 仕様書: トークン効率を既定にするハーネス整備

## 1. 概要

テンプレートのワークフローに「フェーズ境界で `/clear` する運用」を組み込み、clear しても安全に再開できる仕組み（SessionStart フックによる現在地の自動注入）と、常駐コンテキストの削減をあわせて行う。利用者が特別に意識しなくても、公式ドキュメント「コストを効果的に管理する」が推奨するトークン節約が自然に実行される状態にする。

## 2. 背景・目的

現在このテンプレートは、承認のたびに `/aidd-approve` が次フェーズを自動継続するため、`/aidd-spec` → `/aidd-design` → `/aidd-tasks` → `/aidd-implement` が1つのコンテキストに積み上がりやすい。仕様作成時の調査ログ・読み込んだ知識ファイル全文が実装フェーズまで居座り、後続の全メッセージでトークンを消費する。

`/clear` すればよいが、clear すると「今どのループの何段階目にいるか」が失われるため、利用者は clear をためらう。さらに `CLAUDE.md` の `@import` により毎セッション約290行（AGENTS.md 56 + rules/workflow.md 121 + rules/implementation.md 86 + CLAUDE.md 本文 15）が常駐しており、公式が目安とする「200行以下」を超えている。

目的は、**節約を利用者の心がけに委ねず、ワークフローの既定の振る舞いとして実装すること**。

### ビジョンとの整合

`.aidd-docs/vision.md` は未記入（テンプレートの雛形のまま）のため、整合チェックはスキップする。

## 3. スコープ

### やること

- 重いフェーズ境界での自動継続を止め、`/clear` を案内して停止する（§4.1）
- 全フローの停止点に統一形式の「次の一手」行を出す（§4.2）
- SessionStart フックで、新しいセッションの冒頭に現在地を数行だけ自動注入する（§4.3）
- `CLAUDE.md` の `@import` から `rules/` 2本を外し、各フローが必要なルールを必要なときに読む方式にする（§4.4）
- 大量出力を伴う作業をサブエージェントに委任する基準を、節約目的として明文化する（§4.5）
- `CLAUDE.md` に Compact instructions 節を追加する（§4.6）
- README に「トークン運用」の節を追加する（§4.7）
- 上記に伴う一貫性マトリクスの更新（§4.8）

### やらないこと（スコープ外）

- **コマンド別のモデル既定の追加**（`/aidd-status` 等への `model:` 指定）。今回の検討で選外とした。`/aidd-implement` の `model: sonnet` は現状維持
- **MCP サーバー・コードインテリジェンスプラグインの設定**。テンプレートは MCP を前提にしていないため対象外
- **トークン消費量の計測・記録基盤**。効果測定は利用者が `/context` `/usage` で行う（README で案内するにとどめる）
- **`rules/` ファイルそのものの分割・再編**。常駐から外すだけで、ファイル構成は変えない
- **`MAX_THINKING_TOKENS` 等の環境変数・`/effort` の既定設定**。人間の裁量に委ねる（README の案内のみ）
- **既存の承認ゲート・TDD 順序・「進捗の真実は tasks.md」原則の変更**。これらは節約より優先する

## 4. 仕様詳細

### §4.1 重いフェーズ境界での自動継続の停止

`/aidd-approve` の承認後の既定動作を、境界の「重さ」で出し分ける。

| 承認する対象 | 承認後の既定動作 | 変更 |
|---|---|---|
| spec.md（draft → approved） | `design: required` なら `/aidd-design`、`skip` なら `/aidd-tasks` を自動継続 | 現状維持 |
| design.md（draft → approved） | `/aidd-tasks` を自動継続 | 現状維持 |
| **tasks.md（draft → approved）** | **自動継続しない。§4.2 の形式で `/clear` → `/aidd-implement` を案内して停止する** | **変更** |
| 実装レビュー（tasks が done） | `/aidd-review` の「承認後の後処理」を実行 | 現状維持 |

また `/aidd-implement` の全タスク完了時、現在は続けて `/aidd-review` の手順に進んでいるが、**自動継続しない**。§4.2 の形式で `/clear` → `/aidd-review` を案内して停止する。

- 停止する2箇所（tasks 承認後・実装完了後）を「重い境界」と呼ぶ。理由は、直前フェーズの成果物がすべてファイルに書き出され済みで、会話履歴を引き継ぐ利得がほとんど無い一方、次のフェーズが最もトークンを消費するため
- 既存の `stop` 引数（自動継続させない）は現状維持。軽い境界で継続してほしくないときに使う
- 重い境界でもそのまま継続したい場合のため、`/aidd-approve <ループ名> go` を追加する。`go` が指定されたときのみ、tasks 承認後にそのまま `/aidd-implement` の手順へ進む
- `stop` と `go` が同時に指定された場合は `stop` を優先する
- **承認ゲートは変更しない**。停止が増える方向の変更であり、人間の承認なしに status が進むことはない

### §4.2 停止点の「次の一手」行

人間が停止点で次に何をすればよいか迷わないよう、`/aidd-spec` `/aidd-design` `/aidd-tasks` `/aidd-implement`（完了時）`/aidd-review` の停止時に、レビュー依頼の**最終行**として次の形式の1〜2行を必ず出す。

軽い境界（`/aidd-spec` `/aidd-design` の停止点、および修正指示待ちの状態）:

```
次: `/aidd-approve 001-token-efficiency`（承認するとタスク分解まで自動で進みます）
```

重い境界（`/aidd-tasks` 承認後、`/aidd-implement` 完了後）:

```
次: `/clear` してから `/aidd-implement 001-token-efficiency`
（実装フェーズは新しいコンテキストで始めるとトークン消費を抑えられます。進行状況は tasks.md に残るので clear しても失われません）
```

- 括弧内の補足は重い境界でのみ出す（軽い境界では1行のみ）
- ループ名は必ず具体名を埋める（`<ループ名>` のようなプレースホルダのまま出さない）
- この行は既存のレビュー依頼項目（要点サマリ・判断ポイント等）を置き換えるものではなく、その末尾に追加する

### §4.3 SessionStart フックによる現在地の自動注入

`/clear` 後の新しいコンテキストでも Claude が現在地を把握できるよう、テンプレートがフックスクリプトと設定を提供する。

**発火条件**: SessionStart（新規起動 / resume / clear / compact のすべて）。

**出力**: 標準出力に最大5行。進行中のループがある場合の形式:

```
[aidd] branch: spec/001-token-efficiency
[aidd] loop: 001-token-efficiency | spec: approved | design: approved | tasks: in-progress (5/12) | current: 2.1
[aidd] next: /aidd-implement 001-token-efficiency
```

**対象ループの決定順**:

1. 現在のブランチ名が `spec/NNN-slug` 形式なら、その `NNN-slug` を対象にする
2. そうでなければ、`.aidd-docs/specs/NNN-*` のうち spec.md の `status` が `done` でないものの中で最も番号が大きいものを対象にする
3. 該当が無ければ `[aidd] 進行中のループはありません` の1行のみ出力する

**`next:` の決定**（対象ループの frontmatter から機械的に導く）:

| 状態 | next |
|---|---|
| spec.md が `draft` | `/aidd-approve <ループ名>`（仕様レビュー待ち） |
| spec が `approved` かつ `design: required` で design.md が無い | `/aidd-design <ループ名>` |
| design.md が `draft` | `/aidd-approve <ループ名>`（設計レビュー待ち） |
| 設計まで揃い tasks.md が無い | `/aidd-tasks <ループ名>` |
| tasks.md が `draft` | `/aidd-approve <ループ名>`（タスクレビュー待ち） |
| tasks.md が `approved` または `in-progress` | `/aidd-implement <ループ名>` |
| tasks.md が `done` かつ spec が `done` でない | `/aidd-review <ループ名>` |
| spec.md が `done` | `/aidd-status`（このループは完了） |

**異常系・制約**:

- 判定に必要なファイルが読めない・形式が想定外・Git リポジトリでない場合は、**何も出力せずに終了コード0で終わる**（フックの失敗でセッション開始を妨げない）
- 追加のインストールを必要としない（`bash` と POSIX 標準コマンドのみ。`jq` 等の外部依存を使わない）
- スクリプトは読み取り専用。ファイルを書き換えない（進捗の真実は tasks.md のままであり、新しい状態ファイルを作らない）
- `.aidd-docs/specs/` を走査するが、**内容の解釈は frontmatter の機械的な読み取りのみ**。履歴 spec の本文を Claude のコンテキストに載せない（「現行ループ以外の spec を参照しない」ルールと矛盾しない）
- 出力は5行を超えない。ループ本文・仕様の要約を出力しない

### §4.4 常駐コンテキストの削減

**`CLAUDE.md` の `@import` を変更する**:

| 変更前 | 変更後 |
|---|---|
| `@AGENTS.md` / `@.aidd-docs/project/context.md` / `@.aidd-docs/rules/workflow.md` / `@.aidd-docs/rules/implementation.md` | `@AGENTS.md` / `@.aidd-docs/project/context.md` のみ |

**`AGENTS.md` の記述を変更する**: 「詳細ルールも読み込むこと」という常時読み込みの指示を、「詳細ルールは各フローの手順書が冒頭で指定するタイミングで読む。コマンド外の作業で該当する判断が必要になったときも同じファイルを読む」という趣旨に改める。絶対ルールの要約11箇条は常駐のまま維持する。

**各フローの「事前準備」に読むべきルールファイルを明記する**。どのフローがどのルールを読むかの割り当ては設計フェーズ（design.md）で確定するが、次の原則に従う:

- 承認・ステータス遷移・履歴参照の判断をするフロー → `rules/workflow.md`
- 実装・進捗更新・コミット・TDD の判断をするフロー → `rules/implementation.md`（必要なら `workflow.md` も）
- 手順書自体に必要事項が完結しているフロー → ルールを読ませない
- **同一セッション内で既に読んだルールファイルを再読しない**ことを手順書に明記する

**検証可能な目標**: 変更後、`CLAUDE.md` から `@import` される内容の合計行数（`CLAUDE.md` 本文 + AGENTS.md + `project/context.md` の雛形）が **120行以下**であること。

### §4.5 大量出力のサブエージェント委任基準

「既定は主エージェント自身が作業する」という現行方針（AGENTS.md ルール11）は維持したうえで、**委任が明らかに割に合うケース**の具体例としてトークン節約を明文化する。

対象は「出力が大きく、主エージェントに必要なのは結論だけ」の読み取り専用作業:

- テストスイート全体の実行と失敗箇所の特定
- リポジトリ全体にわたる横断調査（呼び出し元の洗い出し、命名規約の確認など）
- 大規模な差分・ログファイルの確認

**判断の目安**: 想定される出力が数百行を超える、または複数ファイルの全文読みが必要な場合は委任を検討する。それ未満は主エージェントが自分で行う。

この基準は `rules/implementation.md` の並列規約と `knowledge/subagent-orchestration.md` に記載する。**書き込みを伴う実装の委任基準は変更しない**（従来どおり独立な機能単位が2つ以上あるときのみ）。

### §4.6 Compact instructions

`CLAUDE.md` に「Compact instructions」節を追加し、自動コンパクション時に何を残すかを指示する。

**残すもの**: 現在のループ名とブランチ / spec・design・tasks の `status` / tasks.md の未完了タスクと `current:` / 人間が下した決定と未決事項 / 直近の検証結果（テスト・Lint・ビルドの成否）。

**捨ててよいもの**: 読み込んだファイルの全文 / 探索の過程 / すでに tasks.md やspec.md に書き戻し済みの内容。

あわせて、**停止点の前にチャット上の決定事項を成果物ファイルへ書き戻す**ことを各フローに明記する（clear・compact のどちらでも情報が失われないようにするため）。書き戻し先は既存の欄を使う: spec.md の「未決事項」「変更履歴」、design.md の変更履歴、tasks.md のタスク本文。新しい欄・新しいファイルは作らない。

### §4.7 README のトークン運用の節

利用者向けに、次を含む節を追加する:

- フェーズ境界で `/clear` する運用（重い境界では Claude が案内すること、clear しても SessionStart フックで現在地が復元されること）
- `/context` `/usage` での確認
- Opus / Sonnet の使い分け（`/aidd-implement` が Sonnet 既定であること、複雑な設計判断で Opus に切り替える指針）
- 具体的なプロンプトを書くこと（曖昧な依頼が広域スキャンを誘発する）
- 大きい調査は読み取り専用サブエージェントに委任されるため、詳細出力は主コンテキストに残らないこと

### §4.8 一貫性の担保

`knowledge/template-maintenance.md` の一貫性マトリクスに、今回追加される変更軸の行を追加する:

- 「フェーズ境界の運用（`/clear` 案内・自動継続の範囲）」 → 影響: `flows/approve.md`・`flows/implement.md`・停止点を持つ全 flows・`rules/workflow.md`・README
- 「SessionStart フック・スクリプト」 → 影響: スクリプト本体・`.claude/settings.json`・README（ディレクトリ構成）・`rules/workflow.md`
- 「常駐コンテキストの構成（`CLAUDE.md` の `@import`）」 → 影響: `CLAUDE.md`・`AGENTS.md`・ルールを読む全 flows・README

また、テンプレートの設計原則に「**節約のために承認ゲート・TDD 順序・進捗可視化を犠牲にしない**」を追加する。

## 5. 技術方針

`.aidd-docs/` 本体（flows・rules・knowledge）の記述変更が中心で、新規に追加するコードはフックスクリプト1本のみ。スクリプトの配置・言語・出力契約と、「どのフローがどのルールを読むか」の割り当ては設計フェーズ（design.md）で確定する。

## 6. 影響範囲

| 対象 | 変更内容 |
|---|---|
| `CLAUDE.md` | `@import` を2本に削減、Compact instructions 節を追加 |
| `AGENTS.md` | 詳細ルールの読み込みタイミングの記述変更、ルール11に節約目的の委任を追記 |
| `.aidd-docs/rules/workflow.md` | 承認後の自動継続範囲、フェーズ境界の clear 運用、サブエージェント節 |
| `.aidd-docs/rules/implementation.md` | 大量出力の委任基準 |
| `.aidd-docs/flows/approve.md` | 承認後の既定動作テーブル、`go` 引数 |
| `.aidd-docs/flows/implement.md` | 完了時の停止、事前準備でのルール読み込み |
| `.aidd-docs/flows/spec.md` `design.md` `tasks.md` `review.md` | 停止点の「次の一手」行、決定事項の書き戻し、ルール読み込み |
| `.aidd-docs/flows/check.md` `docs.md` `docs-fix.md` `status.md` `vision.md` | ルール読み込み指示（必要なフローのみ） |
| `.aidd-docs/flows/README.md` | 表記規約に「次の一手」行の書式を追加 |
| `.aidd-docs/knowledge/subagent-orchestration.md` | 節約目的の委任基準 |
| `.aidd-docs/knowledge/template-maintenance.md` | 一貫性マトリクス3行・設計原則1項目の追加 |
| **新規** フックスクリプト1本 | SessionStart で現在地を出力（配置と名称は design.md で確定） |
| `.claude/settings.json` | SessionStart フックの登録（テンプレート提供の初期値として） |
| `README.md` | トークン運用の節、ディレクトリ構成図、承認の仕組みの記述更新 |

**破壊的変更**: `/aidd-approve` の tasks 承認後の挙動が変わる（自動継続 → 停止）。既存の利用者は承認後に `/clear` + `/aidd-implement` を打つ手数が1回増える（`go` 引数で従来動作も可能）。

**移行**: 不要。ファイル差し替えのみで完結する。

## 7. 環境変更・依存の追加

**なし。** フックスクリプトは `bash` と POSIX 標準コマンドのみで実装し、追加のインストール・ダウンロードは行わない。

## 8. 未決事項

| 事項 | 仮決めした内容 | 理由 |
|---|---|---|
| 重い境界でも継続したい場合の手段 | `/aidd-approve <ループ名> go` 引数を追加（§4.1） | 停止を既定にすると「今すぐ実装まで進めたい」ケースの逃げ道が無くなるため。引数名は `go` 以外でもよい |
| SessionStart フックの発火範囲 | startup / resume / clear / compact のすべて（§4.3） | clear 直後だけに限ると、通常起動時の現在地把握が効かない。出力は数行なので全発火でも安価と判断 |
| フック出力に `next:` を含めるか | 含める（§4.3） | 含めないと Claude が status を読み直す手間が発生する。判定は frontmatter からの機械的導出のみで、判断をスクリプトに委ねてはいない |
| ルール読み込みの割り当て | 原則のみ仕様に記載し、フロー別の割り当て表は design.md で確定（§4.4） | 割り当ては構造の決定であり、設計フェーズの成果物として扱うのが適切 |
| 常駐行数の目標値 | 120行以下（§4.4） | 公式目安200行に対し、雛形状態の `project/context.md` が薄い分を見込んだ値。プロジェクト固有内容を書き足す余地を残す |

## 変更履歴

| 日付 | 変更内容 |
|---|---|
| 2026-08-22 | 初版作成 |
