# Iteration 6の解説：リネームする

演習の各段階について，模範解答と考え方を示す．

## 6-1 準備

引き継いだテストは，単体テストが77個，統合テストが14個である．
Iteration 5のサーバは`renameProvider`を宣言しないので，エディタはリネームを要求しない．

## 6-2 文法と概念

REPLの課題の結果は次のとおりである．

```text
ghci> quickCheck (\xs -> sort (sort xs) == sort (xs :: [Int]))
+++ OK, passed 100 tests.
ghci> quickCheck (\n -> n + 1 > (n :: Int))
+++ OK, passed 100 tests.
ghci> quickCheck (forAll (elements ['a' .. 'z']) isAsciiLower)
+++ OK, passed 100 tests.
```

2つ目の性質は，`n`が`Int`の最大値(`maxBound`)のときに成り立たない(`maxBound + 1`は最小値に戻る)．
それでも100回のテストが通るのは，QuickCheckが小さな値を中心に試すからである．
性質のテストは，反例を見つけたときに誤りを示せるが，通ったことは性質が正しい証明にはならない．

## 6-3 テストリスト

模範解答は[TESTLIST.md](../TESTLIST.md)にある．

- 名前の規則は`isValidName`のテストで確かめ，`renameEdits`のテストでは断る場合の代表(規則違反，`let`，定義済み)だけを確かめる．
- 「編集を適用すると，名前だけが変わった文書になる」は，性質のテストの補助の関数(`renameIn`)を例で確かめる項目でもある．
- 性質のテストは1つで，「変えてから戻すと元に戻る」である．新しい名前は，規則に合い，すでに定義された名前(`tax`)と`let`を除いたものを作る．
- 統合テストは，2つのリクエストのそれぞれで，結果がある場合とない場合を確かめる．

## 6-4 設計文書

| 文書 | 変えたこと | 理由 |
| --- | --- | --- |
| [c4-context.md](../design/c4-context.md) | リネームの要求と「文書の編集，またはエラー」を足した．サーバが文書を書き換えないことを図の下に書いた | 編集はエディタが適用するという，LSPの役割分担を示すため |
| [c4-component.md](../design/c4-component.md) | `Calc.Rename`を足した．`Calc.Rename`は`Calc.Parser`(`isValidName`)と`Calc.Query`(`definitionOf`)を使う | 名前の規則を`Calc.Parser`の1か所に保つため |
| [code-flow.md](../design/code-flow.md) | リネームの流れを4つ目の図にし，`renameEdits`の成功と失敗の行き先を描いた | 失敗が`TResponseError`になることを示すため |
| [lsp-sequence.md](../design/lsp-sequence.md) | `prepareRename`と`rename`を足し，成功とエラーを`alt`で分けた．成功のあとにエディタが文書を編集することを`Note`で書いた | 2つのリクエストの順序と，編集の主体を示すため |

## 6-5 テストファーストの実装

### 1. `isValidName`

規則は`Calc.Parser`の`name`パーサにすでに書かれている．
`name <* eof`で文字列全体を読めれば，規則に合う．

```haskell
-- | Whether a text can be used as a name: it follows the rule of names and is not @let@.
isValidName :: Text -> Bool
isValidName candidate = candidate /= "let" && isRight (parse (name <* eof) "" candidate)
```

`let`を断る項目は，`candidate /= "let"`がないと失敗する．
`name`パーサにとって，`let`は英字だけの正しい名前だからである．

### 2. `renameEdits`

最初の項目は，すべての出現を置き換えるだけで通る．

```haskell
renameEdits old new occs =
  Right [(occSpan occurrence, new) | occurrence <- occs, occName occurrence == old]
```

規則違反と`let`の項目で`isValidName`のガードを足す．
`let`のガードがない`isValidName`では，`let`への書き換えを返してしまう．

```text
  1) Calc.Rename.renameEdits rejects let as a new name
       expected: Left (InvalidName "let")
        but got: Right [(Span {
                   spanLine = 0,
                   spanStart = 4,
                   spanEnd = 8
                 }, "let"), (Span {
                   spanLine = 1,
                   spanStart = 17,
                   spanEnd = 21
                 }, "let")]
```

定義済みの項目では，`tax`への書き換えを返してしまう．

```text
  1) Calc.Rename.renameEdits rejects a new name that is already defined
       expected: Left (AlreadyDefined "tax")
        but got: Right [(Span {
                   spanLine = 0,
                   spanStart = 4,
                   spanEnd = 8
                 }, "tax"), (Span {
                   spanLine = 1,
                   spanStart = 17,
                   spanEnd = 21
                 }, "tax")]
```

`definitionOf`で定義済みかを調べる．
同じ名前に変える場合は，自分の定義を見つけてしまうので，`new /= old`を条件に加える．

```haskell
renameEdits :: Text -> Text -> [Occurrence] -> Either RenameError [(Span, Text)]
renameEdits old new occs
  | not (isValidName new) = Left (InvalidName new)
  | new /= old && isJust (definitionOf new occs) = Left (AlreadyDefined new)
  | otherwise = Right [(occSpan occurrence, new) | occurrence <- occs, occName occurrence == old]
```

### 3. 編集の適用と性質のテスト

テストのファイルに，リネームして文書に編集を適用する`renameIn`と，正しい新しい名前を作る`newName`を書く．

