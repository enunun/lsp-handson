# Iteration 0の解説：サーバを起動してエディタとつなぐ

演習の各段階について，模範解答と考え方を示す．

## 0-1 準備

`cabal.project`に`iterations/iteration-0/exercise`を足すと，`cabal build calc-lsp-iter0-exercise`でライブラリ，実行ファイル，2つのテストスイートがビルドされる．
テストのファイルはまだないので，`cabal test calc-lsp-iter0-exercise`は次の出力で通る(両方のスイートで同じ)．

```text
0 examples, 0 failures
```

演習の最初のサーバは`options = defaultOptions`のままなので，`initialize`のレスポンスに`textDocumentSync`がない．
そのため，VS Codeは文書を開いても`didOpen`を送らない．

## 0-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> T.lines "a\n\nb"
["a","","b"]
ghci> T.lines "\n"
[""]
ghci> T.lines "a\r\nb"
["a\r","b"]
```

- 空行も1つの要素になる．
- 改行だけの文字列は，空の行1つである．
- `T.lines`は`\n`だけで区切るので，`\r\n`の`\r`は前の行に残る．

## 0-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- 単体テストは`countLines`の場合分けを確かめる．空の文書(0行)，改行のない1行，複数行の順に単純なものから並べ，最後に境界(末尾の改行，空行)を置く．
- 統合テストは，LSPのメッセージから`countLines`に届き，結果がログとして返ることを確かめる．開いたときと変えたときの2つで，ハンドラがどちらにもあることを確かめられる．行数の場合分けは単体テストに任せる．

## 0-4 設計文書

4つの設計文書の最初の版を書いた．

| 文書 | 書いたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 利用者，VS Code(エディタとCalc拡張機能)，Calcサーバ，`.calc`ファイルと，「開いた・変わった文書」「ログ(行数)」のやり取り | サーバがファイルを直接読まず，エディタから届く文書の内容だけを扱うことを示すため |
| [c4-component.md](../design/c4-component.md) | `Main` → `Lsp.Server` → `Calc.Summary`の依存と，`lsp`ライブラリ | 行数の計算を純粋な`Calc.Summary`に置き，LSPに依存しない単体テストを書けるようにするため |
| [code-flow.md](../design/code-flow.md) | `Uri` → `Maybe VirtualFile` → `Text` → `Int` → ログの文字列の流れ | どこで失敗(VFSにない)がありうるか，どの関数が純粋かを示すため |
| [lsp-sequence.md](../design/lsp-sequence.md) | `initialize`(リクエスト)から`didOpen`，`didChange`と，それぞれへの`window/logMessage` | リクエストと通知の違い，`textDocumentSync = Full`の意味を示すため |

## 0-5 テストファーストの実装

### 1. 空の文書は0行

テストを書く．

```haskell
spec :: Spec
spec = describe "countLines" $ do
  it "counts no lines in an empty document" $
    countLines "" `shouldBe` 0
```

演習のスタブは`undefined`なので，テストは例外で失敗する．

```text
Calc.Summary
  countLines
    counts no lines in an empty document [x]

Failures:

  src/Calc/Summary.hs:9:14: 
  1) Calc.Summary.countLines counts no lines in an empty document
       uncaught exception: ErrorCall
       Prelude.undefined
       CallStack (from HasCallStack):
         undefined, called at src/Calc/Summary.hs:9:14 in calc-lsp-iter0-exercise-0.1.0-inplace:Calc.Summary
```

定数を返す仮実装で通す．

```haskell
countLines :: Text -> Int
countLines _ = 0
```

### 2. 改行のない1行は1行

```haskell
  it "counts one line without a newline" $
    countLines "let a = 1" `shouldBe` 1
```

```text
  1) Calc.Summary.countLines counts one line without a newline
       expected: 1
        but got: 0
```

空かどうかで分ける．まだ仮実装である．

```haskell
countLines :: Text -> Int
countLines text = if T.null text then 0 else 1
```

### 3. 改行で区切られた3行は3行

```haskell
  it "counts every line separated by newlines" $
    countLines "let a = 1\nlet b = 2\nlet c = 3" `shouldBe` 3
```

```text
  1) Calc.Summary.countLines counts every line separated by newlines
       expected: 3
        but got: 1
```

改行で分けて数える．`"\n"`を`Text`として書くので，ファイルの先頭に`OverloadedStrings`が必要である．

```haskell
countLines :: Text -> Int
countLines text = if T.null text then 0 else length (T.splitOn "\n" text)
```

### 4. 末尾の改行のあとに行は数えない

```haskell
  it "does not count a line after the final newline" $
    countLines "let a = 1\n" `shouldBe` 1
```

`T.splitOn`は末尾の改行のあとに空の要素を作るので，2行と数えてしまう．

```text
  1) Calc.Summary.countLines does not count a line after the final newline
       expected: 1
        but got: 2
```

`T.lines`に替える．`T.lines ""`は`[]`なので，空の文書の場合分けもいらなくなる(Refactor)．

```haskell
-- | The number of lines in a document. A newline at the end does not start a new line.
countLines :: Text -> Int
countLines = length . T.lines
```

`T.splitOn`を使わなくなったので，`OverloadedStrings`も外せる．

### 5. 空行も1行として数える

```haskell
  it "counts empty lines" $
    countLines "let a = 1\n\nlet b = 2\n" `shouldBe` 3
