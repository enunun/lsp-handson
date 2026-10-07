# HaskellでLSPサーバを作るハンズオン

小さな式言語Calcのための言語サーバ(LSPサーバ)を，Haskellの`lsp`ライブラリで作るコースである．
Iteration 0〜7の8回で，1つのサーバを少しずつ育てる．
最後には，VS Codeで診断，ホバー，定義へ移動，参照，補完，リネーム，アウトラインが動く．

```text
-- sample.calc
let rate = 8
let price = 1200
let tax = price * rate / 100
let total = price + tax + fee    ← undefined variable 'fee'
```

## 対象

- 何らかの言語で実務経験があり，テストを書いたことがある．
- Haskellの基礎文法(型，パターンマッチ，`Maybe`と`Either`，`do`記法)が分かる．
- LSPの中身は知らなくてよい．

## 進め方

どのIterationも，テストリスト → 設計文書 → テストファーストの実装 → 設計の見直しの順に進める．
手を動かす場所は`iterations/iteration-N/exercise`で，`iterations/iteration-N/solution`に模範解答と解説がある．
Iteration Nの演習は，Iteration N-1の模範解答と同じコードから始まる．

| Iteration | 作る機能 | 演習 | 模範解答 |
| --- | --- | --- | --- |
| 0 | サーバの起動，エディタのログへの行数の出力 | [exercise](iterations/iteration-0/exercise/) | [solution](iterations/iteration-0/solution/) |
| 1 | `let`の形をしていない行の診断 | [exercise](iterations/iteration-1/exercise/) | [solution](iterations/iteration-1/solution/) |
| 2 | 式の構文解析，未定義変数と二重定義の診断 | [exercise](iterations/iteration-2/exercise/) | [solution](iterations/iteration-2/solution/) |
| 3 | ホバーで変数の値を表示 | [exercise](iterations/iteration-3/exercise/) | [solution](iterations/iteration-3/solution/) |
| 4 | 定義へ移動，すべての参照を検索 | [exercise](iterations/iteration-4/exercise/) | [solution](iterations/iteration-4/solution/) |
| 5 | 補完 | [exercise](iterations/iteration-5/exercise/) | [solution](iterations/iteration-5/solution/) |
| 6 | リネーム | [exercise](iterations/iteration-6/exercise/) | [solution](iterations/iteration-6/solution/) |

各Iterationの要求と学ぶことは[ロードマップ](docs/ROADMAP.md)にある．

## 環境の準備

1. DockerとVS Code(Dev Containers拡張機能)を入れる．
2. このリポジトリをVS Codeで開き，コマンド「Dev Containers: Reopen in Container」を実行する．初回はイメージの作成に時間がかかる．
3. コンテナの中のターミナルで次を実行し，すべて通ることを確かめる．

   ```sh
   mise run check
   ```

4. Calc拡張機能をVS Codeに入れる．

   ```sh
   mise run client
   ```

`mise tasks`で，使えるタスクの一覧が見られる．

## 資料

- [ロードマップ](docs/ROADMAP.md): 各Iterationの要求，使用例，学ぶこと
- [テスト駆動開発とテストリスト](docs/tdd.md)
- [設計文書の書き方](docs/design.md)
- [文法と概念のノート](docs/haskell/README.md)
- [Calc拡張機能](clients/vscode/README.md)
