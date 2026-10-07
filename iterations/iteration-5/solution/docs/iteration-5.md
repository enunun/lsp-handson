# Iteration 5の解説：補完する

演習の各段階について，模範解答と考え方を示す．

## 5-1 準備

引き継いだテストは，単体テストが65個，統合テストが12個である．
Iteration 4のサーバは`completionProvider`を宣言しないので，VS Codeは文書の中の単語だけを候補に出す．

## 5-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> word = T.takeWhileEnd isAlphaNum line
ghci> (T.dropEnd (T.length word) line, word)
("let a = 2 * ","pri")
ghci> nub (map fst [("a", 1), ("b", 2), ("a", 3 :: Int)]) :: [String]
["a","b"]
ghci> LSP.Range (LSP.Position 0 4) (LSP.Position 0 9) & L.end .~ LSP.Position 1 0
Range {_start = Position {_line = 0, _character = 4}, _end = Position {_line = 1, _character = 0}}
```

`line`は`"let a = 2 * pri"`である．

## 5-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- 候補の種類を決める場所(行頭，`let`の入力中，名前の入力中，右辺)を先に並べ，そのあとで右辺の候補の細かい決まりを確かめる．
- テストでは，行の一覧を受け取り，指定した行の末尾で補完する補助の関数`completeOn`と，最後の行で補完する`complete`を作った．カーソルの行と下の行の項目では，補完する行が最後の行ではないので`completeOn`を使う．
- 統合テストは，右辺と行頭の2つである．書きかけの行の扱いは単体テストで確かめる．

## 5-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 補完の要求と候補のやり取りを足した | 新しい機能のため |
| [c4-component.md](../design/c4-component.md) | `Calc.Complete`を足した．`Calc.Complete`から`Calc.Eval`，`Lsp.Convert`から`Calc.Complete`への依存を足した | 候補に値を添えるために評価を使い，候補を`CompletionItem`に変えるため |
| [code-flow.md](../design/code-flow.md) | 補完の流れを3つ目の図にした．候補の種類を決める決まりを図の下に書いた | `candidates`だけが，解析できた文に加えて行の文字列を受け取ることを示すため |
| [lsp-sequence.md](../design/lsp-sequence.md) | `textDocument/completion`を足し，`initialize`の応答に`completionProvider`を書いた | 新しいリクエストのため |

## 5-5 テストファーストの実装

### 1. 行頭の`let`

最初のテストは，空の行の先頭で`let`を出すことである．
空白だけなら`let`を出す形で通る．

```haskell
candidates _ column lineText _
  | T.all isSpace (T.take column lineText) = [Keyword "let"]
  | otherwise = []
```

### 2. `let`の入力中

```haskell
  it "offers let while it is being typed" $
    complete ["let price = 1200", "  le"] `shouldBe` [Keyword "let"]
```

`complete`は，テストのファイルの`where`で定義した，最後の行の末尾で補完する補助の関数である．
カーソルの前の文字列全体を見ていると，2つの空白と`le`からなる文字列は空白だけではないので，候補が出ない．

```text
  1) Calc.Complete.candidates offers let while it is being typed
       expected: [Keyword "let"]
        but got: []
```

カーソルの前の文字列を，入力中の語(`prefix`)と，その前の部分(`before`)に分け，`before`が空白だけかを調べる．
「ほかの語は候補なし」の項目のために，最後に入力中の語で始まる候補だけを残す．

```haskell
candidates line column lineText statements = filter ((prefix `T.isPrefixOf`) . label) offered
 where
  typed = T.take column lineText
  prefix = T.takeWhileEnd isNameChar typed
  before = T.dropEnd (T.length prefix) typed
  offered
    | T.all isSpace before = [Keyword "let"]
    | otherwise = []
```

### 3. 右辺の変数

```haskell
  it "offers the variables defined above after =" $
    complete ["let price = 1200", "let pages = 30", "let total = "]
      `shouldBe` [Variable "price" (Right 1200), Variable "pages" (Right 30)]
```

`before`に`=`が含まれていれば右辺である．
変数は，文の名前と`evalProgram`の値から作る．

```haskell
    | "=" `T.isInfixOf` before = variablesAbove line statements
```

### 4. 入力中の語で絞る

```haskell
  it "keeps only the variables that start with the word being typed" $
    complete ["let price = 1200", "let tax = 96", "let total = 2 * p"]
      `shouldBe` [Variable "price" (Right 1200)]
```

2で足した`filter`がなければ，すべての変数が候補になる．

```text
  1) Calc.Complete.candidates keeps only the variables that start with the word being typed
       expected: [Variable "price" (Right 1200)]
        but got: [Variable "price" (Right 1200), Variable "tax" (Right 96)]
