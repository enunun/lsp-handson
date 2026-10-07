# Iteration 2の解説：式を解析して名前の誤りを見つける

演習の各段階について，模範解答と考え方を示す．

## 2-1 準備

引き継いだテストは，単体テストが18個，統合テストが4個である．
`examples/sample.calc`の5行目は`let`の形をしているので，Iteration 1のサーバは何も指摘しない．

## 2-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> parseTest (many (L.decimal <* hspace) :: Parser [Integer]) "1 2 3"
[1,2,3]
ghci> parseTest (string "let" :: Parser Text) "letter"
"let"
ghci> parseTest (string "let" <* notFollowedBy letterChar :: Parser Text) "letter"
1:4:
  |
1 | letter
  |    ^
unexpected 't'
ghci> foldl1 (-) [1, 2, 3 :: Int]
-4
ghci> foldr1 (-) [1, 2, 3 :: Int]
2
```

- `string "let"`だけでは，`letter`の先頭の3文字を`let`と読んでしまう．`notFollowedBy`で，キーワードのあとに名前の文字が続かないことを確かめる．
- `foldl1 (-)`は`(1 - 2) - 3`，`foldr1 (-)`は`1 - (2 - 3)`である．`1 - 2 - 3`と同じなのは`foldl1`で，左結合の演算子は`foldl`で組み立てる．

## 2-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- 式のテストは，被演算子1つ(変数)から始め，演算子の数と種類を少しずつ増やし，最後に括弧を足した．それぞれが，前の段階の実装を失敗させる．
- 空白のない書き方と行末のコメントは，字句の読み方(`lexeme`と`symbol`)を確かめる．
- 式の誤りは，行の途中で止まる場合(`12abc`)と行末で止まる場合(閉じていない括弧)の2つで，位置の決まり(その位置から行末まで)を確かめる．
- 名前の検査は，定義より前で使う場合と，自分の定義の中で使う場合を分けた．どちらも「上の行で定義されたか」という1つの決まりで説明できることを確かめる．
- 引き継いだテストのうち，正しい文の期待値には式が加わり，`let a =`のメッセージはmegaparsecのものに変わる．統合テストは変わらない．

## 2-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 診断のラベルを「構文の誤り，未定義の変数，二重定義」にした | 利用者が受け取る診断の種類が増えたため |
| [c4-component.md](../design/c4-component.md) | `Calc.Check`と，megaparsec，containersへの依存を足した | 名前の検査は解析済みの`[Statement]`だけを使うので，`Calc.Check`は`Calc.Parser`に依存しない |
| [code-flow.md](../design/code-flow.md) | `[Statement]`から`checkProgram`を通る枝と，2種類の問題を`<>`で合わせる箇所を足した．`parseLine`の読み方，`chainLeft`，`checkProgram`の決まりを図の下に書いた | 「どこまで読めたら式の誤りか」は図に描けない決まりなので，文で残す |
| [lsp-sequence.md](../design/lsp-sequence.md) | 変えていない | 新しい診断も，既存の`publishDiagnostics`の中で送るため |

## 2-5 テストファーストの実装

### 1. `Statement`に式を足す

`Calc.Syntax`に`Expr`と`Op`を定義し，`Statement`に`stmtExpr`を足すと，引き継いだテストがコンパイルできなくなる．

```text
test/unit/Calc/ParserSpec.hs:13:62: error: [GHC-83865]
    * Couldn't match expected type `Statement'
                  with actual type `Calc.Syntax.Expr -> Statement'
    * Probable cause: `Statement' is applied to too few arguments
      In the first argument of `Right', namely
        `(Statement "price" (Span 0 4 9))'
```

`Statement "price" (Span 0 4 9)`は，引数が1つ足りないので，まだ`Expr -> Statement`という関数である．
テストリストの「期待値を変えるテスト」に挙げた3つのテストに，右辺の式を足す．

```haskell
    it "reads a let statement and the position of its name" $
      parseLine 0 "let price = 1200"
        `shouldBe` Just (Right (Statement "price" (Span 0 4 9) (Number 1200)))
```

### 2. megaparsecへの書き換え(Refactor)

`let <name> =`までを読む`header`と，そのあとの式を読むパーサを作る．
`parseLine`は，まず`header`だけを読んでみて，読めなければ行全体を`expected: let <name> = <expr>`にする．
読めれば，行全体を文として読み，読めなかったら`toProblem`でmegaparsecのメッセージを問題にする．

```haskell
-- | Reads one line, given its line number. Blank lines and comment lines give 'Nothing'.
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line
  | T.null body || "--" `T.isPrefixOf` body = Nothing
  | otherwise = Just $ case parse (hspace *> header lineNo) "" line of
      Left _ -> Left (Problem (Span lineNo 0 (T.length line)) "expected: let <name> = <expr>")
      Right _ -> case parse (hspace *> statement lineNo <* eof) "" line of
        Left errors -> Left (toProblem lineNo line errors)
        Right parsed -> Right parsed
 where
  body = T.stripStart line
