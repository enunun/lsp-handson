# Iteration 5のノート：補完と書きかけの入力

Iteration 5では，入力中の語を補う候補を出す．
このノートでは，LSPの補完(`textDocument/completion`)と`CompletionItem`，書きかけで解析できない入力の扱い方，候補を作るための`Data.Text`と一覧の関数，lensでレコードの一部のフィールドを設定する書き方を説明する．

## 補完のリクエスト

エディタは，利用者が語を入力している間や，補完の操作(VS Codeでは`Ctrl+Space`)をしたときに，`textDocument/completion`を送る．
パラメータは文書と位置で，位置はカーソルの位置(入力中の語の直後)である．

結果の型は`[CompletionItem] |? (CompletionList |? Null)`で，候補の一覧は`InL`で返す．
エディタは，受け取った候補を入力中の語でさらに絞り込み，並べ替えて表示する．

補完のハンドラを登録すると，`lsp`ライブラリがcapabilitiesに`completionProvider`を加える．

## `CompletionItem`

`CompletionItem`は，1つの候補を表すレコードで，19個のフィールドを持つ．
このコースで使うのは3つである．

| フィールド | 意味 |
| --- | --- |
| `_label` | 候補の名前．選ぶと，この文字列が入力される |
| `_kind` | 候補の種類(`CompletionItemKind_Keyword`，`CompletionItemKind_Variable`など)．エディタはアイコンを変える |
| `_detail` | 候補の横に出る補足 |

ほかのフィールドはすべて`Nothing`にしてよい．

## lensでフィールドを設定する

フィールドの多いレコードは，「すべてが`Nothing`のひな形」を1つ作り，必要なフィールドだけをlensで設定すると読みやすい．

| 書き方 | 意味 |
| --- | --- |
| `x & f` | `f x`と同じ．左から右へ読める |
| `x & l .~ v` | `x`の，lens `l`が指すフィールドを`v`にした値 |
| `x & l ?~ v` | `x & l .~ Just v`と同じ．`Maybe`のフィールドに使う |
| `x ^. l` | `x`の，lens `l`が指すフィールドの値 |

```text
ghci> import Control.Lens ((&), (?~), (.~), (^.))
ghci> import Language.LSP.Protocol.Lens qualified as L
ghci> import Language.LSP.Protocol.Types qualified as LSP
ghci> range = LSP.Range (LSP.Position 0 4) (LSP.Position 0 9)
ghci> range & L.start .~ LSP.Position 0 0
Range {_start = Position {_line = 0, _character = 0}, _end = Position {_line = 0, _character = 9}}
ghci> item = toCompletionItem (Variable "price" (Right 1200))
ghci> item ^. L.detail
Just "price = 1200"
ghci> item & L.detail ?~ "changed" & (^. L.detail)
Just "changed"
```

`&`は何個でもつなげられる．

```haskell
plainItem name & L.kind ?~ CompletionItemKind_Variable & L.detail ?~ hoverText name value
```

フィールド名を共有する型(`lsp-types`の型)では，レコード更新の構文(`item {_detail = …}`)はエラーになる．どの型のフィールドかを決められないからである．
lensは型ごとに作られているので，この問題がない．

## 書きかけの入力

補完が必要になるのは，利用者が入力している途中である．
そのとき，カーソルのある行はたいてい書きかけで，構文解析できない．

```text
let price = 1200
let total = (price + p|      ← この行は括弧が閉じていないので，文として読めない
```

候補を作るには，2つの情報を組み合わせる．

- 解析できた文(`[Statement]`)．上の行で定義された名前と値が分かる．
- カーソルのある行の，カーソルより前の文字列．解析できなくても，入力中の語と，その前に何があるかは分かる．

Calcでは，カーソルの前の文字列を，入力中の語とその前の部分に分ける．

```text
ghci> typed = T.take 13 "let total = price"
ghci> typed
"let total = p"
ghci> T.takeWhileEnd isAlphaNum typed
"p"
ghci> T.dropEnd 1 typed
"let total = "
ghci> "=" `T.isInfixOf` "let total = "
True
```

- `T.take n`は先頭の`n`文字，`T.dropEnd n`は末尾の`n`文字を除いた残りである．
- `T.takeWhileEnd p`は，末尾から`p`を満たす文字を集める．
- `T.isInfixOf`は，途中に含まれるかを調べる．

前の部分が空白だけなら行頭なので，キーワード`let`を候補にする．
`=`を含んでいれば右辺なので，変数を候補にする．

## 一覧の関数

```text
ghci> import Data.List (nub)
ghci> nub ["a", "b", "a", "c" :: String]
["a","b","c"]
ghci> [x * 10 | Just x <- [Just 1, Nothing, Just (3 :: Int)]]
[10,30]
```

- `nub`は，重複した要素を除く．最初に現れた要素が残る．
- リストの内包表記の`<-`の左にパターンを書くと，パターンに合う要素だけを使う．`Just x <- [Map.lookup name values]`は，見つかった値だけを取り出す書き方である．

一覧の`n`番目の要素は`xs !! n`で取り出せるが，範囲外なら例外になる．
`drop n xs`のあとにパターンマッチすれば，範囲外の場合を`[]`として扱える．

```haskell
lineText = case drop line (T.lines text) of
  current : _ -> current
  [] -> ""
```

## REPLの課題

`cabal repl calc-lsp-iter5-exercise`で，次を試す．

1. `T.takeWhileEnd`と`T.dropEnd`で，`"let a = 2 * pri"`を`"let a = 2 * "`と`"pri"`に分ける．
2. `nub`と`map fst`で，`[("a", 1), ("b", 2), ("a", 3)]`の名前を重複なく取り出す．
3. `Range`を作り，`&`と`.~`で`L.end`を変える．
