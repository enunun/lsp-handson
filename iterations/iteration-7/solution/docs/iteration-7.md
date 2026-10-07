# Iteration 7の解説：アウトラインと差分同期

演習の各段階について，模範解答と考え方を示す．

## 7-1 準備

引き継いだテストは，単体テストが89個，統合テストが18個である．
Iteration 6のサーバは`documentSymbolProvider`を宣言せず，同期の方式は全文(`Full`)である．

## 7-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> v <- newTVarIO (Map.empty :: Map.Map Text Int)
ghci> atomically (modifyTVar' v (Map.insert "a" 1) >> modifyTVar' v (Map.insert "b" 2))
ghci> readTVarIO v
fromList [("a",1),("b",2)]
ghci> anProblems (analyze "let a = 1\n")
[]
ghci> anValues (analyze "let a = 1\n")
fromList [("a",Right 1)]
ghci> :type readTVarIO
readTVarIO :: TVar a -> IO a
```

- 2つの`modifyTVar'`を`>>`でつないで1つの`atomically`に入れると，ほかのスレッドからは2つの組が同時に加わったように見える．
- `liftIO (readTVarIO v)`の型は，`MonadIO m => m a`である．ハンドラの中では`LspM () a`になる．

## 7-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- `analyze`は，これまでの関数の結果と同じであることを確かめる．個々の関数の振る舞いは，それぞれのテストがすでに確かめている．
- キャッシュは，読む前，書いたあと，書き直したあと，別の文書の4つの状態を確かめる．
- 差分同期は，capabilitiesと，差分を送ったあとの診断とホバーで確かめる．
- 統合テストの期待値は1つも変えない．診断，ホバー，定義，参照，補完，リネームの統合テストが，キャッシュへの書き換えの安全網になる．変えるのは，テストの補助の`TestServer.hs`だけである．

## 7-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | アウトラインのやり取りを足し，エディタが送るものを「開いた文書，変わった部分」にした | 完成形のやり取りをすべて示すため |
| [c4-component.md](../design/c4-component.md) | `Calc.Analysis`と`Lsp.State`を足した．`Lsp.Server`から`Calc.Parser`，`Calc.Check`，`Calc.Eval`への依存がなくなった | 解析を呼ぶのは`Calc.Analysis`だけ，状態を持つのは`Lsp.State`だけであることを示すため |
| [code-flow.md](../design/code-flow.md) | `analyze`を起点に2つの図に描き直した．1つ目は文書の変更からキャッシュまで，2つ目はキャッシュから各リクエストの結果まで | 「解析は1回，検索は何度でも」という構造を示すため |
| [lsp-sequence.md](../design/lsp-sequence.md) | キャッシュを参加者に足し，`didChange`で更新，リクエストで読む流れにした．`documentSymbol`を足し，`textDocumentSync`を`Incremental`にした | いつ解析が行われるかを示すため |

## 7-5 テストファーストの実装

### 1. `analyze`

```haskell
-- | Reads, checks and evaluates a document once.
analyze :: Text -> Analysis
analyze text =
  Analysis
    { anLines = T.lines text
    , anProblems = parseProblems <> checkProgram statements
    , anStatements = statements
    , anOccurrences = occurrences statements
    , anValues = evalProgram statements
    }
 where
  (parseProblems, statements) = parseProgram text
```

`anLines`は，補完がカーソルのある行の文字列を使うために持つ．

### 2. キャッシュ(`Lsp.State`)

「書き直したあと」の項目で，同じURIの結果を置き換えることを確かめる．
すでにある結果を残してしまう実装(`Map.insertWith (\_new old -> old)`)では失敗する．

```text
  1) Lsp.State.updateAnalysis replaces the analysis when the document changes
       expected: Just ["let a = 2"]
        but got: Just ["let a = 1"]
```

`Map.insert`は同じキーの値を置き換える．

