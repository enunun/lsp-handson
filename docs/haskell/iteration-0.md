# Iteration 0のノート：LSPの仕組みと`lsp`ライブラリの骨組み

Iteration 0では，エディタとつながり，開いた文書の行数をエディタのログに書くサーバを作る．
このノートでは，LSPの仕組み，`lsp`ライブラリでサーバを組み立てる方法，`Text`と`OverloadedStrings`，lensによるメッセージの読み出し，cabal・hspec・lsp-testの使い方を説明する．

## LSPとは

LSP(Language Server Protocol)は，エディタ(クライアント)と言語サーバ(サーバ)の間の約束事である．
エディタは「文書を開いた」「この位置のホバーを見せて」といったメッセージをサーバへ送り，サーバは診断やホバーの内容を返す．
言語ごとの知識はサーバに集まるので，1つのサーバをVS Code，Neovim，Emacsなど多くのエディタで使える．

このコースでは，VS CodeのCalc拡張機能がクライアントとしてCalcサーバ(`calc-lsp`)を起動し，2つのプロセスが標準入出力でメッセージを交わす．

## JSON-RPCのメッセージ

メッセージはJSON-RPC 2.0の形をしたJSONで，前に`Content-Length`ヘッダが付く．
ヘッダと本文の間は空行(`\r\n\r\n`)で区切り，`Content-Length`は本文のバイト数である．
エディタが文書を開いたときに送るメッセージは，次のバイト列になる．

```text
Content-Length: 186

{"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {"uri": "file:///tmp/sample.calc", "languageId": "calc", "version": 1, "text": "let a = 1\nlet b = 2\n"}}}
```

Iteration 0のサーバは，これに次のメッセージで応える．

```text
Content-Length: 99

{"jsonrpc":"2.0","method":"window/logMessage","params":{"message":"sample.calc: 2 lines","type":3}}
```

メッセージには3種類ある．

| 種類 | 見分け方 | 例 |
| --- | --- | --- |
| リクエスト | `id`と`method`を持つ．相手は同じ`id`のレスポンスを1つ返す | `initialize`，`textDocument/hover` |
| レスポンス | `id`と，`result`または`error`を持つ | `initialize`への応答 |
| 通知 | `method`を持ち，`id`を持たない．応答はない | `initialized`，`textDocument/didOpen`，`window/logMessage` |

リクエストと通知は，クライアントとサーバのどちらからでも送れる．
`window/logMessage`はサーバからクライアントへの通知で，VS Codeは出力パネルにその文字列を表示する．

`lsp`ライブラリがヘッダの読み書きとJSONの変換を受け持つので，サーバのコードはHaskellの型で書いたメッセージだけを扱う．

## 初期化とcapabilities

接続の最初に，次の順でメッセージを交わす．

1. クライアントが`initialize`リクエストを送る．自分にできること(クライアントのcapabilities)を伝える．
2. サーバがレスポンスを返す．自分にできること(サーバのcapabilities)と，サーバの名前(`serverInfo`)を伝える．
3. クライアントが`initialized`通知を送る．ここから通常のやり取りが始まる．

クライアントは，サーバのcapabilitiesに書かれた機能だけを使う．
特に`textDocumentSync`がないと，エディタは文書を開いたときや変えたときに何も送ってこない．
`textDocumentSync`には，次のことを書く．

| フィールド | 意味 |
| --- | --- |
| `openClose` | `didOpen`と`didClose`を送ってほしいか |
| `change` | `didChange`で何を送ってほしいか．`Full`は毎回全文，`Incremental`は変わった部分だけ |

Iteration 0では`openClose = true`と`change = Full`を宣言する．

## `lsp`ライブラリの骨組み

### `ServerDefinition`

サーバの定義は`ServerDefinition`というレコードにまとめる．

```haskell
serverDefinition :: ServerDefinition ()
serverDefinition =
  ServerDefinition
    { defaultConfig = ()
    , configSection = "calc"
    , parseConfig = \_ _ -> Right ()
    , onConfigChange = const (pure ())
    , doInitialize = \env _request -> pure (Right env)
    , staticHandlers = const handlers
    , interpretHandler = \env -> Iso (runLspT env) liftIO
    , options = defaultOptions
    }
```

