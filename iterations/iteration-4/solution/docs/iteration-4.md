# Iteration 4の解説：定義と参照をたどる

演習の各段階について，模範解答と考え方を示す．

## 4-1 準備

引き継いだテストは，単体テストが54個，統合テストが8個である．
Iteration 3のサーバは`definitionProvider`と`referencesProvider`を宣言しないので，エディタは定義や参照を要求しない．

## 4-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> find ((== "a") . fst) [("a", 1), ("b", 2), ("a", 3 :: Int)] :: Maybe (String, Int)
Just ("a",1)
ghci> filter ((== "a") . fst) [("a", 1), ("b", 2), ("a", 3 :: Int)] :: [(String, Int)]
[("a",1),("a",3)]
ghci> params ^. L.context . L.includeDeclaration
False
ghci> location ^. L.range . L.start . L.line
2
```

`params`と`location`は，ノートの例と同じ形で作った値である(`location`の範囲は2行目)．

## 4-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- `occurrences`の並び順をテストで決めた．各文で使用を先に，定義をあとに並べる．この順なら，`Calc.Check`は「使用はそれより前の定義だけを見る」という決まりを，一覧を1回たどるだけで実装できる．
- `Calc.Check`とホバーのテストは変えない．リファクタリングで振る舞いが変わっていないことを，これらのテストで確かめる．
- `nameAt`のテストは，呼び方だけを`occurrenceAt`に変える．確かめる位置と名前は同じである．
- 定義と参照の両方で，2回定義された名前と，定義されていない名前を確かめる．

## 4-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | 「定義・参照の要求(位置)」と「定義と参照の場所」のやり取りを足した | エディタの移動と一覧の機能が加わったため |
| [c4-component.md](../design/c4-component.md) | `Calc.Resolve`を足し，`Calc.Check`と`Calc.Query`が`Calc.Resolve`を使うようにした．`Lsp.Server`から`Calc.Resolve`と`Calc.Syntax`への依存を足した | 式の木をたどるのが`Calc.Resolve`と`Calc.Eval`だけになったことを示すため．`Lsp.Server`は`Statement`と`Occurrence`を受け渡す |
| [code-flow.md](../design/code-flow.md) | 位置を受け取る3つの機能を，`[Occurrence]`を中心にした1つの図にまとめた | 3つの機能が同じ表を検索していることを示すため |
| [lsp-sequence.md](../design/lsp-sequence.md) | `textDocument/definition`と`textDocument/references`を足し，`initialize`の応答に2つのproviderを書いた | 新しいリクエストと，capabilitiesの変化を示すため |

## 4-5 テストファーストの実装

### 1. 出現の一覧(`Calc.Resolve`)

空のプログラム，定義だけの文，使用を含む文の順にテストを足し，最後に並び順のテストを書く．

```haskell
  it "lists the uses of a statement before its definition, and the statements in order" $
    resolve "let a = 1\nlet b = a\n"
      `shouldBe` [ Occurrence "a" (Span 0 4 5) Definition
                 , Occurrence "a" (Span 1 8 9) Use
                 , Occurrence "b" (Span 1 4 5) Definition
                 ]
```

```haskell
{- | Every occurrence of a name, in the order of evaluation: for each statement, the variables of
its expression from left to right, then the name it defines.
-}
occurrences :: [Statement] -> [Occurrence]
occurrences = concatMap statementOccurrences
 where
  statementOccurrences (Statement name location expr) =
    uses expr <> [Occurrence name location Definition]

uses :: Expr -> [Occurrence]
uses (Number _) = []
uses (Var name location) = [Occurrence name location Use]
uses (BinOp _ left right) = uses left <> uses right
```

### 2. `Calc.Check`の書き換え

テストを変えずに，中身を`occurrences`の結果をたどる形にする．

```haskell
-- | Reports variables used before their definition, and names defined twice.
checkProgram :: [Statement] -> [Problem]
checkProgram statements = concat (snd (mapAccumL check Set.empty (occurrences statements)))

