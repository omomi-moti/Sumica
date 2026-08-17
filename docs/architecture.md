# アーキテクチャ上の決定

**なぜそうするか** を書く。何を作るかは [spec.md](spec.md)、データと関数の定義は [domain-model.md](domain-model.md)、行動ルールは [CLAUDE.md](../CLAUDE.md)。

実装しながら変わりうる。変わったらこのファイルを更新する。

---

## 1. 設計の根幹

### 汚れ度は永続化しない

`Area.lastVerifiedCleanAt` からの純粋関数で毎回算出する。

タイマーで汚れ値を加算する実装にすると、アプリ非起動中の経過補完・バックグラウンド復帰・端末時刻の変更・保存タイミングを全部自前で抱えることになる。

純粋関数にすると永続化対象は `Date` 1つで済み、テストが書け、**閾値到達時刻を逆算できる**。この逆算可能性が、サーバなしでローカル通知を成立させる根拠になる。

副産物として、**未来の任意時刻の汚れ度を今計算できる**。通知を数日分まとめて予約できるのはこの性質による。

### 現在時刻は引数で受け取る

`Domain/` 内の関数は `Date()` を呼ばない。

上記の「逆算」も、テストも、時刻を注入できることが前提になっている。`Date()` を内部で呼ぶと、任意の経過時間に対する検証ができなくなる。テストでも `Date()` ではなく固定日時を使う。

### 計算は描画層に置かない

汚れの計算・粒子の配置・モップの経路はすべて `Domain/` に置く。

Phase 2 で描画を 2D から 3D に差し替えたときに、計算部分を書き直さないため。`Canvas` の中で乱数を呼ぶと、その時点で作り直しが確定する。

ただし **`RoomRenderer` protocol は Phase 1 では作らない**。§4 を参照。

### 区画は長方形のみ

理由と却下した選択肢は [domain-model.md](domain-model.md) に記載。要点は「頂点配列にしても凹形状は扱えないため、複雑さを払う見返りが無い」。

---

## 2. 技術選定

| 項目 | 選択 | 理由 |
|---|---|---|
| 言語 | **Swift 6**（言語モード 6） | データ競合をコンパイル時に検出する。SwiftData の `ModelContext` は `Sendable` でないため、どこが `@MainActor` に閉じているべきかが明示される |
| デプロイメントターゲット | **iOS 26.1** | §2.1 |
| Xcode | **26.1.1** | |
| UI | SwiftUI | 使う描画 API（`Canvas` / `TimelineView` / `RealityView` / `matchedGeometryEffect`）がいずれも SwiftUI 側にある。UIKit から使うにはラップが要る |
| 状態管理 | `@Observable`（Observation） | §2.2 |
| 永続化（部屋の状態） | SwiftData | §2.3 |
| 永続化（設定値） | `UserDefaults` | 通知のオン/オフ・時刻・ペースの3つ。関連も検索も要らない単一の値で、View から `@AppStorage` で直接読める。SwiftData に入れると `ModelContext` 経由になり、得るものが無い |
| 2D描画 | `Canvas` + `TimelineView` | §2.4 |
| 3D描画 | RealityKit（`RealityView`） | §3 |
| 通知 | `UserNotifications`（ローカル） | 閾値到達時刻を逆算できるため、配信判断をサーバに置く必要がない（§1） |
| テスト | Swift Testing | 対象が純粋関数なので `@Test(arguments:)` で境界値を表として渡せる。XCTest だと同じことをループで書くことになる |
| **アプリに入る依存** | **ゼロ** | 描画・永続化・通知・テストがすべて標準フレームワークで揃っており、入れる候補が存在しない |

「依存ゼロ」は**アプリバイナリに入るもの**の話。開発ツールは別枠（§6）。依存を減らすこと自体が目的ではなく、必要が生じていないだけ。

### 2.1 デプロイメントターゲット

**使う API の下限は iOS 18。**

| API | 必要バージョン |
|---|---|
| `RealityView` / `.realityViewCameraControls(.orbit)` | **iOS 18** |
| SwiftData / Observation | iOS 17 |
| `Canvas` / `TimelineView` | iOS 15 |
| `matchedGeometryEffect` | iOS 14 |

Phase 2 の RealityKit が最も高い下限を要求する。ここが実質的な足切りライン。

**では 18 に置かず 26.1 にする理由。** 下げても得るものが無い。対応端末が増えても利用者は増えず、代わりに `#available` の分岐と旧 OS での確認という作業だけが残る。