```haskell
-- | Analyzes the new text of a document and keeps the result.
updateAnalysis :: Cache -> NormalizedUri -> Text -> IO Analysis
updateAnalysis cache uri text = do
  let analysis = analyze text
  atomically (modifyTVar' cache (Map.insert uri analysis))
  pure analysis

-- | The latest analysis of a document, if it has been opened.
lookupAnalysis :: Cache -> NormalizedUri -> IO (Maybe Analysis)
lookupAnalysis cache uri = Map.lookup uri <$> readTVarIO cache
```

### 3. `valueText`と`toDocumentSymbol`

まず`valueText`をテストファーストで作り，`hoverText`のテストを変えずに，`hoverText`が`valueText`を使う形に書き換える．

```haskell
hoverText :: Text -> Either EvalError Integer -> Text
hoverText name value@(Right _) = name <> " = " <> valueText value
hoverText name value@(Left _) = name <> ": " <> valueText value

-- | A value, or why it cannot be computed.
valueText :: Either EvalError Integer -> Text
valueText (Right value) = T.pack (show value)
valueText (Left err) = "cannot evaluate (" <> reason err <> ")"
 where
  reason DivisionByZero = "division by zero"
  reason (UndefinedVariable var) = "undefined variable '" <> var <> "'"
```

`value@(Right _)`は，引数全体に`value`という名前を付けたまま，`Right`かどうかで場合を分けるパターンである．
`toDocumentSymbol`は，`DocumentSymbol`のレコードを作るだけである([src/Lsp/Convert.hs](../src/Lsp/Convert.hs))．

### 4. サーバがキャッシュを受け取る

`serverDefinition`の引数にキャッシュを加えると，引き継いだ`TestServer.hs`がコンパイルできなくなる．

```text
test/integration/TestServer.hs:24:74: error: [GHC-83865]
    * Couldn't match expected type: lsp-2.8.0.0:Language.LSP.Server.Core.ServerDefinition
                                      config0
                  with actual type: Lsp.State.Cache
                                    -> lsp-2.8.0.0:Language.LSP.Server.Core.ServerDefinition ()
    * Probable cause: `serverDefinition' is applied to too few arguments
```

`run`と`TestServer.hs`で，キャッシュを作ってから渡す．

```haskell
run :: IO ()
run = do
  cache <- newCache
  void (runServer (serverDefinition cache))
```

```haskell
runCalcSession session = do
  (serverIn, clientOut) <- createPipe
  (clientIn, serverOut) <- createPipe
  cache <- newCache
  bracket
    (forkIO (void (runServerWithHandles mempty mempty serverIn serverOut (serverDefinition cache))))
    killThread
    (const (runSessionWithHandles clientOut clientIn config fullLatestClientCaps "." session))
```

テストごとに新しいキャッシュを作るので，テストどうしが結果を共有しない．

### 5. 通知のハンドラで解析する

`didOpen`と`didChange`から呼ぶ`checkDocument`で，解析結果をキャッシュに入れ，その結果からログと診断を送る．

```haskell
checkDocument :: Cache -> Uri -> LspM () ()
checkDocument cache uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents -> do
      let text = virtualFileText contents
      analysis <- liftIO (updateAnalysis cache (toNormalizedUri uri) text)
      sendNotification SMethod_WindowLogMessage $
        LogMessageParams MessageType_Info (summary uri text)
      sendNotification SMethod_TextDocumentPublishDiagnostics $
        PublishDiagnosticsParams
          uri
          (Just (virtualFileVersion contents))
          (map toDiagnostic (anProblems analysis))
```

### 6. リクエストのハンドラをキャッシュに切り替える

ハンドラを1つずつ，キャッシュの解析結果を使う形に書き換え，そのたびに統合テストを実行した．
例えばホバーは次の形になる．

```haskell
    , requestHandler SMethod_TextDocumentHover $ \request respond -> do
        let params = request ^. L.params
        analysis <- analysisOf cache (params ^. L.textDocument . L.uri)
        respond (Right (maybe (InR Null) InL (hoverAt (fromPosition (params ^. L.position)) =<< analysis)))