```

```haskell
-- | The part before the expression: @let <name> =@.
header :: Int -> Parser (Text, Span)
header lineNo = do
  _ <- lexeme (string "let" <* notFollowedBy (satisfy isNameChar))
  named <- lexeme (located lineNo name)
  _ <- symbol "="
  pure named

statement :: Int -> Parser Statement
statement lineNo = do
  (named, location) <- header lineNo
  Statement named location <$> expression lineNo
```

最初の`expression`は整数だけを読む(`expression _ = Number <$> lexeme L.decimal`)．
この段階では，右辺が`price * 8`の「行番号」のテストは`unexpected 'p'`で失敗したままになる．
変数(3)と`*`(4〜6)を読めるようになると通る．
引き継いだテストのうち，`let a =`のテストは期待値を変える．
`let a =`は`header`まで読めるので，式の誤りになる．
メッセージはREPLで確かめて期待値に写した．

```haskell
    it "reports a line without an expression after = at the end of the line" $
      parseLine 0 "let a ="
        `shouldBe` Just
          (Left (Problem (Span 0 7 7) "unexpected end of input\nexpecting '(', integer, or name"))
```

このメッセージは，式の部品がすべてそろったあとの文言である．
書き換えの途中では`expecting integer`のように短くなる．

### 3. 変数とその位置

```haskell
    it "reads a variable and the position where it is used" $
      parseLine 0 "let total = price"
        `shouldBe` Just (Right (Statement "total" (Span 0 4 9) (Var "price" (Span 0 12 17))))
```

整数か変数を読む`factor`を作る．
変数の位置は，名前を読む前後の`getOffset`で取る(`located`)．

```haskell
  factor =
    Number <$> lexeme L.decimal
      <|> uncurry Var <$> lexeme (located lineNo name)
```

`located lineNo name`の結果は`(Text, Span)`なので，`uncurry Var`で`Var`の2つの引数に渡す．

### 4. 足し算と5. 左結合

```haskell
    it "reads an addition" $
      exprOf "let a = 1 + 2" `shouldBe` Just (BinOp Add (Number 1) (Number 2))
    it "groups operators of the same strength to the left" $
      exprOf "let a = 1 - 2 - 3"
        `shouldBe` Just (BinOp Sub (BinOp Sub (Number 1) (Number 2)) (Number 3))
```

`exprOf`は，テストのファイルの`where`で定義した，文から式だけを取り出す補助の関数である．
「被演算子と，(演算子，被演算子)の一覧」を読み，`foldl`で左から組み立てる`chainLeft`を作る．

```haskell
-- | Reads one or more operands separated by operators, and combines them from the left.
chainLeft :: Parser Expr -> Parser Op -> Parser Expr
chainLeft operand operator = foldl combine <$> operand <*> many ((,) <$> operator <*> operand)
 where
  combine left (op, right) = BinOp op left right
```

この段階では，4つの演算子を同じ強さで読む．

```haskell
expression lineNo = chainLeft factor (Add <$ symbol "+" <|> Sub <$ symbol "-" <|> Mul <$ symbol "*" <|> Div <$ symbol "/")
```

### 6. `*`は`+`より強く結合する

```haskell
    it "binds * more tightly than +" $
      exprOf "let a = 1 + 2 * 3"
        `shouldBe` Just (BinOp Add (Number 1) (BinOp Mul (Number 2) (Number 3)))
```

```text
  1) Calc.Parser, parseLine (expressions), binds * more tightly than +
       expected: Just (BinOp Add (Number 1) (BinOp Mul (Number 2) (Number 3)))
        but got: Just (BinOp Mul (BinOp Add (Number 1) (Number 2)) (Number 3))
```

強さごとに段を分ける．
弱い段(`+` `-`)の被演算子が，強い段(`*` `/`)の式になる．

```haskell
expression :: Int -> Parser Expr
expression lineNo = chainLeft term (Add <$ symbol "+" <|> Sub <$ symbol "-")
 where
  term = chainLeft factor (Mul <$ symbol "*" <|> Div <$ symbol "/")
```

### 7. `/`は`*`と同じ強さ

```haskell
    it "binds / as tightly as * and groups them to the left" $
      exprOf "let a = 8 / 2 * 3"
        `shouldBe` Just (BinOp Mul (BinOp Div (Number 8) (Number 2)) (Number 3))
