# コースの計画

このファイルは，教材を作る人とエージェントのための決定事項と約束事をまとめる．
受講者向けの説明は`README.md`と`docs/`にある．
各Iterationで作るもの，学ぶことは`docs/ROADMAP.md`に書く．

## 受講者と目標

- 受講者は，何らかの言語で実務経験があり，テストを書いたことがある．エディタの補完や定義ジャンプは使うが，LSPの中身は知らない．
- Haskellは基礎文法(型，パターンマッチ，`Maybe`と`Either`，`do`記法)が分かる．megaparsec，lens，QuickCheck，STMは，コースの中で必要な分だけ解説する．
- 修了後，受講者は次のことができる．
  - LSPのメッセージの流れ(初期化，通知，リクエストとレスポンス)を説明できる．
  - Haskellの`lsp`ライブラリで，診断，ホバー，定義へ移動，参照，補完，リネーム，アウトラインを持つ言語サーバを作れる．
  - 言語の処理(解析，名前解決，評価)を純粋な関数として作り，LSPとのやり取りから分けてテストできる．
- 教材は日本語で書く．文体は常体で，読点は「，」，句点は「．」を使う．コードの識別子，サーバが返すメッセージ，コード中のコメントは英語で書く．
- Iterationは0〜7の8回で，1回あたり1〜2時間を見込む．

## 題材

小さな式言語Calcの言語サーバを育てる．
Calcのプログラムは`let 名前 = 式`の行を並べたもので，式は整数，変数，`+` `-` `*` `/`と括弧からなる．
`--`から行末まではコメントである．
完成形の使用例は`docs/ROADMAP.md`の冒頭にある．

## 設計文書

各パッケージの`design/`に，次の4つのファイルを置く．
記法はすべてMarkdownの中のMermaidで，図の上に1〜2文の説明，図で表せない決まりは図の下の箇条書きに書く．

| ファイル | 表すもの | 記法 | 育ち方 |
| --- | --- | --- | --- |
| `c4-context.md` | C4のContextとContainer．利用者，VS Code，Calc拡張機能，Calcサーバ，`.calc`ファイルと，その間でやり取りするもの | `flowchart` | Iterationごとに，やり取りする機能(ログ，診断，ホバー…)を関係のラベルに足す |
| `c4-component.md` | C4のComponent．サーバのモジュールと依存の向き．純粋な`Calc.*`とIOを扱う`Lsp.*`を`subgraph`で分ける | `flowchart` | モジュールと矢印を足し，リファクタリングで描き直す |
| `code-flow.md` | C4のCode．型をノード，関数を矢印のラベルにした，入力(文書，位置)から出力(LSPの型)までの流れ | `flowchart` | 機能ごとの流れを足す．Iteration 7で`analyze`を起点に描き直す |
| `lsp-sequence.md` | エディタとサーバが交わすLSPのメッセージの順序 | `sequenceDiagram` | 新しいメソッドと分岐を足す |

図は次の決まりで書く．

- `c4-component.md`のモジュールのノードは`Calc_Parser["Calc.Parser"]`のように，ラベルにモジュール名をそのまま書く．矢印`A --> B`は「AがBをimportする」を表す．
- パッケージの外にあるもの(`lsp`，megaparsecなどのライブラリ)は，`ext_`で始まるIDのノードで描く．照合の対象から外れる．
- `scripts/check-design.mjs`が，`c4-component.md`のモジュールの矢印と`src/`・`app/`のimportを比べ，片方にしかない依存を報告する．
- `scripts/check-mermaid.mjs`が，`design/`と`docs/`のすべてのMermaidのブロックを構文解析する．

## 開発環境

### Dev Container

- ベースは`jdxcode/mise`のDebianイメージ．`.devcontainer/Dockerfile`がghcupで次の版を入れる．
  - GHC 9.10.3，cabal 3.16.1.0，HLS 2.14.0.0
  - fourmolu 0.21.0.0とhlint 3.10(cabalでビルドして`/usr/local/bin`に置く)
