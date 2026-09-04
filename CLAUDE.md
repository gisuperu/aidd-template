# プロジェクトルール

絶対ルール・操作の一覧はエージェント共通の AGENTS.md に、プロジェクト固有の概要・スタック・ルールはプロジェクト層の context.md にある。この2つだけを常時読み込む:

@AGENTS.md
@.aidd-docs/project/context.md

詳細ルール（`.aidd-docs/rules/workflow.md` `.aidd-docs/rules/implementation.md`）は常駐させず、**各フローの手順書が指定するタイミングで読む**（読み分けは `.aidd-docs/flows/README.md` の「ルールファイルの読み込み」を参照）。コマンドを使わない作業でも、承認・ステータス遷移・TDD・進捗更新・コミット粒度の判断が必要になったら該当ファイルを読むこと。

## Claude Code 固有の構成

- **スラッシュコマンド**（`.claude/commands/`）は `.aidd-docs/flows/` の手順書への薄いラッパー（組み込みコマンドとの衝突を避けるため名前は `aidd-` プレフィックス付き）。`/aidd-implement` のみ frontmatter `model: sonnet` で軽量モデル実行になる
- **スキル**（`.claude/skills/`）は `.aidd-docs/knowledge/` の知識ファイルへの薄いローダー（コマンド外の作業中にも自動発見できるように残してある）
- **本体はすべて `.aidd-docs/` 側**。ルール・手順・知識を変更するときは `.aidd-docs/` を編集し、`.claude/` 配下のラッパー/ローダーに本文を書かないこと（`template-maintenance` 知識ファイル参照）
- **フック**: `SessionStart` で `.aidd-docs/scripts/session-context.sh` が走り、現在のブランチ・対象ループ・status・進捗・次に実行すべきコマンドを数行だけ注入する（`/clear` してもフェーズを再開できるようにするため）。登録は `.claude/settings.json`
- **サブエージェント**は Agent ツールで起動する: 読み取り専用の調査・観点別レビューは `Explore`、並列実装の作業者は `general-purpose` を `isolation: "worktree"` で。**既定は主エージェント自身が作業し、委任は適宜の判断または人間の指示で切り替えるモード**（基本は委任しない）。委任すると決めたら作業者のモデルは既定で自身より下位を選ぶ（`model` に `haiku` / `sonnet` 等を指定。haiku でこなせるなら haiku、難しければ同等モデル、上位モデルの能力が要ると判断したら人間に打診する。Claude Code ではモデル切替を人間が `/model` で行うため主エージェントは自分で上げられない）。並列規約は `.aidd-docs/rules/implementation.md`、委任の判断・指示文・検証は `.aidd-docs/knowledge/subagent-orchestration.md`

## Compact instructions

要約するときは、作業を再開できる状態を保つため次を必ず残す: **現在のループ名とブランチ / spec・design・tasks の `status` と `design:` の値 / tasks.md の未完了タスクと `current:` / 人間が下した決定・修正指示と未決の論点 / 直近のテスト・Lint・ビルドの結果**。

次は捨ててよい: 読み込んだファイルの全文・差分の逐語的な内容 / 調査の過程 / すでに spec.md・design.md・tasks.md へ書き戻し済みの内容（ファイルを読み直せばよい）。