```

6の実装で，このテストは最初から通る．
`/`を`term`の段に置いたことを記録するテストとして残す．

### 8. 括弧

```haskell
    it "reads parentheses first" $
      exprOf "let a = (1 + 2) * 3"
        `shouldBe` Just (BinOp Mul (BinOp Add (Number 1) (Number 2)) (Number 3))
```

```text
  1) Calc.Parser, parseLine (expressions), reads parentheses first
       expected: Just (BinOp Mul (BinOp Add (Number 1) (Number 2)) (Number 3))
        but got: Nothing
```

`factor`に，括弧で囲んだ式を足す．
括弧の中は`expression`(一番弱い段)に戻る．

```haskell
      <|> (symbol "(" *> expression lineNo <* symbol ")")
```

### 9. 空白のない文と10. 行末のコメント

```haskell
    it "reads a statement without spaces" $
      exprOf "let a=1+2" `shouldBe` Just (BinOp Add (Number 1) (Number 2))
    it "allows a comment at the end of the line" $
      exprOf "let a = 1 -- one" `shouldBe` Just (Number 1)
```

空白を`hspace`だけで読み飛ばしていると，コメントの行は文として読めない．

```text
  1) Calc.Parser, parseLine (expressions), allows a comment at the end of the line
       expected: Just (Number 1)
        but got: Nothing
```

`L.space`で，空白と行コメントをまとめて読み飛ばす．

```haskell
-- | Spaces and a comment that runs to the end of the line.
spaces :: Parser ()
spaces = L.space hspace1 (L.skipLineComment "--") empty
```

### 11. 式が途中で読めなくなった位置

```haskell
    it "reports where the expression stops, up to the end of the line" $
      parseLine 0 "let a = 12abc"
        `shouldBe` Just
          ( Left
              ( Problem
                  (Span 0 10 13)
                  "unexpected 'a'\nexpecting '*', '+', '-', '/', digit, or end of input"
              )
          )
```

`eof`を続けずに`parse`すると，`12`まで読んだところで成功してしまう．

```text
  1) Calc.Parser, parseLine (expressions), reports where the expression stops, up to the end of the line
       expected: Just (Left Problem {
                   problemSpan = Span {
                     spanLine = 0,
                     spanStart = 10,
                     spanEnd = 13
                   },
                   problemMessage = "unexpected 'a'\nexpecting '*', '+', '-', '/', digit, or end of input"
                 })
        but got: Just (Right Statement {
                   stmtName = "a",
                   stmtSpan = Span {
                     spanLine = 0,
                     spanStart = 4,
                     spanEnd = 5
                   },
                   stmtExpr = Number 12
                 })
```

`statement lineNo <* eof`で，行の最後まで読んだことを求める．
誤りの位置とメッセージは，最初のエラーから取り出す．

```haskell
-- | A problem at the position where the expression could not be read, up to the end of the line.
toProblem :: Int -> Text -> ParseErrorBundle Text Void -> Problem
toProblem lineNo line errors =
  Problem
    (Span lineNo column (max column (T.length line)))
    (T.strip (T.pack (parseErrorTextPretty firstError)))
 where
  firstError = NE.head (bundleErrors errors)
  column = errorOffset firstError
```

### 12. 閉じていない括弧

```haskell
    it "reports an unclosed parenthesis at the end of the line" $
      parseLine 0 "let broken = (1 + 2"
        `shouldBe` Just
          ( Left
              ( Problem
                  (Span 0 19 19)
                  "unexpected end of input\nexpecting ')', '*', '+', '-', '/', or digit"
              )
          )
```

11の実装で通る．
行末で止まると，範囲は長さ0(19列から19列)になる．
エディタは，その位置に短い波線を引く．

### 13. `parseProgram`の期待値

誤りと文を集めるテストの期待値に，`Number 1200`と`Number 96`を足す．

### 14〜19. `checkProgram`

```haskell
  it "reports a variable that is not defined" $
    check "let total = price + 1\n"
      `shouldBe` [Problem (Span 0 12 17) "undefined variable 'price'"]
```

`check`は，テストのファイルの`where`で定義した，文書から`checkProgram`の結果を作る補助の関数である．
最初のテスト(すべて定義済み)は`checkProgram _ = []`で通る．
2つ目のテストで，この仮実装が失敗する．

```text
  1) Calc.Check.checkProgram reports a variable that is not defined
       expected: [Problem {problemSpan = Span {spanLine = 0, spanStart = 12, spanEnd = 17}, problemMessage = "undefined variable 'price'"}]
        but got: []
```

式の変数を集める再帰関数`variables`と，名前の集合を持ち回る`mapAccumL`で実装する．

```haskell
-- | Reports variables used before their definition, and names defined twice.
checkProgram :: [Statement] -> [Problem]
checkProgram statements = concat (snd (mapAccumL check Set.empty statements))