- node，pnpm，rtk，lefthookは`mise.toml`で版を固定する．
- VS Codeには次の拡張機能を入れる．
  - `haskell.haskell`(HLS．整形はfourmolu，ヒントはhlint)
  - `justusadam.language-haskell`
  - `bierner.markdown-mermaid`(Markdownのプレビューで図を見る)
  - `DavidAnson.vscode-markdownlint`
  - Calc拡張機能(`clients/vscode`．`mise run client`でビルドして入れる)

### Calc拡張機能

`clients/vscode`は，コース側で用意する最小のVS Code拡張機能である．
`.calc`ファイルを開くと`.bin/calc-lsp`を起動し，標準入出力でLSPを話す．
`calc.trace.server`を`verbose`にすると，出力パネル「Calc Language Server」にJSON-RPCのメッセージが出る．
受講者は`mise run use-server <パッケージ>`で，`.bin/calc-lsp`の指す実行ファイルを切り替える．

### ビルドとテスト

- ビルドはcabal．ルートの`cabal.project`にパッケージを並べる．
- 単体テストはhspecとhspec-discover，統合テストはhspecとlsp-test．
- 整形にはfourmolu(`fourmolu.yaml`)を，リントにはhlint(`.hlint.yaml`)を使う．
- 文書のリントはtextlintとmarkdownlint-cli2．

### リポジトリの構成

```text
COURSE.md                        この計画
README.md                        受講者向けのコースの概要とIterationの一覧
cabal.project                    cabalのプロジェクト．各Iterationのパッケージを登録する
docs/ROADMAP.md                  Iterationごとの要求，学ぶこと，設計文書の更新
docs/tdd.md                      テスト駆動開発とテストリストの書き方
docs/design.md                   設計文書の書き方
docs/haskell/README.md           文法と概念のノートの目次
docs/haskell/iteration-N.md      Iteration Nで初めて使う文法と概念のノート
clients/vscode/                  Calc拡張機能
scripts/                         設計文書の検査スクリプト
iterations/iteration-N/
  exercise/                      受講者が手を動かす場所
  solution/                      完成したコードと模範解答
```

### パッケージ

- パッケージ名は`calc-lsp-iterN-exercise`と`calc-lsp-iterN-solution`．`.cabal`ファイルはパッケージ名にそろえる．
- パッケージは次のコンポーネントを持つ．
  - ライブラリ(`src/`)．`Calc.*`と`Lsp.*`のモジュールを`exposed-modules`に並べる．
  - 実行ファイル`calc-lsp`(`app/Main.hs`)．`main = Lsp.Server.run`だけを持つ．
  - テストスイート`unit`(`test/unit/`)と`integration`(`test/integration/`)．どちらも`Spec.hs`がhspec-discoverの入口である．
- テストのファイルはモジュールごとに1つで，`test/unit/Calc/ParserSpec.hs`のように名前をそろえる．統合テストは機能ごとに`test/integration/HoverSpec.hs`のように分ける．
- 統合テストはlsp-testでサーバを同じプロセスの中で起動する．起動の手順は`test/integration/TestServer.hs`にまとめる．
- 言語は`GHC2021`．`OverloadedStrings`などの拡張は，使うファイルの先頭で`LANGUAGE`プラグマとして宣言する．

### 登録

- `cabal.project`には，すべての`solution`パッケージを登録する．
- `exercise`パッケージは受講者が自分で`cabal.project`に1行足して登録する．各Iterationの準備の手順で案内する．
- 教材を作るときは，すべての`exercise`も並べた`cabal.project.all`で，演習がビルドできることを確かめる．

### コマンド

| コマンド | すること |
| --- | --- |
| `mise run setup` | 依存パッケージを入れ，Gitのフックを設定する |
| `mise run build` | 登録されたすべてのパッケージをビルドする |
| `mise run test` | 登録されたすべてのパッケージのテストを実行する |
| `mise run fmt` | Haskellのソースを整形する |
| `mise run lint` | 整形の検査，hlint，文書のリント，Mermaidの構文検査，設計文書とコードの照合 |
| `mise run check` | `lint`と`test`をまとめて実行する(CIと同じ) |
| `mise run client` | Calc拡張機能をビルドしてVS Codeに入れる |
| `mise run use-server <パッケージ>` | エディタが起動するサーバを，指定したパッケージの`calc-lsp`に切り替える |

