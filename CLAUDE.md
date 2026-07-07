# プロジェクトルール

プロジェクト概要・絶対ルール・操作の一覧はエージェント共通の @AGENTS.md にある。詳細ルールも読み込むこと:

@AGENTS.md
@dev-docs/rules/workflow.md
@dev-docs/rules/implementation.md

## Claude Code 固有の構成

- **スラッシュコマンド**（`.claude/commands/`）は `dev-docs/flows/` の手順書への薄いラッパー。`/implement` のみ frontmatter `model: sonnet` で軽量モデル実行になる
- **スキル**（`.claude/skills/`）は `dev-docs/knowledge/` の知識ファイルへの薄いローダー（コマンド外の作業中にも自動発見できるように残してある）
- **本体はすべて `dev-docs/` 側**。ルール・手順・知識を変更するときは `dev-docs/` を編集し、`.claude/` 配下のラッパー/ローダーに本文を書かないこと（`template-maintenance` 知識ファイル参照）
