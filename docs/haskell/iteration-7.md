# Iteration 7のノート：アウトライン，差分同期，共有状態

Iteration 7では，アウトラインを表示し，エディタから変更部分だけを受け取り，文書の解析結果を1回だけ作って使い回す．
このノートでは，LSPの`DocumentSymbol`，文書の同期の2つの方式とVFS，STMの`TVar`による共有状態，`IO`の処理をハンドラから呼ぶ`liftIO`を説明する．

## アウトライン(`textDocument/documentSymbol`)

エディタのアウトライン(VS Codeでは「アウトライン」ビューやパンくずリスト)は，`textDocument/documentSymbol`の結果を表示する．
パラメータは文書だけである．

結果の型は`[SymbolInformation] |? ([DocumentSymbol] |? Null)`で，`DocumentSymbol`の一覧は`InR (InL symbols)`で返す．

| フィールド | 意味 |
| --- | --- |
| `_name` | 表示する名前 |
| `_detail` | 名前の横に出る補足 |
| `_kind` | 種類(`SymbolKind_Variable`など)．エディタはアイコンを変える |
| `_range` | その定義全体の範囲 |
| `_selectionRange` | 選んだときに選択する範囲(名前の範囲) |
| `_children` | 入れ子になった定義 |

Calcの文は名前の`Span`しか持たないので，`_range`と`_selectionRange`のどちらにも名前の範囲を入れる．

lsp-testでは，`getDocumentSymbols document`で結果を`Either [SymbolInformation] [DocumentSymbol]`として受け取る．

## 文書の同期：全文と差分

`initialize`の応答の`textDocumentSync`で，エディタが`didChange`で何を送るかを決める．

| 方式 | `didChange`が運ぶもの |
| --- | --- |
| `TextDocumentSyncKind_Full` | 毎回，文書の全文 |
| `TextDocumentSyncKind_Incremental` | 変わった範囲と，そこに入る文字列の一覧 |

差分の1つは，次の形をしている．

```haskell
TextDocumentContentChangeEvent
  (InL (TextDocumentContentChangePartial (Range (Position 1 12) (Position 1 13)) Nothing "a"))
```

1行目の12列から13列までを`a`に置き換える，という意味である．
大きな文書を1文字ずつ編集するとき，差分なら送る量が少なくて済む．

差分を受け取ったサーバは，自分の持つ文書に差分を適用して最新の全文を作る必要がある．
`lsp`ライブラリのVFSがこれを受け持つ．
`didChange`のハンドラが呼ばれる時点で，VFSの文書には差分が適用済みなので，`virtualFileText`は常に最新の全文を返す．
そのため，同期の方式を`Incremental`に変えても，ハンドラのコードは変わらない．

## 共有状態：STMと`TVar`

ハンドラは1回ごとに独立した関数である．
`didChange`のハンドラで作った解析結果を，あとのホバーのハンドラで使うには，両方から読み書きできる変数が必要になる．

Haskellの値は変更できないので，変更できる箱を別に用意する．
`stm`パッケージの`TVar`は，STM(Software Transactional Memory)で読み書きする箱である．

```text
ghci> import Control.Concurrent.STM
ghci> counter <- newTVarIO (0 :: Int)
ghci> readTVarIO counter
0
ghci> atomically (modifyTVar' counter (+ 1))
ghci> readTVarIO counter
1
ghci> atomically (do { n <- readTVar counter; writeTVar counter (n * 10) })
ghci> readTVarIO counter
10
```

| 関数 | すること |
| --- | --- |
| `newTVarIO x` | 中身が`x`の新しい`TVar`を作る |
| `readTVarIO v` | 中身を読む |
| `atomically stm` | STMの処理をまとめて実行する．途中の状態はほかのスレッドから見えない |
| `readTVar v`，`writeTVar v x`，`modifyTVar' v f` | `atomically`の中で読む，書く，関数で変える |

```text
ghci> :type atomically
atomically :: STM a -> IO a
ghci> :type newTVarIO
newTVarIO :: a -> IO (TVar a)
```

`atomically`の中の処理は，ほかのスレッドの処理と混ざらない．
「読んでから書く」処理を1つの`atomically`にまとめれば，その間にほかのスレッドが書き換えることはない．

Calcサーバのキャッシュは，文書のURIから解析結果への`Map`を入れた`TVar`である．

```haskell
type Cache = TVar (Map NormalizedUri Analysis)
```

キャッシュは`run`で1つ作り，`serverDefinition`と`handlers`に引数で渡す．
統合テストの`TestServer.hs`でも，キャッシュを作ってから`serverDefinition`に渡す．

## ハンドラから`IO`を呼ぶ(`liftIO`)

ハンドラは`LspM ()`の中で動くので，`IO`の処理(`readTVarIO`など)をそのまま書けない．
`liftIO`で`IO`の処理を`LspM ()`の処理に変える．

```text
ghci> :type liftIO
liftIO :: Control.Monad.IO.Class.MonadIO m => IO a -> m a
```

`MonadIO`は「`IO`の処理を中で実行できるモナド」の型クラスで，`LspM`はその1つである．

```haskell
analysisOf :: Cache -> Uri -> LspM () (Maybe Analysis)
analysisOf cache uri = liftIO (lookupAnalysis cache (toNormalizedUri uri))
```

## 解析を1回にまとめる

Iteration 6までは，ホバー，定義，参照，補完，リネームのハンドラが，それぞれ文書を構文解析していた．
Iteration 7では，文書が開かれたときと変わったときに1回だけ解析し，結果を`Analysis`にまとめる．

```text
ghci> analysis = analyze "let price = 1200\nlet total = price + fee\n"
ghci> anProblems analysis
[Problem {problemSpan = Span {spanLine = 1, spanStart = 20, spanEnd = 23}, problemMessage = "undefined variable 'fee'"}]
ghci> anValues analysis
fromList [("price",Right 1200),("total",Left (UndefinedVariable "fee"))]
```

`Analysis`は純粋な値で，`analyze`は純粋な関数である．
キャッシュ(`IO`)と解析(純粋)を分けておくと，解析はこれまでどおり単体テストで確かめられる．

## REPLの課題

`cabal repl calc-lsp-iter7-exercise`で，次を試す．

1. `newTVarIO`で空の`Map`を入れた`TVar`を作り，`atomically`と`modifyTVar'`で2つの組を加えてから，`readTVarIO`で読む．
2. `analyze`に，誤りを含む文書と含まない文書を渡し，`anProblems`と`anValues`を比べる．
3. `:type liftIO`と`:type readTVarIO`を見て，`liftIO (readTVarIO v)`の型を考える．
