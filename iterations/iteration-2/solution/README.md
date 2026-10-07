# Iteration 2(模範解答)：式を解析して名前の誤りを見つける

右辺の式をmegaparsecで解析し，構文の誤り，定義されていない変数，二重定義に診断を送るCalcサーバである．
各段階の解説は[docs/iteration-2.md](docs/iteration-2.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter2-solution
mise run use-server calc-lsp-iter2-solution
```

VS Codeで`examples/sample.calc`を開くと，5行目の`fee`に`undefined variable 'fee'`の波線が付く．

## 構成

```text
calc-lsp-iter2-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Syntax.hs                   Span，Statement，Expr，Op，Problem
src/Calc/Parser.hs                   parseLine，parseProgram(megaparsec)
src/Calc/Check.hs                    checkProgram
src/Calc/Summary.hs                  countLines
src/Lsp/Convert.hs                   toRange，toDiagnostic
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/Calc/ParserSpec.hs         parseLineとparseProgramの単体テスト
test/unit/Calc/CheckSpec.hs          checkProgramの単体テスト
test/unit/Calc/SummarySpec.hs        countLinesの単体テスト
test/unit/Lsp/ConvertSpec.hs         toRangeとtoDiagnosticの単体テスト
test/integration/DiagnosticsSpec.hs  publishDiagnosticsの統合テスト
test/integration/LogMessageSpec.hs   window/logMessageの統合テスト
test/integration/TestServer.hs       サーバをテストの中で動かす
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-2.md                  解説
```
