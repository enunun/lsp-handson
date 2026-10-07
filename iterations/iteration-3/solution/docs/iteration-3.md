# Iteration 3の解説：ホバーで値を見る

演習の各段階について，模範解答と考え方を示す．

## 3-1 準備

引き継いだテストは，単体テストが34個，統合テストが5個である．
Iteration 2のサーバはホバーのハンドラを持たないので，`initialize`の応答に`hoverProvider`がなく，エディタはホバーを要求しない．

## 3-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> Map.fromList [("a", 1), ("a", 2 :: Int)] :: Map.Map Text Int
fromList [("a",2)]
ghci> do { a <- safeDiv 100 5; b <- safeDiv a 0; safeDiv b 2 }
Left "division by zero"
ghci> InL 1 :: Int |? Bool
InL 1
ghci> InR True :: Int |? Bool
InR True
```

- `Map.fromList`では，同じキーのあとの値が残る．
- 途中で`Left`になると，その後の`safeDiv b 2`は計算されず，`Left`が全体の結果になる．

## 3-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- 評価は，数，変数，演算の順に単純なものから並べ，丸め，2種類の失敗，失敗の伝わり方，二重定義を足した．
- 割り算の丸めは，正の数(`7 / 2`)と負の数(`(0 - 7) / 2`)の2つで確かめる．Calcには負の数のリテラルがないので，引き算で負の数を作る．
- 位置は，名前の最初の文字，最後の文字，直後の3か所で境界を確かめる．
- 統合テストは，値，失敗の理由，何もない場合の3つである．評価の細かい場合分けは単体テストに任せる．

## 3-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 「ホバーの要求(位置)」と「変数の値」のやり取りを足し，利用者に見えるものにホバーを加えた | 通知だけでなく，エディタからの要求に応える機能が加わったため |
| [c4-component.md](../design/c4-component.md) | `Calc.Eval`と`Calc.Query`を足した．`Lsp.Convert`から`Calc.Eval`への依存を足した | `hoverText`が`EvalError`を文字列にするため |
| [code-flow.md](../design/code-flow.md) | ホバーの流れを2つ目の図にした．`nameAt`と`Map.lookup`で`Nothing`になりうることを書いた | 診断とホバーは入力が違う(文書全体と，文書と位置)ので，図を分けた |
| [lsp-sequence.md](../design/lsp-sequence.md) | `textDocument/hover`のリクエストと応答を足し，`null`の場合を`alt`で分けた．`initialize`の応答に`hoverProvider`を書いた | リクエストと通知の違いと，capabilitiesの変化を示すため |

`c4-component.md`の図の下には，`variables`が`Calc.Check`と`Calc.Query`の両方にあることを書いた．
Iteration 4で，この重複をまとめる．

## 3-5 テストファーストの実装

### 1. 評価(`Calc.Eval`)

空のプログラムと数のテストは，`foldl'`で名前と値を`Map`に加える形と，数だけを計算する`evalExpr`で通る．

```haskell
evalProgram :: [Statement] -> Map Text (Either EvalError Integer)
evalProgram = foldl' define Map.empty
 where
  define values (Statement name _ expr) = Map.insert name (evalExpr values expr) values
```

変数のテストで`Map.lookup`を，演算のテストで`BinOp`の`do`と`apply`を足す．

```haskell
evalExpr :: Map Text (Either EvalError Integer) -> Expr -> Either EvalError Integer
evalExpr _ (Number n) = Right n
evalExpr values (Var name _) = fromMaybe (Left (UndefinedVariable name)) (Map.lookup name values)
evalExpr values (BinOp op left right) = do
  a <- evalExpr values left
  b <- evalExpr values right
  apply op a b
```

`Map`の値が`Either EvalError Integer`なので，変数の値はそのまま式の値になる．
失敗した変数を使う式は，`do`の`<-`で止まり，同じ失敗になる．

### 2. 負の商の丸め

```haskell
  it "rounds a negative quotient down" $
    Map.lookup "a" (eval "let a = (0 - 7) / 2\n") `shouldBe` Just (Right (-4))
```

`quot`で割っていると，0の方向へ丸めてしまう．

```text
  1) Calc.Eval.evalProgram rounds a negative quotient down
       expected: Just (Right (-4))
        but got: Just (Right (-3))
```

`div`を使う．

### 3. 0での割り算

```haskell
  it "reports a division by zero" $
    Map.lookup "a" (eval "let a = 1 / (2 - 2)\n") `shouldBe` Just (Left DivisionByZero)
```

`div`は0で割ると例外を投げるので，テストは例外で失敗する．

```text
  1) Calc.Eval.evalProgram reports a division by zero
       uncaught exception: ArithException
       divide by zero
```

割る前に0かを調べる．
パターンの順序が大事で，`Div _ 0`を`Div a b`より前に書く．

```haskell
apply :: Op -> Integer -> Integer -> Either EvalError Integer
apply Add a b = Right (a + b)
apply Sub a b = Right (a - b)
apply Mul a b = Right (a * b)
apply Div _ 0 = Left DivisionByZero
apply Div a b = Right (a `div` b)
```

未定義の変数と，失敗の伝わり方のテストは，この実装で通る．

### 4. 二重定義

```haskell
  it "keeps the value of the first definition of a name" $
    Map.lookup "a" (eval "let a = 1\nlet a = 2\n") `shouldBe` Just (Right 1)
```

`Map.insert`は同じキーの値を置き換えるので，2回目の定義の値になる．

```text
  1) Calc.Eval.evalProgram keeps the value of the first definition of a name
       expected: Just (Right 1)
        but got: Just (Right 2)
```