| フィールド | 意味 |
| --- | --- |
| `defaultConfig`，`configSection`，`parseConfig`，`onConfigChange` | エディタの設定を受け取る仕組み．Calcサーバは設定を持たないので，型は`()`である |
| `doInitialize` | `initialize`を受け取ったときの処理．ここでは何もせず，環境`env`をそのまま渡す |
| `staticHandlers` | メッセージごとの処理(ハンドラ)の一覧 |
| `interpretHandler` | ハンドラを動かすモナドを`IO`へ変換する方法．`LspM`を使う限り，この形のままでよい |
| `options` | capabilitiesの一部やサーバの名前など．`defaultOptions`を元に，必要なフィールドだけを変える |

`run = void (runServer serverDefinition)`で，標準入出力を使うサーバが動き出す．
`runServer`は終了コードを`Int`で返すので，`void`で捨てて`IO ()`にする．

`options`は，レコード更新の構文で一部のフィールドだけを変える．

```haskell
defaultOptions
  { optTextDocumentSync = Just syncOptions
  , optServerInfo = Just (ServerInfo "calc-lsp" Nothing)
  }
```

### ハンドラ

ハンドラは`notificationHandler`(通知用)で作り，`mconcat`で1つにまとめる．

```haskell
handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_notification -> pure ()
    , notificationHandler SMethod_TextDocumentDidOpen $ \notification -> ...
    ]
```

- `SMethod_Initialized`，`SMethod_TextDocumentDidOpen`はメソッドを表す値である．名前は，LSPのメソッド名(`textDocument/didOpen`)から`/`を除き，先頭を大文字にして`SMethod_`を付けたものである．
- 受け取る`notification`の型はメソッドで決まる．`SMethod_TextDocumentDidOpen`なら，`params`に`DidOpenTextDocumentParams`を持つ通知である．
- `Handlers`は`Monoid`なので，`mconcat`でまとめられる．
- ハンドラは`LspM ()`の中で動く．`LspM`は，サーバの状態を読んだりクライアントへメッセージを送ったりできる`IO`のようなモナドである．`()`は設定の型である．

### クライアントへの通知

`sendNotification`は，メソッドとパラメータを受け取ってクライアントへ通知を送る．

```haskell
sendNotification SMethod_WindowLogMessage $
  LogMessageParams MessageType_Info "sample.calc: 2 lines"
```

`MessageType_Info`はログの重さで，ほかに`MessageType_Error`，`MessageType_Warning`，`MessageType_Log`がある．

### 仮想ファイルシステム(VFS)

`lsp`ライブラリは，`didOpen`と`didChange`を受け取るたびに，開いている文書の最新の内容を仮想ファイルシステム(VFS)に保存する．
ハンドラは，そのあとに呼ばれる．
文書の内容はURIで取り出す．

```haskell
file <- getVirtualFile (toNormalizedUri uri)   -- Maybe VirtualFile
case file of
  Nothing -> pure ()                           -- 開いていない文書
  Just contents -> ... (virtualFileText contents) ...   -- Text
```

`toNormalizedUri`は，URIを比較に使える正規の形(`NormalizedUri`)に変える．
`virtualFileText`は`Language.LSP.VFS`にある．

## `Text`と`OverloadedStrings`

`lsp`ライブラリは，文字列に`String`ではなく`Data.Text`の`Text`を使う．
`Text`の関数は名前が`Prelude`と重なるので，修飾名で使う．

```haskell
import Data.Text (Text)
import Data.Text qualified as T
```

`import 〜 qualified as T`は，`GHC2021`で使える書き方である．
REPLで試すと，次のようになる．

```text
ghci> :set -XOverloadedStrings
ghci> import Data.Text qualified as T
ghci> T.lines "let a = 1\nlet b = 2\n"
["let a = 1","let b = 2"]
ghci> T.lines ""
[]
ghci> T.splitOn "\n" "let a = 1\n"
["let a = 1",""]
ghci> T.takeWhileEnd (/= '/') "file:///workspaces/sample.calc"
"sample.calc"
ghci> T.pack (show (42 :: Int)) <> " lines"
"42 lines"
ghci> :type T.lines
T.lines :: Text -> [Text]
```

- `T.lines`は改行で区切る．末尾の改行のあとに空の行を作らない．
- `T.splitOn`は区切り文字で分ける．末尾の区切りのあとにも空の要素を作る．
- `T.pack`は`String`を`Text`に変える．`show`の結果は`String`なので，`T.pack`を通す．
- `<>`で`Text`をつなぐ．

文字列リテラル`"…"`の型は，ふつうは`String`である．
ファイルの先頭で`OverloadedStrings`を有効にすると，文字列リテラルを`Text`としても使える．

```haskell
{-# LANGUAGE OverloadedStrings #-}
```

