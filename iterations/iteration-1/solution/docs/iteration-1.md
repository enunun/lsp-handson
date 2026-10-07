# Iteration 1の解説：最初の診断を出す

演習の各段階について，模範解答と考え方を示す．

## 1-1 準備

`cabal.project`に`iterations/iteration-1/exercise`を足してビルドすると，Iteration 0から引き継いだ7つのテスト(単体5，統合2)が通る．
エディタでは，ログに行数が出るだけで，波線はまだ出ない．

## 1-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> T.words "let x=1"
["let","x=1"]
ghci> parseLine 0 "let x=1"
Just (Left (Problem {problemSpan = Span {spanLine = 0, spanStart = 0, spanEnd = 7}, problemMessage = "expected: let <name> = <expr>"}))
ghci> partitionEithers (catMaybes [Just (Left 'a'), Nothing, Just (Right True)])
("a",[True])
```

- `T.words`は空白だけで区切るので，`x=1`は1語になる．Iteration 1の`parseLine`は語の並びで判定するので，この行は誤りになる．Iteration 2で式を構文解析するようになると，空白のない書き方も読めるようになる．
- `catMaybes`は`mapMaybe id`と同じで，`Nothing`を除いて`Just`の中身を集める．

## 1-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- `parseLine`の項目は，3つのまとまりの順に並べた．正しい文と位置の計算(行番号，字下げ，`let`のあとの空白)，崩れた行の種類，調べない行(空行とコメント)である．後の項目ほど，前の実装を失敗させるように選んでいる．
- `parseProgram`は，空のプログラムと，すべての種類の行を混ぜたプログラムの2つで確かめる．空行とコメント行を飛ばしても，行番号が元の行のままであることを，混ぜたプログラムの期待値で確かめている．
- `Lsp.Convert`は，LSPの型への変換を単体テストで確かめる．
- 統合テストは，開いたときに診断が付くことと，直すと消えることの2つである．
- 引き継いだテストのうち，文書を変えたときのログのテストは失敗する．診断の通知が，ログより先に届くからである．ほかのメッセージを読み飛ばす形に変える．

## 1-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 「診断(letの形でない行)」のやり取りと，利用者に見える「波線とメッセージ」を足した．診断は毎回すべて送り直すという決まりを書いた | 利用者から見える変化と，LSPの診断の性質を示すため |
| [c4-component.md](../design/c4-component.md) | `Calc.Syntax`，`Calc.Parser`，`Lsp.Convert`を足した．`Lsp.Convert`は`Lsp.*`の側に置いた | `Calc.*`をLSPの型から切り離し，`lsp`なしで単体テストできるようにするため |
| [code-flow.md](../design/code-flow.md) | `Text` → `([Problem], [Statement])` → `[Problem]` → `[Diagnostic]` → `publishDiagnostics`の流れと，`parseLine`の決まりを足した | 行の判定と位置の決まりは図に描けないので，図の下に書いた |
| [lsp-sequence.md](../design/lsp-sequence.md) | `didOpen`と`didChange`のあとに`publishDiagnostics`を足した | 1つの通知に対して，サーバが2つの通知(ログと診断)を返すことを示すため |

## 1-5 テストファーストの実装

`Calc.Syntax`のレコードは，ロードマップのとおりに定義した([src/Calc/Syntax.hs](../src/Calc/Syntax.hs))．
以下，テストリストの項目ごとに，テストと，そのときのコードを示す．

### 1. `let price = 1200`は文で，名前の位置は0行の4〜9列

```haskell
    it "reads a let statement and the position of its name" $
      parseLine 0 "let price = 1200" `shouldBe` Just (Right (Statement "price" (Span 0 4 9)))
```

定数を返す仮実装で通す．

```haskell
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine _ _ = Just (Right (Statement "price" (Span 0 4 9)))
```

### 2. 行番号を位置に使う

```haskell
    it "uses the line number for the position" $
      parseLine 3 "let tax = price * 8" `shouldBe` Just (Right (Statement "tax" (Span 3 4 7)))