積極的な理由もある。Phase 2 の主戦場である RealityKit は毎年 API が増える領域で、低く張ると実装中に「使いたい API が下限を超えている」が発生し、結局その時点で上げることになる。最初から最新に置けばこの判断自体が発生しない。

### 2.2 状態管理

`@Observable` を使う理由は記述量ではなく、**再評価の粒度**にある。

| | 変更を伝える単位 |
|---|---|
| `ObservableObject` | オブジェクト全体。`objectWillChange` が1つしかないため、どのプロパティが変わっても、そのオブジェクトを見ている View がすべて再評価される |
| `@Observable` | プロパティ単位。View の `body` が実際に読んだプロパティを実行時に記録し、**それが変わった View だけ**を再評価する |

**このアプリでは差が具体的に出る。** メイン画面には性質の違う2つが同居している。

- 部屋の `Canvas` — `TimelineView` で高頻度に再描画される
- 下段の問いとタスク — 1日1回しか変わらない

`ObservableObject` だと、どちらか一方が変わっただけで両方が再評価される。`Canvas` の描画は粒子を数百個扱うため、ここを不要に巻き込むのは避けたい。`@Observable` なら、下段のテキストだけを更新して `Canvas` に触らない、という分離が**宣言を増やさずに成立する**。

副次的に `@Published` の付け忘れが構造的に起きなくなる（プロパティが素の `var` のままでよい）が、これは理由の主ではない。

### 2.3 永続化

**保存先を2つに分ける。**

| 対象 | 保存先 | 理由 |
|---|---|---|
| 部屋の状態（`Room` / `Area`） | SwiftData | 関連を持つ木構造。将来 確認履歴が増える余地がある |
| 設定値（通知オン/オフ・時刻・ペース） | `UserDefaults` | 独立したスカラが3つ。関連も検索も要らない |

分ける理由は、性質が違うものを同じ仕組みに載せると、片方に合わせた作りがもう片方の邪魔をするため。設定値を SwiftData に入れると、値を1つ読むために `ModelContext` が要る。逆に部屋の状態を `UserDefaults` に入れると、木構造を毎回まるごとエンコードすることになる。

以下は SwiftData 側の話。

保存するのは `Room` 1件と、それにぶら下がる `Area` 5件。木構造が1つあるだけで、実質 `Date` と `Int` が数個。

比較対象は2つ。

| 候補 | 判断 |
|---|---|
| **Core Data** | SwiftData と同じ永続化スタック（SwiftData は Core Data の上に構築されている）。できることはほぼ同じで、選ぶとすれば段階的なスキーマ移行を細かく制御したい場合。今回はスキーマが小さく、そこまでの制御を必要としない。`@Model` と `@Query` で SwiftUI と直結する分、SwiftData の方が記述が素直 |
| **`Codable` + ファイル** | 全体が木構造1つなので、まるごと JSON に書けば足りる。フレームワークも `@Model` も要らない最小構成。**現時点の要求だけを見ればこれで十分** |

その上で SwiftData を選ぶ理由は2つ。

- **変更を View に伝える経路を自前で持たなくて済む。** `Codable` + ファイルの場合、保存と読み込みに加えて「変わったことを View に知らせる」仕組みを自分で用意することになる。`@Query` がそこを担う
- **件数が伸びるデータが入る余地があること。** halfLife の自動調整（[spec.md](spec.md) §2.3-C）を入れる場合、確認履歴という時系列データが増え続ける。木構造まるごとの読み書きだと、件数に比例して毎回の読み書きが重くなる

**決め手は強くない。** この規模ならどちらでも成立するし、SwiftData 側にも `ModelContainer` の初期化と Swift 6 の並行性という持ち出しがある（§8）。**現時点の要求に対してはオーバースペック**であることは認識した上で選んでいる。

### 2.4 2D描画

**`Canvas` を選ぶ理由は、粒子に identity が要らないから。**

SwiftUI の View は1つ1つが identity を持ち、状態・アニメーション・ヒットテスト・アクセシビリティの単位になる。汚れの粒子はそのどれも必要としない。個別にタップされず、個別に状態を持たず、まとめて消える。**View にする理由が無いものを View にしない**、というのが選定理由。

`Canvas` は `GraphicsContext` に描画命令を出すだけで View を作らないため、この用途に合う。

なお「View を数百個並べると遅い」という性能面の主張は**計測していない**。SwiftUI がどこまで捌けるかは実測しないと分からないので、選定の根拠には置かない。

