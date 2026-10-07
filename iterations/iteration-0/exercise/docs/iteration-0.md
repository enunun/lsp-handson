# Iteration 0: サーバを起動してエディタとつなぐ

このIterationでは，エディタとつながり，開いた文書の行数をエディタのログに書くサーバを作る．
LSPのメッセージの流れ(初期化，通知)と，`lsp`ライブラリでサーバを組み立てる方法を学ぶ．

## 0-1 準備

1. ルートの`cabal.project`の`packages`に，このパッケージの行を足す．

   ```text
   packages:
     iterations/iteration-0/solution
     iterations/iteration-0/exercise
   ```

2. ビルドし，テストを実行する．テストはまだ1つもないので，どちらのスイートも`0 examples, 0 failures`になる．

   ```sh
   cabal build calc-lsp-iter0-exercise
   cabal test calc-lsp-iter0-exercise
   ```

3. Calc拡張機能をVS Codeに入れ(最初の1回だけ)，エディタが起動するサーバをこのパッケージにする．

   ```sh
   mise run client
   mise run use-server calc-lsp-iter0-exercise
   ```

4. VS Codeで`examples/sample.calc`を開く．設定`calc.trace.server`を`verbose`にし，コマンド「Calc: Restart Server」を実行する．出力パネルの「Calc Language Server」に，`initialize`のリクエストとレスポンスが出ることを確かめる．今のサーバは，文書を開いてもログを書かない．

## 0-2 文法と概念

[Iteration 0のノート](../../../../docs/haskell/iteration-0.md)を読み，最後の「REPLの課題」を`cabal repl calc-lsp-iter0-exercise`で解く．

## 0-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- エディタが`.calc`ファイルを開くと，サーバが起動して初期化に応じる．サーバは名前`calc-lsp`を名乗り，文書を全文で受け取ることを宣言する．
- 文書を開いたとき，および編集するたびに，サーバはエディタのログに`<ファイル名>: <N> lines`を書く．ファイル名はURIの最後の`/`より後ろである．
- 行数は改行で区切られた行の数である．空の文書は0行で，末尾の改行のあとに行は数えない．

### 使用例

```text
-- examples/sample.calc を開いたとき，出力パネル「Calc Language Server」に出る行
sample.calc: 5 lines
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Summary` | `countLines :: Text -> Int` |
| `Lsp.Server` | `serverDefinition`の`options`，`didOpen`と`didChange`のハンドラ |

### 書くときに考えること

- 行数の数え方で，結果が分かれそうな入力は何か．空の文書，改行のない1行，末尾の改行，空行を並べて，単純なものから順にする．
- どの項目を単体テスト(`countLines`だけを呼ぶ)で確かめ，どの項目を統合テスト(LSPのメッセージを送る)で確かめるか．統合テストは，開いたときと変えたときの代表的な例があればよい．

## 0-4 設計文書

1. [設計文書の書き方](../../../../docs/design.md)を読む．
2. `design/`の4つのファイルに，最初の版を書く．各ファイルのコメントが，何を描くかを示している．
   - `c4-context.md`: 利用者，VS Code，Calc拡張機能，Calcサーバ，`.calc`ファイルの間で，何がやり取りされるか．
   - `c4-component.md`: `Main`，`Lsp.Server`，`Calc.Summary`のimportの向き．どれが純粋で，どれがIOを扱うか．
   - `code-flow.md`: 文書のURIからログの文字列ができるまでに，どの型をどの関数が変えるか．
   - `lsp-sequence.md`: `initialize`から，開く・変えるまでのメッセージの順序．どれがリクエストで，どれが通知か．
3. `mise run lint:mermaid`で，図の構文を確かめる．

## 0-5 テストファーストの実装

テストリストの項目を1つずつ，Red → Green → Refactorで実装する．

### `countLines`

- テストは`test/unit/Calc/SummarySpec.hs`に書く．モジュール名は`Calc.SummarySpec`で，`spec :: Spec`を公開する．
- `.cabal`ファイルの`test-suite unit`に，`other-modules: Calc.SummarySpec`を足す．
- 最初は定数を返すだけの仮実装から始め，次のテストで本物の実装へ進める．
- `Data.Text`の`T.lines`と`T.splitOn`は，末尾の改行の扱いが違う．

### ログを書くハンドラ

- まず`test/integration/TestServer.hs`をノートの「サーバをテストの中で動かす」を見て作り，`test/integration/LogMessageSpec.hs`にテストを書く．どちらも`test-suite integration`の`other-modules`に足す．
- 最初のテストは，サーバがログを送らないので，lsp-testが待ちきれずに`Timed out waiting to receive a message from the server.`で失敗する．このとき表示される`initialize`のレスポンスの`capabilities`に，`textDocumentSync`があるかを見る．
- `options`に`optTextDocumentSync`と`optServerInfo`を設定する．`TextDocumentSyncOptions`をレコード構文で作るなら，`DisambiguateRecordFields`を有効にする．
- `didOpen`と`didChange`のハンドラから，同じ関数(URIを受け取ってログを書く関数)を呼ぶ．文書の内容はVFSから取り出す．
- テストを実行するコマンドは0-1と同じである．

### エディタで確かめる

`mise run use-server calc-lsp-iter0-exercise`を実行し，「Calc: Restart Server」でサーバを起動し直す．
`examples/sample.calc`を開いて編集し，出力パネルに行数が出ることを確かめる．

## 0-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．自分になかった項目，模範解答になかった項目はどれか．
2. 末尾の改行のテストは，どの実装を失敗させるために必要だったか．
3. `countLines`の細かい場合分けを単体テストで確かめ，統合テストでは代表的な例だけにしたのはなぜか．統合テストだけで確かめると，何が困るか．
4. `optTextDocumentSync`を設定しないと，統合テストはどう失敗したか．それはLSPのどの決まりによるか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で，`c4-component.md`とimportを照合する．

## 0-7 発展課題

文書を閉じたら，エディタのログに`<ファイル名>: closed`を書く．
`textDocument/didClose`の通知を受け取ったときには，VFSから文書がなくなっている．
テストリスト，設計文書，実装の順に進める．