```

名前の入力中(`let p`)の項目は最初から通る．`before`は`let`と空白1つで，空白だけでもなく，`=`も含まないからである．

### 5. カーソルの行と下の行

```haskell
  it "leaves out the variables defined on the line and below" $
    completeOn 1 ["let price = 1200", "let total = p", "let pages = 30"]
      `shouldBe` [Variable "price" (Right 1200)]
```

すべての文の名前を使っていると，下の行の`pages`も候補になる．

```text
  1) Calc.Complete.candidates leaves out the variables defined on the line and below
       expected: [Variable "price" (Right 1200)]
        but got: [Variable "price" (Right 1200), Variable "pages" (Right 30)]
```

カーソルの行より上の文だけを使う．
評価も上の文だけで行う．

```haskell
-- | The variables defined on the lines above a line, in the order of their first definitions.
variablesAbove :: Int -> [Statement] -> [Candidate]
variablesAbove line statements =
  [Variable name value | name <- nub (map stmtName above), Just value <- [Map.lookup name values]]
 where
  above = filter (\statement -> spanLine (stmtSpan statement) < line) statements
  values = evalProgram above
```

書きかけの行(括弧が閉じていない行)の項目は，この実装で最初から通る．
解析できない行は文にならないが，候補に必要な情報(上の行の文と，カーソルの前の文字列)はそろっている．

### 6. 二重定義

```haskell
  it "offers a name defined twice once, with its first value" $
    complete ["let a = 1", "let a = 2", "let b = "] `shouldBe` [Variable "a" (Right 1)]
```

`nub`がなければ，同じ名前が2回出る．
値はどちらも`evalProgram`が最初の定義から求めた1である．

```text
  1) Calc.Complete.candidates offers a name defined twice once, with its first value
       expected: [Variable "a" (Right 1)]
        but got: [Variable "a" (Right 1), Variable "a" (Right 1)]
```

値が計算できない変数の項目は，`evalProgram`の`Left`をそのまま候補に入れているので，最初から通る．

### 7. `toCompletionItem`

```haskell
-- | A completion item. A variable shows its value, as in a hover.
toCompletionItem :: Candidate -> CompletionItem
toCompletionItem (Keyword word) = plainItem word & L.kind ?~ CompletionItemKind_Keyword
toCompletionItem (Variable name value) =
  plainItem name & L.kind ?~ CompletionItemKind_Variable & L.detail ?~ hoverText name value
```

`plainItem`は，19個のフィールドのうち`_label`だけを設定し，ほかを`Nothing`にしたひな形である([src/Lsp/Convert.hs](../src/Lsp/Convert.hs))．

### 8. 補完のハンドラ

```haskell
    , requestHandler SMethod_TextDocumentCompletion $ \request respond -> do
        let params = request ^. L.params
            (line, column) = fromPosition (params ^. L.position)
        file <- getVirtualFile (toNormalizedUri (params ^. L.textDocument . L.uri))
        let text = maybe "" virtualFileText file
            lineText = case drop line (T.lines text) of
              current : _ -> current
              [] -> ""
            (_problems, statements) = parseProgram text
        respond (Right (InL (map toCompletionItem (candidates line column lineText statements))))
```

文書が改行で終わると，最後の改行のあとの行(カーソルを置ける空の行)は`T.lines`の結果に含まれず，行番号が一覧の外になる．
`drop`のあとにパターンマッチして，その場合を空の行として扱う．

## 5-6 振り返り

1. 模範解答の`candidates`の項目は10個で，そのうち4つは最初から通った．最初から通る項目は，書きかけの行や値の失敗のように，設計(行の文字列を受け取る，`Either`をそのまま渡す)の結果として成り立つ振る舞いを記録している．
2. `candidates`は，解析できた文に加えて，カーソルのある行の文字列を受け取る．文だけだと，書きかけの行は文にならないので，カーソルの位置が行頭と右辺のどちらにあり，入力中の語が何であるかが分からない．
3. レコード構文だけで作ると，2種類の候補ごとに19個のフィールドを並べることになる．ひな形とlensなら，候補ごとの違い(種類と詳細)だけが読める．
4. エディタの絞り込みに任せると，候補が多い文書では，毎回すべての変数の値を計算して送ることになる．また，エディタによって絞り込み方が違う．サーバで絞れば，送る量が減り，どのエディタでも同じ候補になる．
5. 実装の途中で，`Calc.Complete`に`variablesAbove`，`label`，`isNameChar`を加えた．`isNameChar`は`Calc.Parser`にも同じ定義がある．`code-flow.md`の3つ目の図の下に，候補の種類の決まりを書いた．

## 5-7 発展課題

テストリストに，次の項目を足す．

- `let x = (`の直後でも，すべての変数を出す
- 行頭で`(`を入力しても，`let`は出さない

`serverDefinition`の`options`で`optCompletionTriggerCharacters = Just ['(']`を設定すると，`initialize`の応答の`completionProvider`に`triggerCharacters`が加わる．
`candidates`は，入力中の語が空でも右辺なら変数を出すので，変更はいらない．