-- | Checks one statement against the names defined above it, and adds its name.
check :: Set Text -> Statement -> (Set Text, [Problem])
check defined (Statement name location expr) =
  (Set.insert name defined, undefinedUses)
 where
  undefinedUses =
    [ Problem used ("undefined variable '" <> var <> "'")
    | (var, used) <- variables expr
    , not (var `Set.member` defined)
    ]
```

「下の行でだけ定義された変数」と「自分の定義の中で使った変数」のテストは，この実装で通る．
`check`は式を調べてから名前を集合に加えるので，どちらの場合も，使った時点では未定義である．

二重定義のテストを足すと失敗する．

```text
  1) Calc.Check.checkProgram reports the second definition of a name
       expected: [Problem {problemSpan = Span {spanLine = 1, spanStart = 4, spanEnd = 9}, problemMessage = "'price' is already defined"}]
        but got: []
```

名前がすでに集合にあれば，問題を足す．

```haskell
check :: Set Text -> Statement -> (Set Text, [Problem])
check defined (Statement name location expr) =
  (Set.insert name defined, undefinedUses <> redefinition)
 where
  ...
  redefinition =
    [Problem location ("'" <> name <> "' is already defined") | name `Set.member` defined]
```

最後の「行の順に並ぶ」テストは，この実装で通る．
同じ行では未定義の変数，二重定義の順になることを記録している．

### 20. 未定義の変数の統合テスト

```haskell
  it "reports a variable that is not defined" $ do
    diagnostics <- runCalcSession $ do
      _ <- createDoc "sample.calc" "calc" "let price = 1200\nlet total = price + fee\n"
      waitForDiagnostics
    map (\d -> (d ^. L.range, d ^. L.message)) diagnostics
      `shouldBe` [(Range (Position 1 20) (Position 1 23), "undefined variable 'fee'")]
```

```text
  1) Diagnostics.textDocument/publishDiagnostics reports a variable that is not defined
       expected: [(Range {_start = Position {_line = 1, _character = 20}, _end = Position {_line = 1, _character = 23}},"undefined variable 'fee'")]
        but got: []
```

`publishProblems`で，構文の問題と名前の問題を合わせる．

```haskell
      let (problems, statements) = parseProgram (virtualFileText contents)
          diagnostics = map toDiagnostic (problems <> checkProgram statements)
```

完成したコードは[src/Calc/Parser.hs](../src/Calc/Parser.hs)と[src/Calc/Check.hs](../src/Calc/Check.hs)にある．
仕上げのRefactorで，名前の文字を判定する述語を`isLetter`と`isNameChar`にまとめ，`name`と`header`の両方で使うようにした．

## 2-6 振り返り

1. 模範解答の式のテストは10項目である．7のように最初から通るテストは，設計の決まり(`/`を`*`と同じ段に置く)を記録するために残している．
2. `header`を分けずに行全体を1つのパーサで読むと，`let`の形でない行もmegaparsecのメッセージになる．`price * 2`は`unexpected "pri"`と`expecting "let" or white space`の2行になり，Iteration 1の`expected: let <name> = <expr>`より分かりにくい．`let 1x = 3`の誤りも名前の位置(4〜10列)だけになる．文の形の誤りと式の誤りを分けることで，それぞれに合ったメッセージと範囲を選べる．
3. `foldr`で組み立てると，`1 - 2 - 3`は`BinOp Sub (Number 1) (BinOp Sub (Number 2) (Number 3))`，つまり`1 - (2 - 3)`になる．Iteration 3で値を計算すると，結果が`-4`ではなく`2`になってしまう．
4. `Calc.Check`は`[Statement]`だけを受け取るので，テストでは`parseProgram`で作った文を渡すだけでよい．名前の検査を構文解析と別に確かめられる．
5. 実装の途中で，`header`，`statement`，`chainLeft`，`located`，`lexeme`，`symbol`，`toProblem`を`Calc.Parser`の中の関数として加えた．どれも外に公開していないので，`c4-component.md`は変わらない．読み方の決まりを`code-flow.md`の図の下に書いた．

## 2-7 発展課題

テストリストに，次の項目を足す．

- `-5`は`Neg (Number 5)`
- `-(1 + 2)`は`Neg (BinOp Add (Number 1) (Number 2))`
- `2 * -3`は`BinOp Mul (Number 2) (Neg (Number 3))`
- `1 - -2`は`BinOp Sub (Number 1) (Neg (Number 2))`

`Expr`に`Neg Expr`を足すと，`variables`にも`Neg`の場合が必要になり，コンパイラの警告(`-Wincomplete-patterns`)が教えてくれる．
`factor`に`Neg <$> (symbol "-" *> factor)`を足すと，単項のマイナスが`*`より強く結合する．