```

このテストは最初から通る．
空行の扱いは要求の一部なので，振る舞いを記録するテストとして残す．

### 6. 文書を開くと行数がログに出る

`TestServer.hs`をノートのとおりに作り，テストを書く．

```haskell
spec :: Spec
spec = describe "window/logMessage" $ do
  it "reports the number of lines when a document is opened" $ do
    logged <- runCalcSession $ do
      _ <- createDoc "sample.calc" "calc" "let a = 1\nlet b = 2\n"
      message SMethod_WindowLogMessage
    logged ^. L.params . L.message `shouldBe` "sample.calc: 2 lines"
```

サーバはログを送らないので，5秒待って失敗する．
最後に受け取ったメッセージは`initialize`のレスポンスで，その`capabilities`に`textDocumentSync`がない(長い一覧は省いてある)．

```text
  1) LogMessage.window/logMessage reports the number of lines when a document is opened
       uncaught exception: SessionException
       Timed out waiting to receive a message from the server.
       Last message received:
       {
           "id": 0,
           "jsonrpc": "2.0",
           "result": {
               "capabilities": {
                   "positionEncoding": "utf-16",
                   "semanticTokensProvider": {
                       ...
                   },
                   "workspace": {
                       "fileOperations": {}
                   }
               }
           }
       }
```

同期の方式とサーバの名前を宣言し，`didOpen`のハンドラを書く．

```haskell
    , options =
        defaultOptions
          { optTextDocumentSync = Just syncOptions
          , optServerInfo = Just (ServerInfo "calc-lsp" Nothing)
          }
```

```haskell
syncOptions :: TextDocumentSyncOptions
syncOptions =
  TextDocumentSyncOptions
    { _openClose = Just True
    , _change = Just TextDocumentSyncKind_Full
    , _willSave = Nothing
    , _willSaveWaitUntil = Nothing
    , _save = Nothing
    }

handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_notification -> pure ()
    , notificationHandler SMethod_TextDocumentDidOpen $ \notification ->
        logSummary (notification ^. L.params . L.textDocument . L.uri)
    ]

-- | Writes "<file name>: <n> lines" to the editor's log.
logSummary :: Uri -> LspM () ()
logSummary uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents ->
      sendNotification SMethod_WindowLogMessage $
        LogMessageParams MessageType_Info (summary uri (virtualFileText contents))

summary :: Uri -> Text -> Text
summary uri text =
  fileName uri <> ": " <> T.pack (show (countLines text)) <> " lines"

fileName :: Uri -> Text
fileName uri = T.takeWhileEnd (/= '/') (getUri uri)
```

`syncOptions`をレコード構文で作るので，`Lsp/Server.hs`の先頭で`DisambiguateRecordFields`を有効にする．
ハンドラは文書の内容を通知から読まず，VFSから取り出す．
`didChange`でも同じ取り出し方で最新の内容が得られるからである．

### 7. 文書を変えると行数がもう一度ログに出る

```haskell
  it "reports the number of lines again when the document changes" $ do
    logged <- runCalcSession $ do
      document <- createDoc "sample.calc" "calc" "let a = 1\n"
      _ <- message SMethod_WindowLogMessage
      changeDoc document [wholeDocument "let a = 1\nlet b = 2\nlet c = 3\n"]
      message SMethod_WindowLogMessage
    logged ^. L.params . L.message `shouldBe` "sample.calc: 3 lines"
 where
  wholeDocument text = TextDocumentContentChangeEvent (InR (TextDocumentContentChangeWholeDocument text))
```

`didChange`のハンドラがないので，2つ目のログを待って失敗する．
`didOpen`と同じ`logSummary`を呼ぶハンドラを足す．

```haskell
    , notificationHandler SMethod_TextDocumentDidChange $ \notification ->
        logSummary (notification ^. L.params . L.textDocument . L.uri)
```

完成したコードは[src/Lsp/Server.hs](../src/Lsp/Server.hs)と[src/Calc/Summary.hs](../src/Calc/Summary.hs)にある．

## 0-6 振り返り

1. 模範解答の単体テストは5項目，統合テストは2項目である．空行の項目は，最初から通るが要求を記録するために残している．
2. 末尾の改行のテストは，`T.splitOn`で数える実装を失敗させる．このテストがないと，`"let a = 1\n"`を2行と数える誤りが残る．
3. 統合テストはサーバの起動とメッセージのやり取りを含むので，遅く，失敗したときに原因の場所が分かりにくい．行数の場合分けを統合テストで確かめると，境界の1つが失敗しただけでもタイムアウトとして現れる．純粋な`countLines`の単体テストなら，入力と期待値の違いがすぐ分かる．
4. `optTextDocumentSync`がないと，サーバのcapabilitiesに`textDocumentSync`がなく，クライアントは`didOpen`を送らない．LSPでは，クライアントはサーバが宣言した機能だけを使うからである．統合テストはログを待ってタイムアウトした．
5. 実装の途中で，ファイル名を取り出す`fileName`と，ログの文字列を作る`summary`を`Lsp.Server`の中の関数として加えた．どちらもURIを扱うので`Calc.*`には置かない．`code-flow.md`の矢印のラベルにこの2つの名前を書いた．

## 0-7 発展課題

テストリストに「文書を閉じると，ログに「sample.calc: closed」が出る」を足す．
lsp-testでは`closeDoc document`で`didClose`を送れる．

`didClose`のハンドラが呼ばれた時点で，`getVirtualFile`は`Nothing`を返す．
ログにはURIだけを使い，VFSは読まない．

```haskell
    , notificationHandler SMethod_TextDocumentDidClose $ \notification -> do
        let uri = notification ^. L.params . L.textDocument . L.uri
        sendNotification SMethod_WindowLogMessage $
          LogMessageParams MessageType_Info (fileName uri <> ": closed")
```

`lsp-sequence.md`には，`didClose`と，それへの`window/logMessage`を足す．
