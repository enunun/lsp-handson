# Iteration 3のノート：リクエストとレスポンス，`Map`と`Either`

Iteration 3では，変数にカーソルを重ねると値を表示する．
このノートでは，LSPのリクエストとレスポンス，`lsp`ライブラリのリクエストハンドラと`|?`型，`Data.Map`，`Either`と`Maybe`を`do`でつなぐ書き方，hspecでテストを絞り込む方法を説明する．

## リクエストとレスポンス

これまでのハンドラは，通知(`didOpen`，`didChange`)を受け取るものだった．
通知には応答がない．
ホバーはリクエストで，エディタは同じ`id`のレスポンスを待つ．

```text
エディタ → サーバ  {"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///workspaces/u3.calc"},"position":{"line":1,"character":5}}}
サーバ → エディタ  {"jsonrpc":"2.0","id":2,"result":{"contents":{"kind":"plaintext","value":"tax = 96"}}}
```

上の2行は，実際に交わしたメッセージから`Content-Length`ヘッダを除いたものである．

- `position`の`line`と`character`は0から数える．`character`の単位は，既定ではUTF-16の符号単位である．
- 表示するものがなければ，`result`に`null`を返す．エラーではない．
- サーバがそのメソッドのハンドラを持たなければ，`lsp`ライブラリは`MethodNotFound`のエラーレスポンスを返す．

## リクエストハンドラ

リクエストのハンドラは`requestHandler`で作る．
通知のハンドラと違い，2つ目の引数に，レスポンスを送る関数(responder)を受け取る．

```haskell
requestHandler SMethod_TextDocumentHover $ \request respond -> do
  let params = request ^. L.params
  ...
  respond (Right result)
```

- `respond`には`Either`を渡す．`Right`は成功の結果，`Left`はエラーレスポンス(`TResponseError`)である．
- 結果の型はメソッドで決まる．ホバーなら`Hover |? Null`である．
- `respond`は，1つのリクエストにつき1回だけ呼ぶ．

`lsp`ライブラリは，登録されたハンドラから`initialize`のcapabilitiesを作る．
ホバーのハンドラを登録すると，`hoverProvider`が自動で加わる．

## `|?`型

LSPには「AかBのどちらか」という型が多い．
`lsp-types`では，これを`A |? B`と書き，`InL`(左)か`InR`(右)で値を作る．

```text
ghci> :type InL
InL :: a -> a |? b
ghci> x = InL (MarkupContent MarkupKind_PlainText "tax = 96") :: MarkupContent |? Null
ghci> x
InL (MarkupContent {_kind = MarkupKind_PlainText, _value = "tax = 96"})
ghci> y = InR Null :: MarkupContent |? Null
ghci> y
InR Null
```

`Null`は，JSONの`null`を表す型である．
ホバーの結果は次のように作る．

```haskell
Hover (InL (MarkupContent MarkupKind_PlainText "tax = 96")) Nothing
```

- `Hover`の1つ目の引数は表示する内容で，`MarkupContent`(プレーンテキストかMarkdown)を`InL`で包む．
- 2つ目の引数は，ホバーの対象の範囲(`Maybe Range`)である．`Nothing`なら，エディタがカーソルの下の語を使う．

ホバーがないときは`InR Null`を返す．
`maybe (InR Null) InL`で，`Maybe Hover`を`Hover |? Null`に変えられる．

## `Data.Map`

`Data.Map.Strict`は，キーから値を引く辞書である．
`containers`パッケージにある．

```text
ghci> import Data.Map.Strict qualified as Map
ghci> prices = Map.fromList [("apple", 120), ("melon", 980 :: Int)] :: Map.Map Text Int
ghci> Map.lookup "apple" prices
Just 120
ghci> Map.lookup "grape" prices
Nothing
ghci> Map.member "melon" prices
True
ghci> Map.insert "grape" 450 prices
fromList [("apple",120),("grape",450),("melon",980)]
ghci> Map.insert "apple" 100 prices
fromList [("apple",100),("melon",980)]
```

- `Map.lookup`は，キーがなければ`Nothing`を返す．
- `Map.insert`は，同じキーがあれば値を置き換える．元の`Map`は変わらない．
- `Map.empty`は空の辞書である．

## `Either`を`do`でつなぐ

`Either e a`は，失敗(`Left e`)か成功(`Right a`)を表す．
`do`の中で`<-`を使うと，`Right`なら中身を取り出して先へ進み，`Left`ならそこで止まって，その`Left`が全体の結果になる．

```text
ghci> safeDiv a b = if b == 0 then Left "division by zero" else Right (a `div` b) :: Either String Integer
ghci> do { x <- safeDiv 10 2; y <- safeDiv x 0; pure (x + y) }
Left "division by zero"
ghci> do { x <- safeDiv 10 2; y <- safeDiv x 1; pure (x + y) }
Right 10
```

評価器では，2つの被演算子を計算し，どちらかが失敗すれば，その失敗をそのまま伝える．

```haskell
evalExpr values (BinOp op left right) = do
  a <- evalExpr values left
  b <- evalExpr values right
  apply op a b
```

## `Maybe`を`do`でつなぐ

`Maybe`も同じように`do`でつなげる．
どこかで`Nothing`になれば，全体が`Nothing`になる．

```text
ghci> do { a <- Map.lookup "apple" prices; m <- Map.lookup "melon" prices; pure (a + m) }
Just 1100
ghci> do { a <- Map.lookup "apple" prices; g <- Map.lookup "grape" prices; pure (a + g) }
Nothing
```

`do`の中では，`let`で途中の値に名前を付けられる．
`let`の行は`<-`と違い，失敗しない計算である．

`=<<`は，`Maybe a`を「`a`を受け取って`Maybe b`を返す関数」に渡す．
`hoverAt position =<< file`は，`file`が`Just`のときだけ`hoverAt position`を使う．

## 整数の割り算

`div`は小数部分を小さいほうへ丸め，`quot`は0の方向へ丸める．
正の数では同じ結果になり，負の数で違いが出る．

```text
ghci> 7 `div` 2 :: Integer
3
ghci> (-7) `div` 2 :: Integer
-4
ghci> (-7) `quot` 2 :: Integer
-3
```

0で割ると，`div`は例外(`ArithException: divide by zero`)を投げる．
評価器では，割る前に0かを調べ，`Left DivisionByZero`を返す．

## テストを名前で絞り込む

hspecのテストは，`--match`で名前の一部を指定して絞り込める．
cabalから渡すときは，`--test-options`を使う．

```sh
cabal test calc-lsp-iter3-exercise:test:unit --test-options='--match "Calc.Eval"'
```

`describe`と`it`の名前は`/`でつながる．
失敗したテストの`To rerun use:`の行にある`--match`を使えば，そのテストだけを実行できる．

## lsp-testでホバーを確かめる

`getHover document position`は，ホバーのリクエストを送り，結果を`Maybe Hover`で返す．
`null`なら`Nothing`である．
ホバーの内容は`^. L.contents`で取り出す．

## REPLの課題

`cabal repl calc-lsp-iter3-exercise`で，次を試す．

1. `Map.fromList`に同じキーを2回含む一覧を渡すと，どちらの値が残るか．
2. `safeDiv`を使い，`100 / 5 / 0 / 2`を左から順に計算する`do`を書く．結果はどうなるか．
3. `InL 1 :: Int |? Bool`と`InR True :: Int |? Bool`を作り，表示する．