```

```haskell
-- | The latest analysis of a document.
analysisOf :: Cache -> Uri -> LspM () (Maybe Analysis)
analysisOf cache uri = liftIO (lookupAnalysis cache (toNormalizedUri uri))
```

`hoverAt`，`definitionAt`，`referencesAt`は，`[Statement]`の代わりに`Analysis`を受け取り，`anOccurrences`と`anValues`を使う．
最後に，使われなくなった`statementsOf`を消した．
どのハンドラも，もう構文解析をしない．

### 7. 差分同期

```haskell
  it "asks the editor for the changed parts only" $ do
    answer <- runCalcSession initializeResponse
    fmap (^. L.capabilities . L.textDocumentSync) (answer ^. L.result)
      `shouldBe` Right
        ( Just
            ( InL
                (TextDocumentSyncOptions (Just True) (Just TextDocumentSyncKind_Incremental) Nothing Nothing Nothing)
            )
        )
```

```text
  1) Sync, text document synchronization, asks the editor for the changed parts only
       expected: Right (Just (InL TextDocumentSyncOptions {
                   _openClose = Just True,
                   _change = Just TextDocumentSyncKind_Incremental,
                   _willSave = Nothing,
                   _willSaveWaitUntil = Nothing,
                   _save = Nothing
                 }))
        but got: Right (Just (InL TextDocumentSyncOptions {
                   _openClose = Just True,
                   _change = Just TextDocumentSyncKind_Full,
                   _willSave = Nothing,
                   _willSaveWaitUntil = Nothing,
                   _save = Nothing
                 }))
```

`syncOptions`の`_change`を`TextDocumentSyncKind_Incremental`にする．
差分を送るテストは，最初から通る．
VFSが差分を適用してからハンドラを呼ぶので，ハンドラから見える文書は常に全文である．

### 8. アウトライン

```haskell
    , requestHandler SMethod_TextDocumentDocumentSymbol $ \request respond -> do
        analysis <- analysisOf cache (request ^. L.params . L.textDocument . L.uri)
        respond (Right (InR (InL (maybe [] symbols analysis))))
```

```haskell
symbols :: Analysis -> [DocumentSymbol]
symbols analysis =
  [ toDocumentSymbol statement value
  | statement <- anStatements analysis
  , Just value <- [Map.lookup (stmtName statement) (anValues analysis)]
  ]
```

最後に，ロードマップの冒頭の使用例を，実行ファイルに`examples/sample.calc`を開かせて1行ずつ確かめた．

## 7-6 振り返り

1. 模範解答の新しい単体テストは，解析のまとめが3項目，キャッシュが4項目，変換が2項目である．
2. `lsp`ライブラリのVFSが差分を適用し，ハンドラには全文を渡すからである．ハンドラは`virtualFileText`で全文を読むだけなので，同期の方式を知らなくてよい．
3. 診断，ホバー，定義，参照，補完，リネーム，ログの統合テスト(18個)が安全網になった．期待値を変えたテストはなく，変えたのは`TestServer.hs`のキャッシュを作る1行と，`serverDefinition`に渡す箇所だけである．
4. `analyze`は純粋なので，入力と出力の比較だけでテストできる．`Lsp.State`のテストは`IO`の中で書くが，解析の中身には触れず，「入れたものが出てくるか」だけを確かめればよい．
5. 実装の途中で，`Lsp.Server`に`analysisOf`と`completionsAt`を加え，`statementsOf`を消した．`c4-component.md`の`Lsp.Server`の依存先から，`Calc.Parser`，`Calc.Check`，`Calc.Eval`が消えた．

## 7-7 発展課題

テストリストに，次の項目を足す．

- `removeAnalysis`のあと，`lookupAnalysis`は`Nothing`を返す
- 文書を閉じたあとのホバーは何も返さない

`notificationHandler SMethod_TextDocumentDidClose`で`liftIO (removeAnalysis cache (toNormalizedUri uri))`を呼ぶ．
`removeAnalysis`は`atomically (modifyTVar' cache (Map.delete uri))`で書ける．
閉じた文書の診断は，空の一覧を`publishDiagnostics`で送って消しておくとよい．