```

```text
  1) Calc.Parser.parseLine uses the line number for the position
       expected: Just (Right Statement {
                   stmtName = "tax",
                   stmtSpan = Span {
                     spanLine = 3,
                     spanStart = 4,
                     spanEnd = 7
                   }
                 })
        but got: Just (Right Statement {
                   stmtName = "price",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 4,
                     spanEnd = 9
                   }
                 })
```

`T.words`で語に分け，2語目を名前にする．
開始列は，まだ4のままの仮実装である．

```haskell
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line = case T.words line of
  ("let" : name : _) -> Just (Right (Statement name (Span lineNo 4 (4 + T.length name))))
  _ -> Nothing
```

### 3. 行頭の空白と`let`のあとの空白を位置に数える

```haskell
    it "counts the indentation and the spaces after let in the position" $
      parseLine 0 "  let   a = 1" `shouldBe` Just (Right (Statement "a" (Span 0 8 9)))
```

```text
  1) Calc.Parser.parseLine counts the indentation and the spaces after let in the position
       expected: Just (Right Statement {
                   stmtName = "a",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 8,
                     spanEnd = 9
                   }
                 })
        but got: Just (Right Statement {
                   stmtName = "a",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 4,
                     spanEnd = 5
                   }
                 })
```

開始列を，字下げの幅，`let`の3文字，`let`のあとの空白の幅の合計にする．

```haskell
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line = case T.words body of
  ("let" : name : _) -> Just (Right (Statement name (nameSpan name)))
  _ -> Nothing
 where
  body = T.stripStart line
  indent = T.length line - T.length body
  nameSpan name =
    let start = indent + T.length "let" + T.length (T.takeWhile isSpace (T.drop 3 body))
     in Span lineNo start (start + T.length name)
```

### 4. `let`で始まらない行は，行全体が誤り

```haskell
    it "reports a line that does not start with let" $
      parseLine 1 "price * 2" `shouldBe` Just (Left (expected (Span 1 0 9)))
```

`expected`は，テストのファイルの`where`で定義した補助の関数である．

```haskell
 where
  expected s = Problem s "expected: let <name> = <expr>"
```

```text
  1) Calc.Parser.parseLine reports a line that does not start with let
       expected: Just (Left (Problem {problemSpan = Span {spanLine = 1, spanStart = 0, spanEnd = 9}, problemMessage = "expected: let <name> = <expr>"}))
        but got: Nothing
```

一致しない場合を`Nothing`から誤りに変える．

```haskell
  _ -> Just (Left problem)
 where
  ...
  problem = Problem (Span lineNo 0 (T.length line)) "expected: let <name> = <expr>"
```

### 5. 数字で始まる名前は誤り

```haskell
    it "reports a name that starts with a digit" $
      parseLine 0 "let 1x = 3" `shouldBe` Just (Left (expected (Span 0 0 10)))
```

```text
  1) Calc.Parser.parseLine reports a name that starts with a digit
       expected: Just (Left Problem {
                   problemSpan = Span {
                     spanLine = 0,
                     spanStart = 0,
                     spanEnd = 10
                   },
                   problemMessage = "expected: let <name> = <expr>"
                 })
        but got: Just (Right Statement {
                   stmtName = "1x",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 4,
                     spanEnd = 6
                   }
                 })
```

名前の規則を`isName`に書き，パターンにガードを付ける．

```haskell
  ("let" : name : _) | isName name -> Just (Right (Statement name (nameSpan name)))
```

```haskell
-- | A name starts with an ASCII letter and continues with ASCII letters and digits.
isName :: Text -> Bool
isName name = case T.uncons name of
  Just (first, rest) -> isLetter first && T.all (\c -> isLetter c || isDigit c) rest
  Nothing -> False
 where
  isLetter c = isAsciiLower c || isAsciiUpper c
