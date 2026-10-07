# Iteration 4(模範解答)：定義と参照をたどる

変数の定義へ移動し，参照を一覧にするCalcサーバである．
名前の出現の一覧(`Calc.Resolve`)を一度作り，名前の検査，ホバー，定義，参照のすべてがそれを使う．
各段階の解説は[docs/iteration-4.md](docs/iteration-4.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter4-solution
mise run use-server calc-lsp-iter4-solution
```

VS Codeで`examples/sample.calc`の5行目の`price`から「定義へ移動」すると，3行目の`price`へ移動する．

## 構成

```text
calc-lsp-iter4-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Syntax.hs                   Span，Statement，Expr，Op，Problem
src/Calc/Parser.hs                   parseLine，parseProgram
src/Calc/Resolve.hs                  Occurrence，OccKind，occurrences
src/Calc/Check.hs                    checkProgram(occurrencesを使う)
src/Calc/Eval.hs                     EvalError，evalProgram
src/Calc/Query.hs                    occurrenceAt，definitionOf，referencesOf
src/Calc/Summary.hs                  countLines
src/Lsp/Convert.hs                   toRange，toDiagnostic，toLocation，fromPosition，hoverText
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/                           各モジュールの単体テスト
test/integration/DefinitionSpec.hs   definitionの統合テスト
test/integration/ReferencesSpec.hs   referencesの統合テスト
test/integration/                    ほかの統合テストとTestServer
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-4.md                  解説
```
