# Iteration 3: ホバーで値を見る

このIterationでは，変数にカーソルを重ねると，その変数の値を表示する．
LSPのリクエストとレスポンス，`|?`型，`Data.Map`，`Either`と`Maybe`を`do`でつなぐ書き方を学ぶ．

## 3-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-3/exercise`の行を足す．
2. ビルドし，Iteration 2から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにして，`examples/sample.calc`の`tax`にカーソルを重ねる．まだ何も表示されない．出力パネルで`initialize`の応答を見ると，`capabilities`に`hoverProvider`がない．そのため，エディタはホバーを要求しない．

## 3-2 文法と概念

[Iteration 3のノート](../../../../docs/haskell/iteration-3.md)を読み，最後の「REPLの課題」を解く．

## 3-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- 変数にカーソルを重ねると(定義と使用のどちらでもよい)，`名前 = 値`を表示する．
- 値は，それまでの定義を上から順に評価して求める．`/`は整数の割り算で，小数部分を切り捨てる(負の数では小さいほうへ丸める)．
- 同じ名前が2回定義されている場合は，最初の定義の値を使う．
- 0で割った場合や，未定義の変数を含む場合は，`名前: cannot evaluate (理由)`を表示する．理由は`division by zero`か`undefined variable '名前'`である．
- 定義されていない変数と，変数以外の場所では何も表示しない．

### 使用例

```text
let price = 1200
let tax = price * 8 / 100     ← tax にホバー: tax = 96
let bad = price / (tax - 96)  ← bad にホバー: bad: cannot evaluate (division by zero)
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Eval` | `data EvalError = DivisionByZero \| UndefinedVariable Text`，`evalProgram :: [Statement] -> Map Text (Either EvalError Integer)` |
| `Calc.Query` | `nameAt :: Int -> Int -> [Statement] -> Maybe Text`(行と列にある名前) |
| `Lsp.Convert` | `fromPosition :: Position -> (Int, Int)`，`hoverText :: Text -> Either EvalError Integer -> Text` |
| `Lsp.Server` | `textDocument/hover`のリクエストハンドラ |

### 書くときに考えること

- 評価の結果が分かれるのはどこか．演算子ごとの計算，割り算の丸め，0での割り算，未定義の変数，失敗した変数を使う式，二重定義を挙げる．
- 名前の位置の境界はどこか．名前の最初の文字，最後の文字，名前の直後の空白で結果がどうなるか．
- 表示の文字列は，値と2種類の失敗で3通りある．
- 統合テストでは，表示がある場合，失敗の理由が出る場合，何も出ない場合を確かめる．

## 3-4 設計文書

- `c4-context.md`: エディタとサーバの間で，新しく何を要求し，何を返すか．
- `c4-component.md`: 新しいモジュールを2つ足す．どちらも`[Statement]`だけを受け取ればよいか．
- `code-flow.md`: ホバーの流れを，診断の流れとは別の図にする．位置と文書から，表示する文字列ができるまでの型と関数を描く．途中で`Nothing`になりうる箇所はどこか．
- `lsp-sequence.md`: リクエストと，その応答を描く．応答が`null`になる場合を`alt`で分ける．`initialize`の応答の中身も変わる．

## 3-5 テストファーストの実装

`Calc.Eval`と`Calc.Query`を`exposed-modules`に，テストのモジュールを`other-modules`に足す．
単体テストで`Data.Map`を使うなら，`test-suite unit`の`build-depends`に`containers`を足す．
1つのモジュールのテストだけを実行するには，hspecの`--match`を使う．

```sh
cabal test calc-lsp-iter3-exercise:test:unit --test-options='--match "Calc.Eval"'
```

### `evalProgram`

- 上の文から順に，名前と値を`Map`に加えていく．`foldl'`で畳み込める．
- 式の値は，`Map`を受け取る再帰関数で求める．変数は`Map.lookup`で引き，見つからなければ`UndefinedVariable`にする．
- `BinOp`は，`Either`の`do`で2つの被演算子を計算してから演算する．0で割るかどうかは，割る前に調べる．
- テストでは，`parseProgram`で文を作ってから`evalProgram`に渡すと読みやすい．

### `nameAt`

- 文の名前と，式の中の変数の両方を候補にする．
- `Span`の終わりの列は含まない．

### `hoverText`と`fromPosition`

- `Position`の行と列の型は`UInt`である．

### ホバーのハンドラ

- 統合テストは`test/integration/HoverSpec.hs`に書き，lsp-testの`getHover`を使う．
- ハンドラは，VFSから文書を取り出し，`nameAt`と`evalProgram`の結果を`Maybe`の`do`でつなぐ．結果がなければ`InR Null`を返す．
- 最初の統合テストは，ハンドラがないので`MethodNotFound`のエラーで失敗する．

### エディタで確かめる

`examples/sample.calc`で，`tax`と`total`にカーソルを重ねる．
`total`は未定義の`fee`を使っているので，理由が表示される．

## 3-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. `evalExpr`を`Either`の`do`を使わずに`case`で書くと，どうなるか．
3. 0での割り算を，割る前に調べなかったら，どのテストがどう失敗するか．
4. `Calc.Check`と`Calc.Query`に，似た処理がないか．Iteration 4で，それをどうまとめられるか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 3-7 発展課題

ホバーに，値に加えて式を表示する(`tax = price * 8 / 100 = 96`)．
`Expr`を文字列に戻す関数を作り，括弧の要否(`(1 + 2) * 3`と`1 + 2 * 3`)をテストリストに書く．
