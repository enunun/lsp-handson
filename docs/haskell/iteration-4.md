# Iteration 4のノート：定義と参照，名前解決の表

Iteration 4では，変数の定義へ移動し，参照を一覧にする．
このノートでは，LSPの`Location`と定義・参照のリクエスト，名前の定義と使用の一覧(名前解決の表)を一度作って使い回す設計，テストを安全網にしたリファクタリング，名前の衝突の避け方を説明する．

## `Location`

LSPで「文書のどこか」を表すのが`Location`で，文書のURIと範囲の組である．

```text
ghci> location = LSP.Location (LSP.Uri "file:///workspaces/sample.calc") (LSP.Range (LSP.Position 0 4) (LSP.Position 0 9))
```

定義や参照は，ほかの文書にあってもよいので，範囲だけでなくURIも返す．
Calcでは1つの文書の中だけで名前を探すので，URIはリクエストの文書のものを使う．

## 定義へ移動(`textDocument/definition`)

パラメータは，文書と位置である．
結果の型は入れ子になっている．

```text
Definition |? ([DefinitionLink] |? Null)
```

| 結果 | 作り方 |
| --- | --- |
| 1か所 | `InL (Definition (InL location))` |
| 複数の場所 | `InL (Definition (InR [location1, location2]))` |
| `LocationLink`の一覧 | `InR (InL links)` |
| なし | `InR (InR Null)` |

`Definition`は，`Location |? [Location]`を包んだ型である．

```text
ghci> :type LSP.Definition
LSP.Definition
  :: (LSP.Location LSP.|? [LSP.Location]) -> LSP.Definition
ghci> LSP.InL (LSP.Definition (LSP.InL location)) :: LSP.Definition LSP.|? ([LSP.DefinitionLink] LSP.|? LSP.Null)
InL (Definition (InL (Location {_uri = Uri {getUri = "file:///workspaces/sample.calc"}, _range = Range {_start = Position {_line = 0, _character = 4}, _end = Position {_line = 0, _character = 9}}})))
```

## すべての参照(`textDocument/references`)

パラメータは，文書，位置と，`ReferenceContext`である．
`ReferenceContext`の`includeDeclaration`が`True`なら，エディタは定義の場所も一覧に含めてほしい．

```haskell
includeDefinitions = params ^. L.context . L.includeDeclaration
```

結果の型は`[Location] |? Null`で，見つからなければ空の一覧を返せばよい．

lsp-testでは，`getDefinitions document position`と`getReferences document position includeDeclaration`でリクエストを送る．

## 名前解決の表

ホバー，定義，参照，名前の検査は，どれも「文書のどこで，どの名前が定義され，使われているか」を必要とする．
Iteration 3までは，`Calc.Check`と`Calc.Query`がそれぞれ式の木をたどって変数を集めていた．

Iteration 4では，名前の出現の一覧を一度だけ作る．

```haskell
data Occurrence = Occurrence
  { occName :: Text
  , occSpan :: Span
  , occKind :: OccKind
  }

data OccKind = Definition | Use
```

```text
ghci> occurrences (snd (parseProgram "let price = 1200\nlet tax = price * 8 / 100\n"))
[Occurrence {occName = "price", occSpan = Span {spanLine = 0, spanStart = 4, spanEnd = 9}, occKind = Definition},Occurrence {occName = "price", occSpan = Span {spanLine = 1, spanStart = 10, spanEnd = 15}, occKind = Use},Occurrence {occName = "tax", occSpan = Span {spanLine = 1, spanStart = 4, spanEnd = 7}, occKind = Definition}]
```

各機能は，この一覧を検索するだけになる．
木の形を知っているのは`Calc.Resolve`だけになり，`Expr`に新しい形を足しても直す場所が1つで済む．

一覧の並び順は，使う側の書きやすさで決める．
`Calc.Check`は「使用は，それより前の定義だけを見る」という決まりで調べる．
各文で式の使用を先に，名前の定義をあとに並べると，一覧を先頭から1回たどるだけで調べられる．

## 一覧を検索する

`Data.List`の`find`は，条件を満たす最初の要素を`Maybe`で返す．
`filter`は，条件を満たす要素をすべて返す．

```text
ghci> import Data.List (find)
ghci> find even [1, 3, 4, 6 :: Int]
Just 4
ghci> find even [1, 3, 5 :: Int]
Nothing
ghci> filter even [1, 2, 3, 4 :: Int]
[2,4]
```

## テストを安全網にしたリファクタリング

リファクタリングは，振る舞いを変えずにコードの構造を変えることである．
振る舞いが変わっていないことは，既存のテストが通ることで確かめる．

1. 新しい部品(`Calc.Resolve`)を，テストファーストで作る．
2. 既存の部品(`Calc.Check`)の中身を，新しい部品を使う形に書き換える．既存のテストは変えない．
3. 既存のテストがすべて通ることを確かめる．通らなければ，振る舞いが変わっている．

公開している関数の名前や型を変える場合(`nameAt`から`occurrenceAt`へ)は，そのテストも書き換える．
その書き換えは「期待値の変更」ではなく「呼び方の変更」なので，確かめている内容(どの位置で何が見つかるか)は同じに保つ．

## 名前の衝突

`Calc.Resolve`の`Definition`(出現の種類)と，`lsp-types`の`Definition`(定義の応答の型)は同じ名前である．
両方をimportしたところで`Definition`と書くと，どちらか分からないというエラーになる．

```text
<interactive>:1:1: error: [GHC-87543]
    Ambiguous occurrence `Definition'.
    It could refer to
       either `Calc.Resolve.Definition',
              imported from `Calc.Resolve' at src/Calc/Check.hs:6:22-33
              (and originally defined at src/Calc/Resolve.hs:15:16-25),
           or `Language.LSP.Protocol.Types.Definition',
              imported from `Language.LSP.Protocol.Types'
              (and originally defined in `lsp-types-2.4.0.0:Language.LSP.Protocol.Internal.Types.Definition').
```

避け方は2つある．

- 必要な名前だけをimportする．`Lsp.Server`は`Calc.Resolve`から`Occurrence (..)`と`occurrences`だけをimportするので，`OccKind`の`Definition`は見えない．
- 修飾付きでimportする(`import Language.LSP.Protocol.Types qualified as LSP`)．上のREPLの例はこの形である．

## 統合テストだけを実行する

```sh
cabal test calc-lsp-iter4-exercise:test:integration
```

## REPLの課題

`cabal repl calc-lsp-iter4-exercise`で，次を試す．

1. `find`と`filter`で，`[("a", 1), ("b", 2), ("a", 3)]`から最初の`"a"`の組と，すべての`"a"`の組を取り出す．
2. `ReferenceContext False`を持つ`ReferenceParams`を作り，`^. L.context . L.includeDeclaration`で読む．
3. `Location`を作り，`^. L.range . L.start . L.line`で始まりの行を読む．
