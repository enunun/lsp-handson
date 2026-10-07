# Iteration 4: 定義と参照をたどる

このIterationでは，変数の定義へ移動し，変数の参照を一覧にする．
LSPの`Location`と定義・参照のリクエスト，名前の出現の一覧を一度作って使い回す設計，テストを安全網にしたリファクタリングを学ぶ．

## 4-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-4/exercise`の行を足す．
2. ビルドし，Iteration 3から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにする．`examples/sample.calc`で`price`の「定義へ移動」を選んでも，まだ移動しない．

## 4-2 文法と概念

[Iteration 4のノート](../../../../docs/haskell/iteration-4.md)を読み，最後の「REPLの課題」を解く．

## 4-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- 変数の使用箇所で「定義へ移動」すると，その変数を定義した行の名前へ移動する．同じ名前が2回定義されていれば，最初の定義へ移動する．
- 「すべての参照を検索」すると，その変数の使用箇所を一覧にする．エディタが定義も含めるよう求めた場合は，定義も含める．
- 未定義の変数では，どちらも空の結果を返す．
- これまでの機能(診断，ホバー)は，そのまま動く．

### 使用例

```text
let price = 1200               ← 定義
let tax = price * 8 / 100      ← 使用 1
let total = price + tax        ← 使用 2．ここの price で「定義へ移動」→ 1 行目
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Resolve` | `data Occurrence = Occurrence {occName :: Text, occSpan :: Span, occKind :: OccKind}`，`data OccKind = Definition \| Use`，`occurrences :: [Statement] -> [Occurrence]`(各文の式の使用，名前の定義の順) |
| `Calc.Query` | `nameAt`を`occurrenceAt :: Int -> Int -> [Occurrence] -> Maybe Occurrence`に置き換え，`definitionOf :: Text -> [Occurrence] -> Maybe Occurrence`，`referencesOf :: Bool -> Text -> [Occurrence] -> [Occurrence]`を足す |
| `Calc.Check` | 未定義と二重定義の検査を，`occurrences`の結果から行うよう書き直す |
| `Lsp.Convert` | `toLocation :: Uri -> Span -> Location` |
| `Lsp.Server` | `textDocument/definition`と`textDocument/references`のハンドラを足し，ホバーも`occurrenceAt`を使うよう書き直す |

`referencesOf`の最初の引数は，定義も含めるかどうかである．

### 書くときに考えること

- `occurrences`の並び順を，テストで決める．1つの文の中で，使用と定義はどちらが先か．なぜその順にするのか．
- `definitionOf`と`referencesOf`で，名前が2回定義されている場合と，定義されていない場合はどうなるか．
- 引き継いだテストのうち，書き換えるもの(`nameAt`のテスト)と，変えずに安全網として使うもの(`Calc.Check`とホバーのテスト)を分ける．

## 4-4 設計文書

- `c4-context.md`: エディタとサーバの間で，新しく何を要求し，何を返すか．
- `c4-component.md`: 新しいモジュールを足し，`Calc.Check`と`Calc.Query`の依存先を変える．式の木をたどるモジュールがいくつになるかを数える．
- `code-flow.md`: 位置を受け取る3つの機能(ホバー，定義，参照)を，`[Occurrence]`を中心にした1つの図にまとめる．
- `lsp-sequence.md`: 2つのリクエストと応答を足す．`initialize`の応答の中身も変わる．

## 4-5 テストファーストの実装

新しいモジュールを`exposed-modules`に，新しいテストのモジュールを`other-modules`に足す．
統合テストだけを実行して，引き継いだ機能が動き続けていることを確かめるには，次のコマンドを使う．

```sh
cabal test calc-lsp-iter4-exercise:test:integration
```

### `occurrences`

- 式の変数を左から集める処理は，`Calc.Check`と`Calc.Query`にある`variables`と同じ形である．
- テストでは，定義だけの文，使用を含む文，複数の文の順に確かめる．

### `Calc.Check`の書き換え

- まず`Calc.Check`のテストを変えずに，中身を`occurrences`の結果をたどる形に書き換える．
- `mapAccumL`で定義済みの名前の`Set`を持ち回る点は同じである．出現ごとに，`Use`と`Definition`で場合を分ける．
- 書き換えたら，`Calc.Check`のテストだけを実行して確かめる．失敗したら，`occurrences`の並び順を見直す．

### `Calc.Query`

- `nameAt`のテストを`occurrenceAt`のテストに書き換える．確かめる位置と結果(名前)は変えない．
- `Data.List`の`find`と`filter`が使える．
- `referencesOf`は，定義されていない名前に対して何を返すか．

### ハンドラ

- 3つのハンドラ(ホバー，定義，参照)は，どれも「文書の文の一覧」を必要とする．文書から`[Statement]`を取り出す関数を1つ作ると，ハンドラが短くなる．
- 定義の応答の型は`Definition |? ([DefinitionLink] |? Null)`，参照の応答の型は`[Location] |? Null`である．
- `Calc.Resolve`の`Definition`と，`lsp-types`の`Definition`は名前が同じである．`Lsp.Server`でのimportの書き方に気を付ける．
- 統合テストは`test/integration/DefinitionSpec.hs`と`test/integration/ReferencesSpec.hs`に書き，lsp-testの`getDefinitions`と`getReferences`を使う．

### エディタで確かめる

`examples/sample.calc`の`price`で「定義へ移動」と「すべての参照を検索」を試す．
未定義の`fee`では，定義と参照のどちらの結果も空になる．

## 4-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. `occurrences`の並び順を「名前の定義，式の使用」(行の中の左から右)にすると，どのテストがどう失敗するか．
3. リファクタリングの前後で，`Calc.Check`のテストが1つも変わらなかったことは，何を保証しているか．
4. 式の木をたどる処理は，いくつのモジュールに残ったか．`Expr`に新しい形(例えば単項のマイナス)を足すとき，直す場所はどこか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 4-7 発展課題

`textDocument/documentHighlight`に応える．
カーソルの下の変数と同じ名前の出現をすべて強調し，定義は`DocumentHighlightKind_Write`，使用は`DocumentHighlightKind_Read`で区別する．
`[Occurrence]`から作れるので，`Calc.*`に足すものはほとんどない．