**代わりに失うもの。** `Canvas` の中身は View 階層の外にあるため:

- 描いた要素ごとのヒットテストが無い。区画のタップ判定は座標から自前で計算する（長方形なので範囲比較2回）
- VoiceOver に乗らない。`accessibilityChildren(children:)` で別途宣言が要る（Phase 1 では入れない）

どちらも今回は許容できる。タップ対象は5区画だけで、判定は Domain 側に置ける。

**`TimelineView` は再描画の駆動に使う。** schedule を渡すと、その時刻を含む `Context` で中身を再評価する。タイマーと `@State` を自前で持つ必要がない。

汚れ度を時刻から算出する設計（§1）と噛み合う点が大きい。`Domain/` の関数は現在時刻を引数で受け取る規約なので、**`TimelineView` が渡してくる `context.date` をそのまま流し込める**。View 側が `Date()` を呼ぶ必要がない。

schedule は用途で使い分ける。

| 対象 | 駆動 |
|---|---|
| 汚れの進行 | `TimelineView` の分単位 schedule。数十秒で目に見える変化は起きないため、フレーム単位で回す必要がない |
| モップのアニメーション | ユーザー操作が起点なので `TimelineView` ではなく、進行度を持つ通常のアニメーション |

`TimelineView` は View が画面に出ていない間は更新を止めるため、バックグラウンドで無駄に回らない。

---

## 3. 3D は RealityKit — SceneKit を使わない理由

WWDC25 の「Bring your SceneKit project to RealityKit」セッションで、SceneKit のソフト非推奨が公式に発表された。今後は重大なバグ修正のみで新機能なし、ドキュメント上も deprecated。Apple の公式見解は「新規プロジェクトでは SceneKit を避け、RealityKit を使う」。

当初 SceneKit を候補にしていた根拠は「非ARの単純表示ではカメラ制御が自前になる」だったが、これも誤り。`.realityViewCameraControls(.orbit) / .dolly / .pan` が用意されており、SwiftUI のモディファイアとして軌道カメラが使える。

**既知の注意点:** orbit 操作中に `cameraTarget` を変更するとカメラの注視点が不正になる不具合が報告されている。掃除した区画にカメラを寄せる演出に影響するため、Phase 2 の素振り時に検証する。

**学習コスト:** ECS（Entity Component System）は SceneKit のシーングラフとは考え方が異なり、学習コストは高い。[roadmap.md](roadmap.md) で素振り期間を確保する。

---

## 4. 描画層の抽象化は Phase 2 まで作らない

当初は `RoomRenderer` protocol を切る予定だったが、**Phase 1 では作らない**。

理由は2つ。

**実装が1つしかない。** 抽象化は2つ目が現れてから、実際の差分を見て切る方が正しい形になる。1つしかない段階で切った protocol は、2つ目が来たときに大抵合わない。

**`View` を継承した protocol は扱いにくい。** `associatedtype Body` を持つため、`RoomRenderer` 型の値として保持できない。実行時に 2D/3D を切り替えるには結局 `if` で分岐するか `AnyView` で包むことになり、protocol の利点がほとんど出ない。

守るべきなのは protocol ではなく「**描画層に計算を書かない**」という規律で、それは Domain に関数を置けば達成される。

### 再描画の駆動は描画層の責務

2D版は `TimelineView` で包んで毎分呼ぶ。3D版は RealityKit のレンダリングループから呼ぶ。ViewModel 側で `TimelineView` を持つと 3D 版で邪魔になるため、ViewModel が渡すのは「**時刻を与えると汚れ度の辞書を返す関数**」に留める。

Phase 2 で protocol を切るとしても、この形は変わらない。

---

## 5. 層構成

**MVVM + Repository + Domain（純粋関数）。DIコンテナは入れない。**

DIコンテナは小規模アプリに対して過剰で、配線に半日使うことになるため外す。Repository は protocol を切り、`init` 注入のみ。

Domain を独立させるのは「層を切ること」自体が目的ではなく、§1 の設計判断から必然的に出てきたもの。SwiftUI にも SwiftData にも依存せず、副作用がなく（`Date()` すら呼ばない）、だからテストでき CI で高速に回る。

