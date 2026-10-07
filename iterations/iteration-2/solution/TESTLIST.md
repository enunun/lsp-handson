# テストリスト

## 単体テスト

### 引き継いだテストの変更

`Calc.Parser.parseLine`と`Calc.Parser.parseProgram`(`test/unit/Calc/ParserSpec.hs`)

- [x] 正しい文の3つのテストの期待値に，右辺の式(`Number 1200`，`BinOp Mul (Var "price" …) (Number 8)`，`Number 1`)を足す
- [x] `=`のあとが空の行(`let a =`)のメッセージを，行末の位置のmegaparsecのメッセージに変える
- [x] `parseProgram`で誤りと文を集めるテストの期待値に，右辺の式を足す

### 式

`Calc.Parser.parseLine`(`test/unit/Calc/ParserSpec.hs`)

- [x] 変数を読み，使った位置を持つ(`let total = price`の`price`は0行の12〜17列)
- [x] 足し算を読む
- [x] 同じ強さの演算子は左から結合する(`1 - 2 - 3`)
- [x] `*`は`+`より強く結合する(`1 + 2 * 3`)
- [x] `/`は`*`と同じ強さで，左から結合する(`8 / 2 * 3`)
- [x] 括弧の中を先に読む(`(1 + 2) * 3`)
- [x] 空白のない文を読む(`let a=1+2`)
- [x] 行末のコメントを読み飛ばす(`let a = 1 -- one`)
- [x] 式が途中で読めなくなったら，その位置から行末までが誤り(`let a = 12abc`は0行の10〜13列)
- [x] 閉じていない括弧は，行末の位置の誤り(`let broken = (1 + 2`は0行の19列)

### 名前の検査

`Calc.Check.checkProgram`(`test/unit/Calc/CheckSpec.hs`)

- [x] すべての変数が上で定義されていれば，問題はない
- [x] 定義されていない変数は，使った位置が問題
- [x] 下の行でだけ定義された変数は，未定義
- [x] 自分の定義の中で使った変数は，未定義(`let a = a + 1`)
- [x] 同じ名前の2回目の定義は，その名前の位置が問題
- [x] 問題は行の順に並び，同じ行では未定義の変数，二重定義の順

`Calc.Summary`と`Lsp.Convert`のテストは変えない．

## 統合テスト

`textDocument/publishDiagnostics`(`test/integration/DiagnosticsSpec.hs`)

- [x] 定義されていない変数を含む文書を開くと，その変数に診断が付く
