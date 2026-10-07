# Iteration 1のノート：診断とレコード

Iteration 1では，`let`の形をしていない行に波線を付ける．
このノートでは，LSPの診断(`textDocument/publishDiagnostics`)と位置の表し方，Haskellのレコード，`Maybe`と`Either`を組み合わせた結果の扱い，`Data.Text`で行を調べる関数を説明する．

## 診断を送る

診断(diagnostic)は，文書の中の誤りや注意をエディタに知らせるものである．
エディタは，診断の範囲に波線を引き，マウスを重ねるとメッセージを見せる．

診断はサーバからの通知`textDocument/publishDiagnostics`で送る．
パラメータは，文書のURI，文書の版，診断の一覧である．

```haskell
sendNotification SMethod_TextDocumentPublishDiagnostics $
  PublishDiagnosticsParams uri (Just version) diagnostics
```

- `publishDiagnostics`は，その文書の診断を「全部」送る．エディタは前に受け取った診断を，新しい一覧で置き換える．
- そのため，誤りが直ったら空の一覧(`[]`)を送る．送らないと，前の波線が残る．
- 版は，`virtualFileVersion`でVFSの文書から取り出せる．エディタは，古い版への診断を捨てられる．

### `Diagnostic`

`Diagnostic`は，次のフィールドを持つレコードである．

| フィールド | 型 | このコースで入れるもの |
| --- | --- | --- |
| `_range` | `Range` | 波線を引く範囲 |
| `_severity` | `Maybe DiagnosticSeverity` | `Just DiagnosticSeverity_Error` |
| `_source` | `Maybe Text` | `Just "calc"`．どのツールの診断かを示す |
| `_message` | `Text` | メッセージ |
| `_code`，`_codeDescription`，`_tags`，`_relatedInformation`，`_data_` | `Maybe …` | `Nothing` |

### `Position`と`Range`

LSPの位置`Position`は，行と列の組である．
どちらも0から数える．
範囲`Range`は，始まりと終わりの`Position`の組で，終わりの位置の文字は含まない．

```text
行1:  price * 2
      ^        ^
      (1, 0)   (1, 9)   → Range (Position 1 0) (Position 1 9)
```

`Position`の行と列の型は`UInt`(符号なし整数)である．
`Int`から変えるときは`fromIntegral`を使う．

列は，既定ではUTF-16の単位で数える．
Calcの名前とキーワードはASCIIの文字だけなので，`Text`の文字数と同じになる．

## レコード

フィールドに名前を付けたデータ型をレコードという．

```haskell
data Span = Span
  { spanLine :: Int
  , spanStart :: Int
  , spanEnd :: Int
  }
  deriving (Eq, Show)
```

- `Span 2 4 9`のように，フィールドの順に値を並べて作れる．
- フィールド名は，そのフィールドを取り出す関数になる(`spanStart :: Span -> Int`)．
- `s {spanEnd = 12}`は，`s`の`spanEnd`だけを変えた新しい値である．元の`s`は変わらない．
- `deriving (Eq, Show)`で，`==`による比較と，`show`による表示ができるようになる．hspecの`shouldBe`は，この2つを使う．
- `Span (..)`のように型名に`(..)`を付けてエクスポートすると，コンストラクタとフィールドも公開される．

```text
ghci> s = Span 2 4 9
ghci> s
Span {spanLine = 2, spanStart = 4, spanEnd = 9}
ghci> spanStart s
4
ghci> s {spanEnd = 12}
Span {spanLine = 2, spanStart = 4, spanEnd = 12}
ghci> stmt = Statement "price" s
ghci> stmtName stmt
"price"
ghci> spanLine (stmtSpan stmt)
2
```

パターンマッチでは，コンストラクタの後ろにフィールドの順で変数を並べる．

```haskell
toRange :: Span -> Range
toRange (Span line start end) = ...
```

## `Maybe`と`Either`を組み合わせる

`parseLine`の結果の型は`Maybe (Either Problem Statement)`である．
3つの場合を1つの型で表している．

| 値 | 意味 |
| --- | --- |
| `Nothing` | 調べる対象ではない(空行，コメント行) |
| `Just (Left problem)` | 誤りがある |
| `Just (Right statement)` | 正しい文である |

