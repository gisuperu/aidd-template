# プロジェクトルール

絶対ルール・操作の一覧はエージェント共通の @AGENTS.md に、プロジェクト固有の概要・スタック・ルールはプロジェクト層の @.aidd-docs/project/context.md にある。詳細ルールも読み込むこと:

@AGENTS.md
@.aidd-docs/project/context.md
@.aidd-docs/rules/workflow.md
@.aidd-docs/rules/implementation.md

## Claude Code 固有の構成

- **スラッシュコマンド**（`.claude/commands/`）は `.aidd-docs/flows/` の手順書への薄いラッパー（組み込みコマンドとの衝突を避けるため名前は `aidd-` プレフィックス付き）。`/aidd-implement` のみ frontmatter `model: sonnet` で軽量モデル実行になる
- **スキル**（`.claude/skills/`）は `.aidd-docs/knowledge/` の知識ファイルへの薄いローダー（コマンド外の作業中にも自動発見できるように残してある）
- **本体はすべて `.aidd-docs/` 側**。ルール・手順・知識を変更するときは `.aidd-docs/` を編集し、`.claude/` 配下のラッパー/ローダーに本文を書かないこと（`template-maintenance` 知識ファイル参照）
- **サブエージェント**は Agent ツールで起動する: 読み取り専用の調査・観点別レビューは `Explore`、並列実装の作業者は `general-purpose` を `isolation: "worktree"` で。**既定は主エージェント自身が作業し、委任は適宜の判断または人間の指示で切り替えるモード**（基本は委任しない）。委任すると決めたら作業者のモデルは既定で自身より下位を選ぶ（`model` に `haiku` / `sonnet` 等を指定。haiku でこなせるなら haiku、難しければ同等モデル、上位モデルの能力が要ると判断したら人間に打診する。Claude Code ではモデル切替を人間が `/model` で行うため主エージェントは自分で上げられない）。並列規約は `.aidd-docs/rules/implementation.md`、委任の判断・指示文・検証は `.aidd-docs/knowledge/subagent-orchestration.md`