cabalのコマンドは，次の順で受講者に見せる．
初めて出るIterationで完全な形を示し，そのあとは「単体テストだけを実行する」のように，することだけを書く．

| Iteration | 初めて示すコマンド |
| --- | --- |
| 0 | `cabal build <パッケージ>`，`cabal test <パッケージ>`，`cabal repl <パッケージ>`，`mise run use-server <パッケージ>` |
| 1 | `cabal test <パッケージ>:test:unit` |
| 3 | `cabal test <パッケージ>:test:unit --test-options='--match "Calc.Eval"'` |
| 4 | `cabal test <パッケージ>:test:integration` |

### ノート

文法と概念のノートは`docs/haskell/iteration-N.md`に置き，`docs/haskell/README.md`に目次を書く．
REPLの例は`cabal repl`で実際に動かした結果を写す．

## Iteration 0の演習の形

- `.cabal`ファイル，`app/Main.hs`はそのまま使える形で置く．
- `src/Calc/Summary.hs`は`countLines`の型だけを持ち，本体は`undefined`にする．
- `src/Lsp/Server.hs`は，`run`，`serverDefinition`と，`initialized`に応じるだけの`handlers`を置く．`options`は`defaultOptions`のままにする．同期の方式とサーバの名前の宣言，`didOpen`と`didChange`のハンドラは受講者が書く．
- `test/unit/Spec.hs`と`test/integration/Spec.hs`は，hspec-discoverの入口だけを置く．`TestServer.hs`は受講者がノートを見て書く．
- `design/`の4つのファイルは，見出しと「ここに何を描くか」のコメントだけを置く．
- `TESTLIST.md`は，単体テストと統合テストの見出しだけを置く．

## 落とし穴

教材を作る中で見つけた，道具や言語の罠を書き足していく．

- `lsp-types`のレコードは，多くのフィールド名(`_change`，`_save`など)を他の型と共有している．`TextDocumentSyncOptions {_change = ...}`のようにレコード構文で値を作るファイルでは，`DisambiguateRecordFields`を有効にする．フィールドを読むときはlens(`^. L.change`)を使う．
- `lsp`は，`optTextDocumentSync`を指定しないと文書の同期方式を宣言しない．その場合，エディタは`didOpen`と`didChange`を送らない．
- `lsp-test`の`defaultConfig`は，サーバからの`window/logMessage`と`window/showMessage`を読み捨てる(`ignoreLogNotifications = True`)．ログを確かめるテストでは`False`にする．
- `lsp-test`の`openDoc'`は公開されていない．ディスクにないファイルを中身ごと開くときは`createDoc`を使う．
- 統合テストでサーバを同じプロセスで動かすときは，`System.Process.createPipe`で作った2本のパイプを`runServerWithHandles`と`runSessionWithHandles`に渡す．テストスイートは`-threaded`でビルドする．
- 実行ファイルとして動かしたサーバは，`lsp`の既定のロガーで`window/logMessage`(例：`can't register dynamically for: "workspace/didChangeConfiguration"`)を送ることがある．統合テストのサーバはロガーに`mempty`を渡すので，この通知は出ない．
- ロケールが設定されていない環境では，hlintが依存する`ghc-lib-parser`のビルドで`happy`がUTF-8のソースを読めずに失敗する(`hGetContents: invalid argument (cannot decode byte sequence …)`)．Dev Containerでは`LANG=C.UTF-8`を設定する．
- fourmolu 0.21とhlint 3.10は，異なる版の`ghc-lib-parser`に依存する．1回の`cabal install`にまとめると依存を解決できないので，別々に入れる．
- GHC 9.10の`Prelude`は`foldl'`を公開している．`import Data.List (foldl')`を書くと，`-Wunused-imports`の警告になる．