一覧に対しては，`Data.Maybe`と`Data.Either`の関数で場合を分ける．

```text
ghci> import Data.Either (partitionEithers)
ghci> import Data.Maybe (mapMaybe)
ghci> partitionEithers [Left ("bad" :: String), Right (1 :: Int), Right 2, Left "worse"]
(["bad","worse"],[1,2])
ghci> mapMaybe (\n -> if even n then Just (n * 10) else Nothing) [1, 2, 3, 4 :: Int]
[20,40]
```

- `mapMaybe f xs`は，各要素に`f`を使い，`Just`の中身だけを集める．
- `partitionEithers`は，`Left`と`Right`をそれぞれの一覧に分ける．順序は保たれる．
- `maybe d f m`は，`m`が`Nothing`なら`d`を，`Just x`なら`f x`を返す．`maybe (Left problem) Right statement`は，`Maybe Statement`を`Either Problem Statement`に変える．

## `Data.Text`で行を調べる

```text
ghci> T.words "  let   price = 1200"
["let","price","=","1200"]
ghci> T.stripStart "  let a = 1"
"let a = 1"
ghci> "--" `T.isPrefixOf` "-- note"
True
ghci> T.uncons "price"
Just ('p',"rice")
ghci> T.uncons ""
Nothing
ghci> zip [0 :: Int ..] (T.lines "let a = 1\nlet b = 2")
[(0,"let a = 1"),(1,"let b = 2")]
```

- `T.words`は空白で区切り，空白そのものは捨てる．
- `T.stripStart`は先頭の空白を除く．元の長さとの差が字下げの幅になる．
- `T.uncons`は，最初の文字と残りに分ける．空なら`Nothing`である．
- `T.all p`は，すべての文字が`p`を満たすかを調べる．
- `zip [0 ..] xs`で，各要素に0からの番号を付ける．`uncurry f`は，2引数の関数`f`を組を受け取る関数に変える．

文字の種類は`Data.Char`の関数で調べる．
`isAsciiLower`，`isAsciiUpper`，`isDigit`はASCIIの英小文字，英大文字，数字を，`isSpace`は空白を判定する．
`isAlpha`はASCII以外の文字(日本語など)も英字とみなすので，名前の判定には使わない．

### パターンマッチとガード

一覧の形と条件を組み合わせて場合を分けられる．

```haskell
case T.words body of
  ("let" : name : "=" : _ : _) | isName name -> ...  -- let，名前，=，1語以上
  _ -> ...
```

- `"let" : name : rest`は，先頭が`"let"`の一覧に一致する．`OverloadedStrings`があれば，`Text`の文字列リテラルもパターンに書ける．
- `_ : _`は「1つ以上の要素」である．
- `| 条件`(ガード)が`False`なら，次の選択肢に進む．

関数の定義にもガードを使える．

```haskell
parseLine lineNo line
  | T.null body = Nothing
  | otherwise = ...
 where
  body = T.stripStart line
```

## 一部のテストだけを実行する

単体テストのスイートだけを実行するには，コンポーネントを`パッケージ:test:スイート名`で指定する．

```sh
cabal test calc-lsp-iter1-exercise:test:unit
```

## lsp-testで診断を待つ

`waitForDiagnostics`は，次の`publishDiagnostics`が届くまでほかのメッセージを読み飛ばし，その診断の一覧を返す．

```haskell
diagnostics <- runCalcSession $ do
  _ <- createDoc "sample.calc" "calc" "price * 2\n"
  waitForDiagnostics
```

`message`は「次に届くメッセージ」がそのメソッドであることを求める．
間にほかの通知が届くときは，`skipManyTill anyMessage (message …)`で読み飛ばしながら待つ．
`skipManyTill`は`Control.Applicative.Combinators`にある．

## REPLの課題

`cabal repl calc-lsp-iter1-exercise`で，次を試す．

1. `T.words`に`"let x=1"`を渡すと，何語になるか．Iteration 1の`parseLine`は，この行をどう扱うことになるか．
2. `Span`の値を作り，レコード更新の構文で`spanLine`だけを変える．
3. `partitionEithers`と`mapMaybe`を使い，`[Just (Left 'a'), Nothing, Just (Right True)]`から`("a", [True])`を作る．
