---
name: infra-architecture
description: コンテナ構成・ネットワーク構成を仕様に含めるとき、Dockerfile / compose / デプロイ構成を書くときに読む。ベストプラクティスと一時回避の基準。
---

# コンテナ・ネットワーク構成の知識

security-practices スキルと同じ3段階（ベスト / 一時回避 / 禁止）で示す。一時回避を選んだら spec の「既知の制限」に返済条件付きで記録する。

## コンテナ（Dockerfile）

- **1コンテナ1責務**: アプリ・DB・キャッシュは別コンテナ。プロセスマネージャで複数プロセスを詰めない
- **マルチステージビルド**: ビルド用と実行用を分け、実行イメージにはランタイムと成果物だけ入れる
- **非rootで実行**: `USER` を指定する。
  - 一時回避: ローカル開発のみ root 可（条件: 本番用 Dockerfile では非root）
- **ベースイメージのタグ固定**: `node:22.x-slim` のように固定。
  - 禁止: 本番での `latest` 運用
- **秘密情報をイメージに焼かない**: env / secret mount で実行時注入。
  - 禁止: `COPY .env` やビルド引数での秘密の埋め込み（レイヤに残る）
- **ヘルスチェック**: `HEALTHCHECK` またはオーケストレータ側の liveness/readiness を定義
- **データは volume へ**: コンテナ内書き込みに依存しない（コンテナは使い捨て前提）
- `.dockerignore` を用意（`.git`, `node_modules`, `.env` 等）

## ネットワーク（compose / デプロイ構成）

- **公開は最小限**: 外部に公開するのはリバースプロキシ（または API ゲートウェイ）の 80/443 のみ
  - 禁止: DB・キャッシュ・内部管理ポートのインターネット公開
- **内部ネットワーク分離**: compose では DB を内部ネットワークに置き、`ports:` を書かない（アプリからはサービス名で解決）
  - 一時回避: ローカル開発で DB ポートを localhost に bind して公開（条件: `127.0.0.1:5432:5432` のように localhost 限定）
- **TLS はプロキシで終端**: アプリ間の内部通信は初期は平文可（条件: 信頼できるネットワーク内に限る）
- **設定は環境変数で注入**: 環境（dev/stg/prod）ごとの差分はイメージを変えず env で切り替える
- **サービス間依存**: 起動順は healthcheck + `depends_on: condition` で制御（sleep で待たない）

## 構成例（compose の骨格）

```yaml
services:
  proxy:      # 唯一の公開点。TLS終端
    ports: ["443:443"]
    networks: [edge, internal]
  app:
    networks: [internal]   # 外部非公開
    env_file: .env         # .gitignore 済みであること
    depends_on:
      db: { condition: service_healthy }
  db:
    networks: [internal]   # ports: を書かない
    volumes: [db-data:/var/lib/...]
    healthcheck: { test: [...], interval: 5s }
networks:
  edge:
  internal:
    internal: true
volumes:
  db-data:
```

## 仕様書に書くとき

- spec の§技術方針に: コンテナ一覧（責務）、公開ポート、ネットワーク分離、秘密情報の注入方法、永続化する volume を明記する。
- 一時回避（root実行、DBポートのlocalhost公開など）は「既知の制限」へ。
- 新しいベースイメージ・ツールの導入は「環境変更・依存追加」（フェーズ0の人間承認枠）に列挙する。