```

### 6. `=`がない行は誤り

```haskell
    it "reports a line without =" $
      parseLine 0 "let a 1" `shouldBe` Just (Left (expected (Span 0 0 7)))
```

```text
  1) Calc.Parser.parseLine reports a line without =
       expected: Just (Left Problem {
                   problemSpan = Span {
                     spanLine = 0,
                     spanStart = 0,
                     spanEnd = 7
                   },
                   problemMessage = "expected: let <name> = <expr>"
                 })
        but got: Just (Right Statement {
                   stmtName = "a",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 4,
                     spanEnd = 5
                   }
                 })
```

3語目に`"="`を求める．

```haskell
  ("let" : name : "=" : _) | isName name -> Just (Right (Statement name (nameSpan name)))
```

### 7. `=`のあとが空の行は誤り

```haskell
    it "reports a line without an expression after =" $
      parseLine 0 "let a =" `shouldBe` Just (Left (expected (Span 0 0 7)))
```

失敗の出力は6と同じ形で，`stmtName = "a"`の文として読んでしまう．
`=`のあとに1語以上を求める．

```haskell
  ("let" : name : "=" : _ : _) | isName name -> Just (Right (Statement name (nameSpan name)))
```

### 8. 空白だけの行は調べない

```haskell
    it "skips a blank line" $
      parseLine 0 "   " `shouldBe` Nothing
```

```text
  1) Calc.Parser.parseLine skips a blank line
       expected: Nothing
        but got: Just (Left (Problem {problemSpan = Span {spanLine = 0, spanStart = 0, spanEnd = 3}, problemMessage = "expected: let <name> = <expr>"}))
```

関数の定義にガードを足す．

```haskell
parseLine lineNo line
  | T.null body = Nothing
  | otherwise = case T.words body of
      ...
```

### 9. `--`で始まる行は調べない

```haskell
    it "skips a comment line" $
      parseLine 0 "  -- total price" `shouldBe` Nothing
```

```text
  1) Calc.Parser.parseLine skips a comment line
       expected: Nothing
        but got: Just (Left (Problem {problemSpan = Span {spanLine = 0, spanStart = 0, spanEnd = 16}, problemMessage = "expected: let <name> = <expr>"}))
```

ガードの条件に，コメント行を調べる式``"--" `T.isPrefixOf` body``を足す．
ここでRefactorとして，文を読む部分を`Maybe Statement`を返す`statement`に分け，`maybe (Left problem) Right statement`で結果の形にそろえた．

```haskell
-- | Reads one line, given its line number. Blank lines and comment lines give 'Nothing'.
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line
  | T.null body || "--" `T.isPrefixOf` body = Nothing
  | otherwise = Just (maybe (Left problem) Right statement)
 where
  body = T.stripStart line
  indent = T.length line - T.length body
  problem = Problem (Span lineNo 0 (T.length line)) "expected: let <name> = <expr>"
  statement = case T.words body of
    ("let" : name : "=" : _ : _) | isName name -> Just (Statement name (nameSpan name))
    _ -> Nothing
  nameSpan name =
    let start = indent + T.length "let" + T.length (T.takeWhile isSpace (T.drop 3 body))
     in Span lineNo start (start + T.length name)
```

### 10. 空のプログラムからは何も読まない

```haskell
    it "reads nothing from an empty program" $
      parseProgram "" `shouldBe` ([], [])
```

仮実装で通す．

```haskell
parseProgram :: Text -> ([Problem], [Statement])
parseProgram _ = ([], [])
```

### 11. 誤りと文を行の順に集める

```haskell
    it "collects the problems and the statements in order" $
      parseProgram "let price = 1200\nprice * 2\n\n-- note\nlet tax = 96\nlet 1x = 3\n"
        `shouldBe` ( [expected (Span 1 0 9), expected (Span 5 0 10)]
                   , [Statement "price" (Span 0 4 9), Statement "tax" (Span 4 4 7)]
                   )
