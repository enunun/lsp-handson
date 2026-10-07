# テストリスト

## 単体テスト

### 評価

`Calc.Eval.evalProgram`(`test/unit/Calc/EvalSpec.hs`)

- [x] 空のプログラムは空の`Map`
- [x] 数の値(`let price = 1200`は1200)
- [x] 上で定義した変数の値を使う(`price + 96`は1296)
- [x] 引き算と掛け算(`10 - 2 * 3`は4)
- [x] 割り算は小数部分を切り捨てる(`7 / 2`は3)
- [x] 負の商は小さいほうへ丸める(`(0 - 7) / 2`は-4)
- [x] 0での割り算は`DivisionByZero`
- [x] 上で定義されていない変数は`UndefinedVariable`
- [x] 式で使った変数の失敗をそのまま伝える
- [x] 同じ名前は最初の定義の値を使う

### 位置

`Calc.Query.nameAt`(`test/unit/Calc/QuerySpec.hs`)

- [x] 定義の名前を見つける
- [x] 式の中の変数を見つける
- [x] 名前の最後の文字の位置でも見つける
- [x] 名前の直後の位置では見つけない
- [x] 数と演算子の位置では見つけない
- [x] 文のない行では見つけない

### 変換

`Lsp.Convert`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] `fromPosition`は行と列を返す
- [x] `hoverText`は値を`名前 = 値`で表す
- [x] `hoverText`は0での割り算を`名前: cannot evaluate (division by zero)`で表す
- [x] `hoverText`は未定義の変数を`名前: cannot evaluate (undefined variable '…')`で表す

`Calc.Parser`，`Calc.Check`，`Calc.Summary`のテストは変えない．

## 統合テスト

`textDocument/hover`(`test/integration/HoverSpec.hs`)

- [x] 変数の上では，その値を表示する
- [x] 計算できない値は，理由を表示する
- [x] 変数でない位置では，何も表示しない