有効にしないで`Text`の場所に文字列リテラルを書くと，次のエラーになる．

```text
src/Calc/Summary.hs:9:64: error: [GHC-83865]
    * Couldn't match type `[Char]' with `Text'
      Expected: Text
        Actual: String
    * In the first argument of `T.splitOn', namely `"\n"'
      In the first argument of `length', namely `(T.splitOn "\n" text)'
      In the expression: length (T.splitOn "\n" text)
  |
9 | countLines text = if T.null text then 0 else length (T.splitOn "\n" text)
  |                                                                ^^^^
```

## lensでメッセージを読む

LSPのメッセージは，レコードが何段にも入れ子になっている．
`didOpen`の通知から文書のURIを取り出すには，「通知の`params`の`textDocument`の`uri`」とたどる．
`lsp-types`は，フィールドごとにlensを用意している．
lensを`.`でつなぎ，`^.`で値を読む．

```haskell
import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L

notification ^. L.params . L.textDocument . L.uri
```

REPLで，`TextDocumentItem`と`DidOpenTextDocumentParams`を作って試す．

```text
ghci> import Control.Lens ((^.))
ghci> import Language.LSP.Protocol.Lens qualified as L
ghci> import Language.LSP.Protocol.Types
ghci> item = TextDocumentItem (Uri "file:///workspaces/sample.calc") "calc" 1 "let a = 1\n"
ghci> item ^. L.uri
Uri {getUri = "file:///workspaces/sample.calc"}
ghci> item ^. L.text
"let a = 1\n"
ghci> params = DidOpenTextDocumentParams item
ghci> params ^. L.textDocument . L.uri
Uri {getUri = "file:///workspaces/sample.calc"}
```

`Uri`は`Text`を包んだ型で，`getUri`で中の`Text`を取り出せる．

### レコード構文で値を作る

`lsp-types`のレコードは，フィールド名(`_change`，`_save`など)を他の型と共有している．
そのため，`TextDocumentSyncOptions {_change = …}`のようにレコード構文で値を作ると，どの型のフィールドか分からないというエラーになる．
値を作るファイルの先頭で`DisambiguateRecordFields`を有効にすると，コンストラクタ名からフィールドを決められるようになる．

```haskell
{-# LANGUAGE DisambiguateRecordFields #-}

syncOptions :: TextDocumentSyncOptions
syncOptions =
  TextDocumentSyncOptions
    { _openClose = Just True
    , _change = Just TextDocumentSyncKind_Full
    , _willSave = Nothing
    , _willSaveWaitUntil = Nothing
    , _save = Nothing
    }
```

## cabalのパッケージ

各Iterationのパッケージは，`.cabal`ファイルに4つのコンポーネントを持つ．

| コンポーネント | 置き場所 | 中身 |
| --- | --- | --- |
| `library` | `src/` | `Calc.*`と`Lsp.*`のモジュール．`exposed-modules`に並べる |
| `executable calc-lsp` | `app/Main.hs` | `main = Lsp.Server.run` |
| `test-suite unit` | `test/unit/` | 単体テスト．テストのモジュールは`other-modules`に並べる |
| `test-suite integration` | `test/integration/` | 統合テスト．テストのモジュールは`other-modules`に並べる |

`common shared`は，各コンポーネントが`import: shared`で取り込む共通の設定である．
新しいモジュールやテストのファイルを作ったら，`.cabal`ファイルの該当する一覧に名前を足す．
足し忘れると，ビルドの警告やリンクのエラーになる．

パッケージは，ルートの`cabal.project`の`packages`に並べるとビルドの対象になる．

| すること | コマンド |
| --- | --- |
| ビルドする | `cabal build calc-lsp-iter0-exercise` |
| テストを実行する | `cabal test calc-lsp-iter0-exercise` |
| ライブラリを読み込んだREPLを起動する | `cabal repl calc-lsp-iter0-exercise` |

REPLでは`:reload`(`:r`)でソースを読み直し，`:type`(`:t`)で式の型を見る．
`:quit`(`:q`)で終わる．

## hspecとhspec-discover

単体テストと統合テストは，hspecで書く．
`test/unit/Spec.hs`と`test/integration/Spec.hs`は，次の1行だけを持つ．

```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover #-}
```

hspec-discoverは，同じディレクトリの下の`〜Spec.hs`を探し，それぞれの`spec`をまとめて実行する．
`test/unit/Calc/SummarySpec.hs`なら，モジュール名は`Calc.SummarySpec`である．
書き方と実行の方法は[テスト駆動開発とテストリスト](../tdd.md)にある．

## lsp-testで統合テストを書く

lsp-testは，テストの中でエディタの代わりをするライブラリである．
`Session`というモナドの中で，文書を開き，サーバからのメッセージを待つ．

| 関数 | すること |
| --- | --- |
| `createDoc "sample.calc" "calc" "let a = 1\n"` | 中身を指定して文書を開く(`didOpen`を送る)．`TextDocumentIdentifier`を返す |
| `changeDoc document [変更]` | 文書を変える(`didChange`を送る) |
| `message SMethod_WindowLogMessage` | 指定したメソッドの通知を受け取るまで待ち，その通知を返す |

文書の全文を置き換える変更は，次のように書く．

```haskell
TextDocumentContentChangeEvent (InR (TextDocumentContentChangeWholeDocument "let a = 1\nlet b = 2\n"))
```

### サーバをテストの中で動かす

統合テストでは，サーバを別のプロセスとして起動する代わりに，テストと同じプロセスの別のスレッドで動かす．
サーバとテストを2本のパイプでつなぐ．

```haskell
-- | Runs the Calc server in the test process and talks to it through lsp-test.
module TestServer (runCalcSession) where

import Control.Concurrent (forkIO, killThread)
import Control.Exception (bracket)
import Control.Monad (void)
import Language.LSP.Server (runServerWithHandles)
import Language.LSP.Test (
  Session,
  SessionConfig (ignoreLogNotifications, messageTimeout),
  defaultConfig,
  fullLatestClientCaps,
  runSessionWithHandles,
 )
import Lsp.Server (serverDefinition)
import System.Process (createPipe)

-- | Starts a server connected by two pipes, runs the session as its client, and stops the server.
runCalcSession :: Session a -> IO a
runCalcSession session = do
  (serverIn, clientOut) <- createPipe
  (clientIn, serverOut) <- createPipe
  bracket
    (forkIO (void (runServerWithHandles mempty mempty serverIn serverOut serverDefinition)))
    killThread
    (const (runSessionWithHandles clientOut clientIn config fullLatestClientCaps "." session))
 where
  -- The tests read window/logMessage, which lsp-test drops by default.
  config = defaultConfig {ignoreLogNotifications = False, messageTimeout = 5}
```

- `createPipe`は，読む端と書く端の組を返す．テストが書いた内容をサーバが読み，サーバが書いた内容をテストが読む．
- `runServerWithHandles`は，指定した入出力でサーバを動かす．2つの`mempty`は，サーバ自身のログを捨てる指定である．
- `bracket`は，サーバのスレッドを起動し，セッションが終わったら(失敗しても)`killThread`で止める．
- `fullLatestClientCaps`は，LSPのすべての機能を持つクライアントとしてふるまう指定である．
- lsp-testの`defaultConfig`は，サーバからの`window/logMessage`を読み捨てる．ログを確かめるテストでは，`ignoreLogNotifications = False`を指定する．
- `messageTimeout`は，メッセージを待つ秒数である．既定は60秒なので，失敗がすぐ分かるように5秒にする．

このモジュールを使うテストは，次の形になる．

```haskell
logged <- runCalcSession $ do
  _ <- createDoc "sample.calc" "calc" "let a = 1\n"
  message SMethod_WindowLogMessage
logged ^. L.params . L.message `shouldBe` "sample.calc: 1 lines"
```

統合テストのスイートは，`.cabal`ファイルで`ghc-options: -threaded`を指定してビルドする．

## エディタで動かす

1. `mise run client`で，Calc拡張機能をVS Codeに入れる(最初の1回だけ)．
2. `mise run use-server calc-lsp-iter0-exercise`で，エディタが起動するサーバを自分のパッケージにする．
3. `.calc`ファイルを開く．サーバを作り直したら，コマンドパレットの「Calc: Restart Server」で起動し直す．
4. 出力パネルで「Calc Language Server」を選ぶと，サーバのログが見える．
5. 設定`calc.trace.server`を`verbose`にすると，同じパネルにJSON-RPCのメッセージがすべて出る．

## REPLの課題

`cabal repl calc-lsp-iter0-exercise`で，次を試す．

1. `T.lines`に，`"a\n\nb"`，`"\n"`，`"a\r\nb"`を渡し，結果の要素数を予想してから確かめる．
2. `T.takeWhileEnd (/= '/')`で，`"file:///workspaces/notes/sample.calc"`からファイル名を取り出す．
3. `TextDocumentItem`を作り，`^.`で`L.languageId`と`L.version`を読む．