-- | Checks one occurrence against the names defined before it.
check :: Set Text -> Occurrence -> (Set Text, [Problem])
check defined (Occurrence name location Use)
  | name `Set.member` defined = (defined, [])
  | otherwise = (defined, [Problem location ("undefined variable '" <> name <> "'")])
check defined (Occurrence name location Definition)
  | name `Set.member` defined = (defined, [Problem location ("'" <> name <> "' is already defined")])
  | otherwise = (Set.insert name defined, [])
```

並び順の大切さは，`occurrences`を行の左から右の順(定義が先)にしてみると分かる．
引き継いだ`Calc.Check`のテストのうち2つが失敗する．

```text
  1) Calc.Check.checkProgram reports a variable used in its own definition
       expected: [Problem {problemSpan = Span {spanLine = 0, spanStart = 8, spanEnd = 9}, problemMessage = "undefined variable 'a'"}]
        but got: []
```

`let a = a + 1`で，`a`の定義を先に集合へ入れてしまうので，右辺の`a`を定義済みとみなしてしまう．
もう1つの失敗は，同じ行の問題の順(未定義の変数，二重定義)が入れ替わることである．

### 3. 位置の検索(`occurrenceAt`)

`nameAt`のテストを，`occurrenceAt`の結果の名前を確かめる形に書き換える．

```haskell
    it "finds the name of a definition" $
      occName <$> at 0 4 `shouldBe` Just "price"
```

`at`は，テストのファイルの`where`で定義した，例のプログラムの出現から位置を引く補助の関数である．
実装は`find`で，位置を含む最初の出現を返す．

```haskell
occurrenceAt :: Int -> Int -> [Occurrence] -> Maybe Occurrence
occurrenceAt line column = find (\occurrence -> occSpan occurrence `contains` (line, column))
```

### 4. `definitionOf`

```haskell
-- | The first definition of a name.
definitionOf :: Text -> [Occurrence] -> Maybe Occurrence
definitionOf name = find (\occurrence -> occName occurrence == name && occKind occurrence == Definition)
```

`find`は最初に見つかったものを返すので，2回定義された名前の項目と，定義されていない名前の項目は，この実装で通る．

### 5. `referencesOf`

使用だけを集める項目と，定義も含める項目は，`filter`で通る．

```haskell
referencesOf includeDefinitions name occs = filter wanted occs
 where
  wanted occurrence =
    occName occurrence == name && (occKind occurrence == Use || includeDefinitions)
```

定義されていない名前の項目で失敗する．

```text
  1) Calc.Query.referencesOf finds nothing for a name that is not defined
       expected: []
        but got: [Occurrence {occName = "fee", occSpan = Span {spanLine = 2, spanStart = 26, spanEnd = 29}, occKind = Use}]
```

定義がなければ空にする．

```haskell
referencesOf :: Bool -> Text -> [Occurrence] -> [Occurrence]
referencesOf includeDefinitions name occs = case definitionOf name occs of
  Nothing -> []
  Just _ -> filter wanted occs
 where
  wanted occurrence =
    occName occurrence == name && (occKind occurrence == Use || includeDefinitions)
```

### 6. `toLocation`

```haskell
-- | A span in a document.
toLocation :: Uri -> Span -> Location
toLocation uri location = Location uri (toRange location)
```

### 7. 定義のハンドラ

```haskell
  it "goes from a variable to its definition" $ do
    (document, definitions) <- definitionsAt (Position 2 13)
    definitions
      `shouldBe` InL (Definition (InL (Location (document ^. L.uri) (Range (Position 0 4) (Position 0 9)))))
```

`definitionsAt`は，テストのファイルの`where`で定義した，文書を開いて定義を求める補助の関数である．
ハンドラがないので，`MethodNotFound`で失敗する．

```text
  1) Definition.textDocument/definition goes from a variable to its definition
       uncaught exception: SessionException
       Received an expected error in a response for id IdInt 1:
       TResponseError {_code = InR ErrorCodes_MethodNotFound, _message = "No handler for:  SMethod_TextDocumentDefinition", _xdata = Nothing}