```

```text
  1) Calc.Parser.parseProgram collects the problems and the statements in order
       expected: ([Problem {problemSpan = Span {spanLine = 1, spanStart = 0, spanEnd = 9}, problemMessage = "expected: let <name> = <expr>"},Problem {problemSpan = Span {spanLine = 5, spanStart = 0, spanEnd = 10}, problemMessage = "expected: let <name> = <expr>"}],[Statement {stmtName = "price", stmtSpan = Span {spanLine = 0, spanStart = 4, spanEnd = 9}},Statement {stmtName = "tax", stmtSpan = Span {spanLine = 4, spanStart = 4, spanEnd = 7}}])
        but got: ([],[])
```

行番号を付けて`parseLine`に渡し，調べない行を除いてから，誤りと文に分ける．

```haskell
-- | Reads every line of a program, collecting the problems and the statements in order.
parseProgram :: Text -> ([Problem], [Statement])
parseProgram text = partitionEithers (mapMaybe (uncurry parseLine) (zip [0 ..] (T.lines text)))
```

### 12. `toRange`と13. `toDiagnostic`

```haskell
  describe "toRange"
    $ it "keeps the line and the columns"
    $ toRange (Span 2 4 9) `shouldBe` Range (Position 2 4) (Position 2 9)
```

```haskell
toRange :: Span -> Range
toRange (Span line start end) =
  Range
    (Position (fromIntegral line) (fromIntegral start))
    (Position (fromIntegral line) (fromIntegral end))
```

`toDiagnostic`のテストは，`Diagnostic`のコンストラクタにフィールドの順で値を並べて期待値を作る([test/unit/Lsp/ConvertSpec.hs](../test/unit/Lsp/ConvertSpec.hs))．
実装はレコード構文で書き，どのフィールドに何を入れたかが読めるようにした．

```haskell
toDiagnostic :: Problem -> Diagnostic
toDiagnostic (Problem location message) =
  Diagnostic
    { _range = toRange location
    , _severity = Just DiagnosticSeverity_Error
    , _code = Nothing
    , _codeDescription = Nothing
    , _source = Just "calc"
    , _message = message
    , _tags = Nothing
    , _relatedInformation = Nothing
    , _data_ = Nothing
    }
```

変数名を`span`にすると，`Prelude`の`span`を隠すという警告(`-Wname-shadowing`)が出るので，`location`にした．

### 14. 開いた文書の`let`の形でない行に診断が付く

```haskell
  it "reports a line that is not a let statement when a document is opened" $ do
    diagnostics <- runCalcSession $ do
      _ <- createDoc "sample.calc" "calc" "let price = 1200\nprice * 2\n"
      waitForDiagnostics
    map (\d -> (d ^. L.range, d ^. L.message)) diagnostics
      `shouldBe` [(Range (Position 1 0) (Position 1 9), "expected: let <name> = <expr>")]
```

サーバは診断を送らないので，ログを受け取ったあと，診断を待ちきれずに失敗する．

```text
  1) Diagnostics.textDocument/publishDiagnostics reports a line that is not a let statement when a document is opened
       uncaught exception: SessionException
       Timed out waiting to receive a message from the server.
       Last message received:
       {
           "jsonrpc": "2.0",
           "method": "window/logMessage",
           "params": {
               "message": "sample.calc: 2 lines",
               "type": 3
           }
       }
```

`didOpen`と`didChange`のハンドラから呼ぶ関数を`checkDocument`にまとめ，ログに続けて診断を送る．

```haskell
-- | Logs the size of the document and sends its diagnostics.
checkDocument :: Uri -> LspM () ()
checkDocument uri = do
  logSummary uri
  publishProblems uri
```

```haskell
-- | Sends a diagnostic for every problem in the document. An empty list clears earlier ones.
publishProblems :: Uri -> LspM () ()
publishProblems uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents -> do
      let (problems, _statements) = parseProgram (virtualFileText contents)
      sendNotification SMethod_TextDocumentPublishDiagnostics $
        PublishDiagnosticsParams uri (Just (virtualFileVersion contents)) (map toDiagnostic problems)
