# Iteration 7: アウトラインと差分同期

このIterationでは，アウトラインを表示し，エディタから変更部分だけを受け取るようにする．
あわせて，文書の解析結果を1回だけ作ってキャッシュし，すべての機能で使い回すようにリファクタリングする．
LSPの`DocumentSymbol`，文書の同期の2つの方式とVFS，STMの`TVar`による共有状態，`liftIO`を学ぶ．

## 7-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-7/exercise`の行を足す．
2. ビルドし，Iteration 6から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにする．`examples/sample.calc`を開いても，アウトラインには何も出ない．設定`calc.trace.server`を`verbose`にして1文字入力すると，`didChange`が文書の全文を運んでいることが分かる．

## 7-2 文法と概念

[Iteration 7のノート](../../../../docs/haskell/iteration-7.md)を読み，最後の「REPLの課題」を解く．

## 7-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- アウトラインに，文書の定義を上から順に並べる．各項目には値(計算できなければその理由)を添える．
- エディタからは変更部分だけを受け取る(差分同期)．
- 文書の解析結果は，文書が開かれたときと変わったときに1回だけ作り，診断，ホバー，定義，参照，補完，リネーム，アウトラインで使い回す．
- これまでのIterationの機能は，そのまま動く．

### 使用例

[ロードマップ](../../../../docs/ROADMAP.md)の冒頭の「完成したプログラムの使用例」がすべて動く．

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Analysis` | `data Analysis = Analysis {...}`(行，問題，文，出現，評価結果)，`analyze :: Text -> Analysis` |
| `Lsp.Convert` | `valueText :: Either EvalError Integer -> Text`(`hoverText`もこれを使う)，`toDocumentSymbol :: Statement -> Either EvalError Integer -> DocumentSymbol` |
| `Lsp.State` | `type Cache = TVar (Map NormalizedUri Analysis)`，`newCache :: IO Cache`，`updateAnalysis :: Cache -> NormalizedUri -> Text -> IO Analysis`，`lookupAnalysis :: Cache -> NormalizedUri -> IO (Maybe Analysis)` |
| `Lsp.Server` | `serverDefinition`と`handlers`がキャッシュを引数に受け取る．`textDocument/documentSymbol`のハンドラを足し，同期の方式を差分に変え，各ハンドラがキャッシュを使うよう書き直す |

### 書くときに考えること

- `analyze`の結果は，これまでの関数(`parseProgram`，`checkProgram`，`occurrences`，`evalProgram`)の結果と同じであるべきである．それをどう確かめるか．
- キャッシュについて，読む前，書いたあと，同じ文書を書き換えたあと，別の文書を書いたあとの4つを考える．
- 差分同期は，capabilitiesと，差分を送ったあとの振る舞いの2つで確かめる．
- このIterationは大きなリファクタリングを含む．引き継いだテストのうち，どれを安全網として変えずに使い，どれを直す必要があるか．

## 7-4 設計文書

- `c4-context.md`: アウトラインのやり取りを足す．エディタが送る文書の中身も変わる．
- `c4-component.md`: 2つのモジュールを足し，依存を整理する．`Lsp.Server`が直接使う`Calc.*`のモジュールはどれになるか．状態を持つモジュールはどれか．
- `code-flow.md`: `analyze`を起点に描き直す．文書の変更から解析結果がキャッシュに入るまでの図と，キャッシュから各リクエストの結果を作る図に分ける．
- `lsp-sequence.md`: キャッシュを参加者として足し，`didChange`で更新し，リクエストで読む流れにする．`documentSymbol`を足す．

## 7-5 テストファーストの実装

`Calc.Analysis`と`Lsp.State`を`exposed-modules`に，テストのモジュールを`other-modules`に足す．
`library`の`build-depends`に`stm`を足す．

### `analyze`

- これまでの関数を1回ずつ呼び，結果をレコードにまとめる．
- テストでは，これまでの関数の結果と比べるとよい．

### `Lsp.State`

- `newTVarIO`，`atomically`，`modifyTVar'`，`readTVarIO`を使う．
- テストは`IO`の中で書く．hspecの`it`には`IO ()`をそのまま渡せる．

### `valueText`と`toDocumentSymbol`

- `hoverText`のテストを変えずに，`hoverText`が`valueText`を使う形に書き換える(Refactor)．

### サーバの書き換え

1. `serverDefinition`と`handlers`がキャッシュを受け取るようにする．`run`で`newCache`を呼ぶ．
2. コンパイルエラーになる`TestServer.hs`を直す．統合テストの期待値は変えない．
3. `didOpen`と`didChange`のハンドラで，解析結果をキャッシュに入れ，そこからログと診断を送る．
4. 各リクエストのハンドラを，キャッシュの解析結果を使う形に1つずつ書き換え，そのたびに統合テストを実行する．
5. 同期の方式を`TextDocumentSyncKind_Incremental`に変える．
6. `textDocument/documentSymbol`のハンドラを足す．

統合テストは，`test/integration/DocumentSymbolSpec.hs`と`test/integration/SyncSpec.hs`に書く．
lsp-testの`initializeResponse`で`initialize`の応答を，`getDocumentSymbols`でアウトラインを受け取れる．
差分は`TextDocumentContentChangeEvent (InL (TextDocumentContentChangePartial range Nothing text))`で送る．

### エディタで確かめる

[ロードマップ](../../../../docs/ROADMAP.md)の冒頭の使用例を，表の上から順に試す．
`calc.trace.server`を`verbose`にして1文字入力し，`didChange`が変わった部分だけを運ぶことを確かめる．

## 7-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. 同期の方式を差分に変えたとき，ハンドラのコードを変えずに済んだのはなぜか．
3. キャッシュを使う形に書き換える間，安全網になったテストはどれか．書き換えた中で，期待値を変えたテストはあったか．
4. `Analysis`を純粋な値にし，キャッシュ(`TVar`)を`Lsp.State`に分けたことで，テストはどう書きやすくなったか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 7-7 発展課題

文書が閉じられたら(`textDocument/didClose`)，その解析結果をキャッシュから除く．
`Lsp.State`に`removeAnalysis :: Cache -> NormalizedUri -> IO ()`を足し，閉じたあとにホバーを求めると何も返らないことを統合テストで確かめる．
