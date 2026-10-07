# Iteration 6のノート：リネーム，エラーレスポンス，性質のテスト

Iteration 6では，変数の名前を，定義と使用のすべての場所でまとめて変える．
このノートでは，LSPのリネームの2つのリクエスト，文書の編集を表す`WorkspaceEdit`，リクエストにエラーで応える方法，QuickCheckによる性質のテストを説明する．

## リネームの流れ

エディタのリネームは，2つのリクエストからなる．

1. `textDocument/prepareRename`: リネームを始めてよいかを尋ねる．サーバは，リネームする名前の範囲を返す．エディタは，その範囲の文字列を入力欄の初期値にする．リネームできない位置では`null`を返す．
2. `textDocument/rename`: 利用者が新しい名前を入力すると送られる．サーバは，文書をどう編集すればよいか(`WorkspaceEdit`)を返す．

サーバは文書を書き換えない．
編集を受け取ったエディタが文書を書き換え，いつもどおり`didChange`をサーバへ送る．

`prepareRename`の結果の型は`PrepareRenameResult |? Null`で，範囲を返すときは`InL (PrepareRenameResult (InL range))`と書く．
2つのハンドラを登録すると，`lsp`ライブラリはcapabilitiesに`renameProvider`と，その`prepareProvider`を加える．

## `WorkspaceEdit`と`TextEdit`

`TextEdit`は，1つの範囲を新しい文字列に置き換える編集である．

```text
ghci> LSP.TextEdit (LSP.Range (LSP.Position 0 4) (LSP.Position 0 8)) "taxRate"
TextEdit {_range = Range {_start = Position {_line = 0, _character = 4}, _end = Position {_line = 0, _character = 8}}, _newText = "taxRate"}
```

`WorkspaceEdit`は，複数の文書への編集をまとめたものである．
`_changes`に，文書のURIから`TextEdit`の一覧への`Map`を入れる．

```haskell
WorkspaceEdit
  { _changes = Just (Map.singleton uri [TextEdit (toRange location) new | (location, new) <- edits])
  , _documentChanges = Nothing
  , _changeAnnotations = Nothing
  }
```

1つの文書への`TextEdit`の範囲はすべて，編集前の文書の位置で書く．
エディタが，範囲がずれないように順に適用する．

## エラーレスポンス

リクエストに応えられないときは，`respond`に`Left`でエラーを渡す．

```haskell
respond (Left (TResponseError (InR ErrorCodes_InvalidParams) "'tax' is already defined" Nothing))
```

| 引数 | 意味 |
| --- | --- |
| `InR ErrorCodes_InvalidParams` | エラーの種類．パラメータ(ここでは新しい名前)が不正であることを表す |
| メッセージ | エディタが利用者に表示する |
| `Nothing` | 追加のデータ |

エラーの種類の型は`LSPErrorCodes |? ErrorCodes`で，JSON-RPCで決められた種類(`ErrorCodes`)は`InR`で包む．
エディタは，エラーを受け取るとメッセージを表示し，文書を変えない．

「結果がない」(`null`)と「エラー」は違う．
`null`は「この位置ではリネームしない」，エラーは「頼まれたリネームはできない．理由はこうである」を表す．

## 性質のテスト(QuickCheck)

これまでのテストは，入力と期待値の組を1つずつ書いた．
QuickCheckでは，「どんな入力でも成り立つ性質」を書き，入力はライブラリがたくさん作って試す．

```text
ghci> import Test.QuickCheck
ghci> quickCheck (\xs -> reverse (reverse xs) == (xs :: [Int]))
+++ OK, passed 100 tests.
ghci> quickCheck (\xs -> reverse xs == (xs :: [Int]))
*** Failed! Falsified (after 3 tests and 2 shrinks):
[0,1]
```

- QuickCheckは，性質が成り立たない入力(反例)を見つけると，それを小さくしてから表示する(shrink)．`[0,1]`は，`reverse`しても同じにならない最も小さい例である．
- 入力は乱数で作るので，何回目で反例が見つかるかは実行ごとに変わる．

入力の作り方を指定するときは，`Gen`(入力を作るもの)と`forAll`を使う．

| 関数 | 作るもの |
| --- | --- |
| `elements xs` | `xs`の要素のどれか |
| `listOf g` | `g`で作った要素の一覧(長さもでたらめ) |
| ``g `suchThat` p`` | `g`で作ったもののうち，`p`を満たすもの |
| `forAll g prop` | `g`で作った値で`prop`を試す |

```text
ghci> quickCheck (forAll (elements "abc") (\c -> c `elem` ("abc" :: String)))
+++ OK, passed 100 tests.
ghci> quickCheck (forAll (listOf (elements "ab")) (\s -> length s < 3))
*** Failed! Falsified (after 5 tests):
"bba"
```

`forAll`で作った値は，小さくせずにそのまま表示する．

### hspecから使う

hspecの`Test.Hspec.QuickCheck`の`prop`で，性質をテストの1つとして書ける．
`===`は，失敗したときに両辺を表示する等号である．

```haskell
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, elements, forAll, listOf, suchThat, (===))

  prop "gives back the program when a name is renamed and renamed back" $
    forAll newName $ \name ->
      (renameIn name "rate" =<< renameIn "rate" name program) === Just program
```

リネームには，「新しい名前に変えてから元の名前に戻すと，元の文書になる」という性質がある．
例を1つずつ書くテストでは思いつかない名前(長い名前，数字を含む名前)でも，この性質が成り立つかを確かめられる．

QuickCheckを使うには，テストスイートの`build-depends`に`QuickCheck`を足す．

## `Ord`と`Down`で並べ替える

`sortOn f xs`は，`f`の結果の小さい順に並べる．
大きい順に並べるには，`Data.Ord`の`Down`で包む．

```haskell
sortOn (Down . spanStart . fst) edits
```

1行に複数の編集を適用するときは，右の編集から適用すると，まだ適用していない編集の位置がずれない．

## REPLの課題

`cabal repl calc-lsp-iter6-exercise:test:unit`で，次を試す(テストスイートのREPLなら`QuickCheck`が使える)．

1. `quickCheck`で，「一覧を2回`sort`しても1回と同じ」という性質を確かめる．
2. `quickCheck`で，「`n + 1 > n`」という性質を`Int`で確かめる．反例は見つかるか．
3. `forAll`と`elements`で，`['a' .. 'z']`から作った文字が`isAsciiLower`を満たすことを確かめる．