```

3つのハンドラが文書の文の一覧を使うので，それを取り出す`statementsOf`を作り，ホバーのハンドラもこれを使う形に書き換えた．

```haskell
-- | The statements of an open document. A document that is not open has none.
statementsOf :: Uri -> LspM () [Statement]
statementsOf uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  pure (maybe [] (snd . parseProgram . virtualFileText) file)
```

```haskell
    , requestHandler SMethod_TextDocumentDefinition $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
        statements <- statementsOf uri
        let found = definitionAt (fromPosition (params ^. L.position)) statements
        respond (Right (maybe (InR (InR Null)) (InL . Definition . InL . toLocation uri . occSpan) found))
```

```haskell
-- | The definition of the name at a position.
definitionAt :: (Int, Int) -> [Statement] -> Maybe Occurrence
definitionAt (line, column) statements = do
  let occs = occurrences statements
  occurrence <- occurrenceAt line column occs
  definitionOf (occName occurrence) occs
```

`Lsp.Server`は`Calc.Resolve`から`Occurrence (..)`と`occurrences`だけをimportする．
`OccKind`の`Definition`を見えなくすることで，`lsp-types`の`Definition`と衝突しない．

### 8. 参照のハンドラ

```haskell
    , requestHandler SMethod_TextDocumentReferences $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            includeDefinitions = params ^. L.context . L.includeDeclaration
        statements <- statementsOf uri
        let found = referencesAt includeDefinitions (fromPosition (params ^. L.position)) statements
        respond (Right (InL (map (toLocation uri . occSpan) found)))
```

```haskell
-- | The references to the name at a position.
referencesAt :: Bool -> (Int, Int) -> [Statement] -> [Occurrence]
referencesAt includeDefinitions (line, column) statements =
  let occs = occurrences statements
   in maybe
        []
        (\occurrence -> referencesOf includeDefinitions (occName occurrence) occs)
        (occurrenceAt line column occs)
```

最後に統合テストをすべて実行し，診断，ホバー，ログのテストが変わらず通ることを確かめた．

## 4-6 振り返り

1. 模範解答で新しく足した単体テストは11項目である．並び順のテストは，`Calc.Check`のための決まりを`Calc.Resolve`のテストに書き残している．
2. 4-5の2で示したとおり，`Calc.Check`の2つのテストが失敗する．自分の定義の中で使った変数を未定義と判定できなくなり，同じ行の問題の順が入れ替わる．
3. `Calc.Check`の6つのテストは，名前の検査の振る舞い(どの位置にどのメッセージが出るか)を確かめている．テストを1つも変えずに通ったことで，内部の作りを変えても，利用者から見える診断は変わっていないと言える．
4. 式の木をたどるのは`Calc.Resolve`(`uses`)と`Calc.Eval`(`evalExpr`)の2つになった．単項のマイナスを足すときは，この2つと`Calc.Parser`を直す．
5. 実装の途中で，`Lsp.Server`に`statementsOf`，`definitionAt`，`referencesAt`を加え，`hoverAt`の引数を`VirtualFile`から`[Statement]`に変えた．`code-flow.md`の2つ目の図の`Uri -->|"statementsOf"|`がこれにあたる．

## 4-7 発展課題

テストリストに，次の項目を足す．

- 変数の上で，同じ名前の出現をすべて強調する
- 定義は`DocumentHighlightKind_Write`，使用は`DocumentHighlightKind_Read`
- 定義されていない名前でも，使用を強調する(参照と違い，未定義でも見つけた出現は示す)

ハンドラは`SMethod_TextDocumentDocumentHighlight`で，結果の型は`[DocumentHighlight] |? Null`である．
出現の種類から強調の種類への変換は`Lsp.Convert`に置く．