```

### 15. 文書を直すと診断が空になる

```haskell
  it "clears the diagnostics when the document is fixed" $ do
    diagnostics <- runCalcSession $ do
      document <- createDoc "sample.calc" "calc" "price * 2\n"
      _ <- waitForDiagnostics
      changeDoc document [wholeDocument "let price = 1200\n"]
      waitForDiagnostics
    diagnostics `shouldBe` []
```

`publishProblems`は誤りがなくても空の一覧を送るので，このテストは最初から通る．
「直したら波線が消える」は要求の一部なので，振る舞いを記録するテストとして残す．

### 16. 引き継いだログのテストを直す

診断の通知を送るようにすると，Iteration 0の「文書を変えるとログが出る」テストが失敗する．

```text
  1) LogMessage.window/logMessage reports the number of lines again when the document changes
       uncaught exception: SessionException
       Received an unexpected message from the server:
       Was parsing: Request for: SMethod_WindowLogMessage
       But the last message received was:
       {
           "jsonrpc": "2.0",
           "method": "textDocument/publishDiagnostics",
           "params": {
               "diagnostics": [],
               "uri": "file:///…/sample.calc",
               "version": 0
           }
       }
```

URIのパスは環境によって変わるので，`…`で省いてある．
`message`は「次に届くメッセージ」がログであることを求める．
文書を開いたときの診断が，変えたあとのログより先に届くので失敗した．
ほかのメッセージを読み飛ばしてログを待つように変える．

```haskell
      changeDoc document [wholeDocument "let a = 1\nlet b = 2\nlet c = 3\n"]
      skipManyTill anyMessage (message SMethod_WindowLogMessage)
```

## 1-6 振り返り

1. 模範解答の`parseLine`の項目は9つで，そのうち4つが崩れた行の種類である．行末のコメント(`let a = 1 -- note`)は，`=`のあとに語があるので正しい文として読む．式の中身はIteration 2で調べる．
2. `Maybe (Either Problem Statement)`なら，`mapMaybe`で調べない行を除いたあと，`partitionEithers`で分けられる．`Either Problem (Maybe Statement)`だと，誤りと「文または調べない行」に分かれ，文を取り出すにはもう一度`Maybe`を外す必要がある．「調べない」を一番外に置くと，一覧の処理が段階ごとに1つの関数で書ける．
3. `Lsp.Convert`はLSPの型(`Range`，`Diagnostic`)を使う．`Calc.*`に置くと，`Calc.*`が`lsp-types`に依存し，言語の処理とエディタとのやり取りの境界がなくなる．
4. 文書を変えたときのログのテストが，診断の通知を受け取って失敗した．`skipManyTill anyMessage`で読み飛ばすように直した．テストが特定のメッセージの順序に頼りすぎていたことが分かる．
5. 実装の途中で，`didOpen`と`didChange`から呼ぶ`checkDocument`と，診断を送る`publishProblems`を`Lsp.Server`の中に加えた．どちらも`Lsp.Server`の中の関数なので，`c4-component.md`は変わらない．`code-flow.md`の図の下に，`parseLine`の判定と位置の決まりを書いた．

## 1-7 発展課題

テストリストに，次の項目を足す．

- 行末に空白がある行は，その空白の範囲に警告が付く．
- 行末に空白がない行には，警告が付かない．
- `let`の形でない行に行末の空白があれば，誤りと警告の両方が付く．

重さを持つ誤りを表すため，`Calc.Syntax`に`data Severity = Error | Warning`を足し，`Problem`に`problemSeverity`を持たせる．
`Calc.*`はLSPの型を使わないので，`DiagnosticSeverity`ではなく自分の型にする．
`toDiagnostic`が`Severity`を`DiagnosticSeverity_Error`か`DiagnosticSeverity_Warning`に変える．
`parseProgram`の結果に警告も入れるか，警告を集める別の関数を作るかは，`code-flow.md`に描いて比べてから決める．