```haskell
renameIn :: Text -> Text -> Text -> Maybe Text
renameIn old new text = case renameEdits old new (occurrences (snd (parseProgram text))) of
  Left _ -> Nothing
  Right edits -> Just (applyEdits edits text)

-- | Applies edits on single lines. On each line, the edits are applied from the right.
applyEdits :: [(Span, Text)] -> Text -> Text
applyEdits edits text = T.unlines (zipWith editLine [0 ..] (T.lines text))
 where
  editLine lineNo line =
    foldl
      apply
      line
      (sortOn (Down . spanStart . fst) [edit | edit@(s, _) <- edits, spanLine s == lineNo])
  apply line (Span _ start end, new) = T.take start line <> new <> T.drop end line
```

```haskell
-- | Valid names that are not defined in the program, except rate itself.
newName :: Gen Text
newName =
  (T.pack <$> ((:) <$> elements letters <*> listOf (elements (letters <> digits))))
    `suchThat` (`notElem` ["let", "tax"])
 where
  letters = ['a' .. 'z'] <> ['A' .. 'Z']
  digits = ['0' .. '9']
```

まず`renameIn`を例のテスト(`rate`を`taxRate`に変えた文書)で確かめてから，性質を書く．

```haskell
  prop "gives back the program when a name is renamed and renamed back" $
    forAll newName $ \name ->
      (renameIn name "rate" =<< renameIn "rate" name program) === Just program
```

`renameEdits`がすでに正しいので，この性質は最初から通る．
性質が誤りを見つけられることを確かめるため，「新しい名前が5文字以上なら何も書き換えない」という誤りを写しに入れて実行すると，QuickCheckは反例を見つける．

```text
  1) Calc.Rename.renameEdits gives back the program when a name is renamed and renamed back
       Falsified (after 6 tests):
         "XTv7AD"
         Nothing /= Just "let rate = 8\nlet tax = 1200 * rate / 100\n"
```

`XTv7AD`への書き換えが何もしないので，戻すときに`rate`がまだ定義されていて`AlreadyDefined`になる．
例を並べるテストでは，この誤りは`taxRate`(7文字)の項目でも見つかる．
性質のテストは，どんな長さや文字の名前で誤るかを知らなくても見つけられる．

### 4. 変換

```haskell
-- | Edits to one document.
toWorkspaceEdit :: Uri -> [(Span, Text)] -> WorkspaceEdit
toWorkspaceEdit uri edits =
  WorkspaceEdit
    { _changes = Just (Map.singleton uri [TextEdit (toRange location) new | (location, new) <- edits])
    , _documentChanges = Nothing
    , _changeAnnotations = Nothing
    }

-- | The message of an error response to a rename.
renameErrorMessage :: RenameError -> Text
renameErrorMessage (InvalidName name) = "'" <> name <> "' is not a valid name"
renameErrorMessage (AlreadyDefined name) = "'" <> name <> "' is already defined"
```

### 5. ハンドラ

```haskell
    , requestHandler SMethod_TextDocumentPrepareRename $ \request respond -> do
        let params = request ^. L.params
            (line, column) = fromPosition (params ^. L.position)
        statements <- statementsOf (params ^. L.textDocument . L.uri)
        let found = occurrenceAt line column (occurrences statements)
        respond (Right (maybe (InR Null) (InL . PrepareRenameResult . InL . toRange . occSpan) found))
    , requestHandler SMethod_TextDocumentRename $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            (line, column) = fromPosition (params ^. L.position)
        statements <- statementsOf uri
        let occs = occurrences statements
        respond $ case occurrenceAt line column occs of
          Nothing -> Right (InR Null)
          Just occurrence -> case renameEdits (occName occurrence) (params ^. L.newName) occs of
            Left err -> Left (TResponseError (InR ErrorCodes_InvalidParams) (renameErrorMessage err) Nothing)
            Right edits -> Right (InL (toWorkspaceEdit uri edits))
```

統合テストのエラーの項目では，lsp-testの`rename`を使わない．
`rename`はエラーの応答で例外を投げるので，`request SMethod_TextDocumentRename`で応答を受け取り，`^. L.result`の`Left`からメッセージを読む．
テストの中の変数名を`response`にすると，lsp-testの同名の関数を隠すという警告が出るので，`answer`にした．

## 6-6 振り返り

1. 模範解答の単体テストは，名前の規則が3項目，リネームが7項目(性質1つを含む)，変換が2項目である．
2. 性質のテストは，例を並べるテストが思いつかない入力(長い名前，大文字と数字の混じった名前)で誤りを見つけやすい．一方，6-2の`n + 1 > n`のように，QuickCheckがほとんど作らない値(最大値，特定の文字列)でだけ起きる誤りは見つけにくい．境界の値は，例のテストで確かめる．
3. `prepareRename`で`null`を返すと，エディタはリネームの入力欄を開かない．`rename`のエラーは，利用者が新しい名前を入力したあとに，その名前が使えない理由として表示される．
4. 名前の規則を2か所に書くと，片方だけを変えたときに，構文解析で読めない名前へリネームできてしまうことがある．`isValidName`が`name`パーサを使えば，規則は1か所になる．
5. 実装の途中で，`Lsp.Convert`から`containers`(`Map.singleton`)への依存が増えた．`c4-component.md`に描いた．

## 6-7 発展課題

テストリストに，次の項目を足す．

- 未定義のまま使われている名前(`fee`)への書き換えは，`AlreadyUsed "fee"`
- 文書に一度も現れない名前への書き換えは断らない

`renameEdits`のガードで，新しい名前の出現が1つでもあるかを調べる．
`definitionOf`ではなく，`occs`に新しい名前があるかで判定する．
`AlreadyDefined`の判定は，この判定に含まれる．
どちらのエラーを返すかは，定義があるかどうかで分ける．
