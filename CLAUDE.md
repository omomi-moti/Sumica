# Sumica

部屋を平面図として描き、時間経過で汚れていく様子を可視化する iOS アプリ。
個人開発・短期プロジェクト。過剰な抽象化や将来拡張の先取りはしない。

## 分担（最重要）

`Domain/` と `Render/Canvas2DRoomRenderer.swift` は本人が学習目的で書く領域。

**YOU MUST NOT edit any file under `Domain/`, `Render/Canvas2DRoomRenderer.swift`, or `SumicaTests/Domain/`, unless explicitly asked.**

- チャット上でも完成形の実装コードを出さない。関数シグネチャ案・アルゴリズムの方針・原因候補・反例となる入力までに留める。
- テストは編集しないが、テストケースの案（入力・期待値の表）を提示するのはよい。
- リネームや型変更が上記に波及する場合は、実行せず影響範囲を報告して指示を待つ。
- バグの原因が上記にあると判断したら、修正せず根拠を示して止まる。

## 前提環境

- Swift 6.2（言語モードは 5）/ iOS 26.1 以上 / Xcode 26.1.1
- テスト: `SumicaTests` は Swift Testing（`@Test` / `#expect`）、`SumicaUITests` は XCTest
- 永続化: SwiftData。`@Model` は `Data/Models/` に置く

## コマンド

```bash
# ビルド
xcodebuild build -project Sumica.xcodeproj -scheme Sumica -destination 'platform=iOS Simulator,name=iPhone 17'

# テスト
xcodebuild test -project Sumica.xcodeproj -scheme Sumica -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SumicaTests

# 単一テスト
xcodebuild test -project Sumica.xcodeproj -scheme Sumica -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SumicaTests/<Suite>/<test>
```

`xcodebuild` の出力は数千行になる。全文を読み返さず `grep -E 'error:|warning:|Test Case.*failed'` で抽出する。

`name=iPhone 17` が見つからない場合は `xcrun simctl list devices available` で実在するシミュレータに置き換える（destination の形式は変えない）。

push 前にテストが通ること。GitHub Actions で同じテストが走る。

## ディレクトリ構成

- `Domain/` 純粋関数。SwiftUI / SwiftData / Foundation の日時 API に非依存
- `Data/` Repository と SwiftData モデル
- `Feature/` 画面ごと（`Room/` など）
- `Render/` 描画層
- `Shared/` 副作用を持つユーティリティ（通知スケジューラ、日付フォーマット等）

`Data/` は永続化とその入出力、`Shared/` はそれ以外の副作用。迷ったら聞く。

配置のルール:

- **IMPORTANT: `Domain/` 内の関数は `Date()` を呼ばない。現在時刻は必ず引数で受け取る。** テストでも `Date()` ではなく固定日時を使う。
- 汚れの計算・粒子の配置・モップの経路はすべて `Domain/` に置く。描画層に書かない。

設計の背景は [docs/architecture.md](docs/architecture.md) を参照。

## 制約

依存ライブラリを追加しない（開発ツールを除く）。必要だと判断した場合は追加せず提案する。

## Git

- Conventional Commits に従う（`feat:` `fix:` `refactor:` `test:` `docs:` `chore:` `ci:`）
- コミットメッセージ・PR 本文・コード内コメント・識別子は英語。チャットの応答は日本語
- ブランチを切って PR を作る。`main` に直接コミットしない
- ブランチ名は prefix + kebab-case（例: `feat/dirtiness-calculation`）
- commit は指示されたときだけ行う。`git push` と PR 作成は勝手にしない

## 迷ったとき

- 仕様が決まっていない点は推測で実装せず質問する。
- このファイルのルール同士が衝突したら、勝手に解釈せず衝突を指摘する。
