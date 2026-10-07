# Iteration 3(模範解答)：ホバーで値を見る

変数にカーソルを重ねると，その値(または計算できない理由)を表示するCalcサーバである．
各段階の解説は[docs/iteration-3.md](docs/iteration-3.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter3-solution
mise run use-server calc-lsp-iter3-solution
```

VS Codeで`examples/sample.calc`の`tax`にカーソルを重ねると，`tax = 96`が表示される．

## 構成

```text
calc-lsp-iter3-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Syntax.hs                   Span，Statement，Expr，Op，Problem
src/Calc/Parser.hs                   parseLine，parseProgram
src/Calc/Check.hs                    checkProgram
src/Calc/Eval.hs                     EvalError，evalProgram
src/Calc/Query.hs                    nameAt
src/Calc/Summary.hs                  countLines
src/Lsp/Convert.hs                   toRange，toDiagnostic，fromPosition，hoverText
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/                           各モジュールの単体テスト
test/integration/HoverSpec.hs        hoverの統合テスト
test/integration/                    ほかの統合テストとTestServer
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-3.md                  解説
```
