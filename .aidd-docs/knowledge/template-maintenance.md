---
name: template-maintenance
description: このテンプレート自体（.aidd-docs/ の rules・flows・knowledge・_template、AGENTS.md、CLAUDE.md、.claude/ のラッパー、README.md）の変更・改善を求められたときに読む。一貫性を保つための変更手順。
---

# テンプレート自身のメンテナンス

このテンプレートはルール・手順書・知識・雛形・README が相互参照している。**1箇所だけ変えると必ず矛盾が生まれる**ので、変更時は以下に従う。

## 本体とアダプタの構造（最初に理解すること）

- **本体**（エージェント中立・内容はすべてここ）: `.aidd-docs/rules/`（ルール）、`.aidd-docs/flows/`（操作の手順書）、`.aidd-docs/knowledge/`（知識ファイル）、`AGENTS.md`（共通エントリポイント）
- **アダプタ**（エージェント固有・薄い参照のみ）: `.claude/commands/*.md`（flows へのラッパー。frontmatter のみ固有情報）、`.claude/skills/*/SKILL.md`（knowledge へのローダー）、`CLAUDE.md`（AGENTS.md を @import）
- **アダプタに本文を書いてはいけない**。内容の変更は必ず本体側で行う

## 一貫性マトリクス（何を変えたら、どこを更新するか）

以下で rules/ = `.aidd-docs/rules/`、flows/ = `.aidd-docs/flows/`、knowledge/ = `.aidd-docs/knowledge/`、_template = `.aidd-docs/specs/_template/`。

| 変更対象 | 更新が必要なファイル |
|---|---|
| status の値・遷移（draft/approved 等） | rules/workflow.md、両テンプレ（frontmatter）、flows 全部、README |
| チェックボックス・実装中マーカーの表記 | rules/implementation.md、_template/tasks.md、flows/implement.md・status.md、README |
| フェーズ構成（フェーズ0、[RED]/[GREEN] 等） | rules/implementation.md、_template/tasks.md、flows/tasks.md・implement.md、README、knowledge/tdd-antipatterns.md |
| spec の§構成 | _template/spec.md、flows/spec.md、_template/tasks.md（§参照例）、knowledge/spec-writing.md |
| 設計フェーズ関連（design.md・`design:` 要否・§D） | _template/spec.md（frontmatter・§5）・_template/design.md、flows/spec.md・design.md・tasks.md・approve.md・status.md・implement.md・review.md、rules/workflow.md・implementation.md、AGENTS.md、README |
| 操作（コマンド）の追加・削除・改名 | flows/ 本体 + `.claude/commands/` ラッパー + **AGENTS.md の対応表** + rules/workflow.md（フロー図）+ README（コマンド一覧）。コマンド名はエージェント組み込みコマンドとの衝突を避けるため `aidd-` プレフィックスを付ける（flows/ のファイル名には付けない） |
| 知識ファイルの追加・削除・改名 | knowledge/ 本体 + `.claude/skills/` ローダー + 参照している flows の読み込み指示 + README（知識一覧）+（相互参照している他の知識ファイル） |
| ビジョン関連（vision.md の構成・整合ルール・実現の記録） | .aidd-docs/vision.md、rules/workflow.md、flows/vision.md・spec.md・implement.md・check.md・review.md（承認後の記録）・status.md（実現度集計）、_template/spec.md（整合欄）、knowledge/review-perspectives.md、README |
| ドキュメント生成（current-spec.md、/aidd-docs、/aidd-docs-fix） | flows/docs.md・docs-fix.md・review.md・status.md、rules/workflow.md、AGENTS.md、README |
| 承認経路（/aidd-approve、status 遷移の文言） | flows/approve.md・spec.md・tasks.md・review.md・status.md、rules/workflow.md、AGENTS.md、README（コマンド一覧・承認の仕組み） |
| ディレクトリ名（.aidd-docs/ 等） | ほぼ全ファイル。`grep -r ".aidd-docs" .claude/ AGENTS.md CLAUDE.md README.md .aidd-docs/` で洗い出す。開発用の資料は隠しディレクトリ `.aidd-docs/`、人間向けの生成物 `docs/current-spec.md` だけが `docs/`（ユーザー向け領域）にある |
| 絶対ルール・履歴参照ルール | AGENTS.md（要約）と rules/ 詳細の**両方**（2層構造を保つ） |
| 手順書の表記規約 | flows/README.md、影響する flows 全部 |
| サブエージェント・並列実行の規約 | rules/implementation.md（並列規約）・rules/workflow.md（全フェーズ方針）、flows/implement.md・review.md、flows/README.md（表記）、AGENTS.md（ルール11）、CLAUDE.md（Agent ツール対応）、README |

変更前に `grep -r "変更するキーワード" .claude/ .aidd-docs/ AGENTS.md CLAUDE.md README.md` で参照箇所を洗い出すこと。

## テンプレートの設計原則（変更時に壊さないこと）

1. **AGENTS.md は要約、.aidd-docs/rules/ が詳細**の2層構造。エントリポイントを肥大化させない
2. **各手順書は必ず「停止点」を持つ**: /aidd-spec /aidd-tasks /aidd-review は人間のレビュー待ちで終わる。停止点を消す変更はループの目的を壊す
3. **承認ゲートを迂回する便利機能を足さない**（「一括承認」「自動 approve」等は追加しない）
4. **知識ファイルは言語非依存の知識のみ**: PEP8 などの言語別スタイル、特定フレームワークの流儀、デザインのトレンドは時流で変わるため**テンプレートに入れない**。それらはプロジェクト側で用意する（AGENTS.md のプロジェクト概要、またはプロジェクト固有の知識ファイルとして追加）
5. **tasks.md が進捗の唯一の真実**という前提を崩さない（進捗を別の場所にも持たせない）
6. **本体は .aidd-docs、エージェント固有ディレクトリは薄い参照のみ**を保つ。新しいエージェントへの対応は、そのエージェント向けのアダプタ（エントリファイル1枚＋必要ならコマンド定義）を足すだけで済む形を崩さない

## テンプレートの更新フロー

テンプレート自体の変更も、規模が大きければこのループ（/aidd-spec → /aidd-review）に乗せてよい。軽微な変更は直接編集で構わないが、必ず:

1. 一貫性マトリクスで影響ファイルを列挙して全部更新する
2. README の説明・ディレクトリ構成図と AGENTS.md の対応表を同期する
3. 変更後、`grep` で旧表記の残骸がないことを確認する