すでにある名前は加えない．

```haskell
  define values (Statement name _ expr)
    | name `Map.member` values = values
    | otherwise = Map.insert name (evalExpr values expr) values
```

### 5. 位置(`Calc.Query`)

文の名前と式の変数を，名前と`Span`の組の一覧にして，位置を含む最初のものを返す．

```haskell
nameAt :: Int -> Int -> [Statement] -> Maybe Text
nameAt line column statements =
  listToMaybe
    [name | (name, location) <- concatMap names statements, location `contains` (line, column)]
 where
  names (Statement name location expr) = (name, location) : variables expr
```

`variables`は`Calc.Check`と同じ定義である．
`Calc.Check`は公開していないので，`Calc.Query`に同じ関数を書いた．

名前の直後のテストで，終わりの列を含めていると失敗する．

```text
  1) Calc.Query.nameAt finds nothing just after a name
       expected: Nothing
        but got: Just "price"
```

`Span`の終わりの列は含まないので，`c < end`にする．

```haskell
-- | Whether a position is on one of the characters of a span.
contains :: Span -> (Int, Int) -> Bool
contains (Span line start end) (l, c) = line == l && start <= c && c < end
```

### 6. 変換

```haskell
-- | The line and the column of a position.
fromPosition :: Position -> (Int, Int)
fromPosition (Position line character) = (fromIntegral line, fromIntegral character)

-- | The text shown when hovering over a name.
hoverText :: Text -> Either EvalError Integer -> Text
hoverText name (Right value) = name <> " = " <> T.pack (show value)
hoverText name (Left err) = name <> ": cannot evaluate (" <> reason err <> ")"
 where
  reason DivisionByZero = "division by zero"
  reason (UndefinedVariable var) = "undefined variable '" <> var <> "'"
```

### 7. ホバーのハンドラ

```haskell
  it "shows the value of the variable under the cursor" $ do
    hover <- hoverOn (Position 1 4)
    fmap (^. L.contents) hover `shouldBe` Just (InL (MarkupContent MarkupKind_PlainText "tax = 96"))
```

`hoverOn`は，テストのファイルの`where`で定義した，文書を開いて指定の位置のホバーを求める補助の関数である．
ハンドラがないので，サーバは`MethodNotFound`のエラーを返す．

```text
  1) Hover.textDocument/hover shows the value of the variable under the cursor
       uncaught exception: SessionException
       Received an expected error in a response for id IdInt 1:
       TResponseError {_code = InR ErrorCodes_MethodNotFound, _message = "No handler for:  SMethod_TextDocumentHover", _xdata = Nothing}
```

リクエストハンドラを足す．
文書の取得はLSPの処理なのでハンドラに置き，そこから先は`VirtualFile`を受け取る`hoverAt`にした．

```haskell
    , requestHandler SMethod_TextDocumentHover $ \request respond -> do
        let params = request ^. L.params
        file <- getVirtualFile (toNormalizedUri (params ^. L.textDocument . L.uri))
        respond (Right (maybe (InR Null) InL (hoverAt (fromPosition (params ^. L.position)) =<< file)))
```

```haskell
-- | The value of the name at a position in a document.
hoverAt :: (Int, Int) -> VirtualFile -> Maybe Hover
hoverAt (line, column) contents = do
  let (_problems, statements) = parseProgram (virtualFileText contents)
  name <- nameAt line column statements
  value <- Map.lookup name (evalProgram statements)
  pure (Hover (InL (MarkupContent MarkupKind_PlainText (hoverText name value))) Nothing)
```

残りの2つの統合テストは，この実装で通る．
定義されていない変数の上では，`nameAt`は名前を返すが，`Map.lookup`が`Nothing`になるので何も表示しない．

## 3-6 振り返り

1. 模範解答の評価のテストは10項目である．二重定義の項目は，`Map.insert`が置き換えることに気付かないと書けない．
2. `case`で書くと，被演算子ごとに`Left`と`Right`で分ける必要があり，2段の入れ子になる．

   ```haskell
   evalExpr values (BinOp op left right) =
     case evalExpr values left of
       Left err -> Left err
       Right a -> case evalExpr values right of
         Left err -> Left err
         Right b -> apply op a b
   ```

   `do`は，この「`Left`なら止める」をまとめて書く書き方である．
3. 0での割り算のテストが`ArithException`で失敗する．`div`は0で割ると例外を投げる．`Either`で失敗を返す関数の中で例外を投げると，呼び出し側で扱えない．
4. 式の変数を集める`variables`が，`Calc.Check`と`Calc.Query`に同じ形である．どちらも「文書の中の名前と，その位置」を必要としている．Iteration 4で，名前の定義と使用の一覧を一度作るモジュールにまとめる．
5. 実装の途中で，`Calc.Eval`の`evalExpr`と`apply`，`Calc.Query`の`variables`と`contains`，`Lsp.Server`の`hoverAt`を加えた．どれも公開していない．`hoverAt`の流れを`code-flow.md`に描いた．

## 3-7 発展課題

テストリストに，式を文字列に戻す関数`render :: Expr -> Text`の項目を足す．

- 数と変数はそのまま
- `1 + 2 * 3`は括弧なし
- `(1 + 2) * 3`は括弧付き
- `1 - (2 - 3)`は括弧付き，`(1 - 2) - 3`は括弧なし

括弧が必要なのは，子の演算子が親より弱い場合と，右の子が親と同じ強さの場合である．
`hoverText`に式を渡すと，`Lsp.Convert`が`Calc.Syntax`の`Expr`も使うようになる．