```
Domain/                          // SwiftUI / SwiftData 非依存。唯一の硬いルール
├─ Dirtiness.swift               // 汚れ度の計算と逆算
├─ AreaSnapshot.swift            // Domain が扱う区画の値型
├─ AreaKind.swift
├─ DustDistribution.swift        // 粒子の配置
├─ MopPath.swift                 // 蛇行パスの生成
├─ DailyQuestion.swift           // その日の問いを決める
├─ NotificationPlanner.swift     // 区画 + 時刻 → 予約すべき通知の配列
└─ Constants/                    // 定数と座標データのみ。計算ロジックは置かない
   ├─ LayoutCatalog.swift
   └─ Tuning.swift

Data/
├─ Models/
│  ├─ Room.swift                 // @Model
│  └─ Area.swift                 // @Model。AreaSnapshot を返すプロパティを持つ
├─ RoomRepository.swift          // protocol
├─ SwiftDataRoomRepository.swift
├─ InMemoryRoomRepository.swift
└─ SettingsStore.swift           // UserDefaults。通知の設定とペース

Feature/
├─ Room/                         // メイン + ViewModel
├─ Onboarding/
└─ Settings/

Render/
└─ Canvas2DRoomRenderer.swift    // Phase 2 で RealityKit 版が並ぶ

Shared/
└─ NotificationScheduler.swift   // 副作用側。UNUserNotificationCenter を叩く
```

**ViewModel を薄く保つ。** 肥大化の対策は層を足すことではなく、押し出し先を決めておくこと。計算は Domain、通知の組み立ては `NotificationPlanner`、永続化は Repository。ViewModel に残るのは配線だけ。

**足さないもの:** UseCase/Interactor 層（ユースケースが3つで中身が転送だけになる）、Coordinator/Router（画面3つで遷移が一直線）、Mapper/DTO（サーバがない）、アーキテクチャライブラリ（依存ゼロ方針と衝突）。

---

## 6. 開発環境

| 項目 | 状態 |
|---|---|
| CI | GitHub Actions（`macos-latest`）。build + test |
| Lint | **未導入。** コード量が増えてから判断する |
| リポジトリ | **private**。ただし macOS ランナーは無料枠の消費が10倍換算になるため、public への切り替えを検討中 |
| ブランチ | **ブランチを切って PR。** `main` 直コミットはしない |
| コミット規約 | Conventional Commits |

**ブランチ運用について。** 当初は「一人開発でレビュー相手がいないため `main` 直コミット」としていたが、CI がある以上 PR には「マージ前に CI が回る」という別の価値がある。

**CI で確認済みの事実:**

- シミュレータ名は Xcode 更新で消える。`iPhone 16` は Xcode 26.1 の既定セットに実体が無く、`iPhone 17` を使っている
- `CODE_SIGNING_ALLOWED=NO` は**不要**。シミュレータ向けビルドは "Sign to Run Locally" で通る
- `xcodebuild test` はビルドも行うため、独立した build ステップは不要

---

## 7. テスト方針

**カバレッジは追わない。純粋関数と時刻計算のみ。** 目安10〜15ケース。

- `dirtiness()` の単調増加性、境界値、表示クランプ
- `dateWhenReaching()` と `dirtiness()` の往復整合
- `partiallyCleaned()` の ratio 境界（0.0 / 1.0）
- `dailyQuestion()` が同じ日付で同じ結果を返すこと
- `DustDistribution` が同じシードで同じ配置を返すこと
- `NotificationPlanner` が指定日数分を返すこと、1日あたり1件を超えないこと
- 初回7日間の切り替わり

**時刻は必ず引数で注入する。** `Date()` をロジック内で直接呼ばない。

UIテストは入れない。シミュレータ起動が遅く不安定で、今回の規模に対して割に合わない。CI は「Domain が壊れてないこと」だけを保証する装置として置く。

---

## 8. 着手時に判断が要る箇所

**アプリ起動時の初回処理をどこに置くか。** オンボーディング済みかの判定と通知の再スケジュール。`@main` の直下か、ルート View の `.task` か。SwiftData のコンテナ初期化と絡むため、着手時に少し考える必要がある。

**通知タップからの遷移。** アプリ未起動の状態から通知タップで確認まで運ぶには、`UNUserNotificationCenterDelegate` で受けて状態を持ち回る必要がある。SwiftUI だと `@Observable` なクラスを1つ挟むのが素直。詰まりやすいポイントなので時間を多めに見る。

**SwiftData と Swift 6 の並行性。** `ModelContext` は `Sendable` ではないため、`@MainActor` を跨ぐ箇所で警告が出る。コードが増えてから顕在化する。
