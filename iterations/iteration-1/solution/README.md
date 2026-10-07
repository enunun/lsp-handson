# Iteration 1(模範解答)：最初の診断を出す

文書を開いたときと変えたときに，`let 名前 = 式`の形をしていない行へ診断を送るCalcサーバである．
各段階の解説は[docs/iteration-1.md](docs/iteration-1.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter1-solution
mise run use-server calc-lsp-iter1-solution
```

VS Codeで`.calc`ファイルに`price * 2`のような行を書くと，その行に波線が付く．

## 構成

```text
calc-lsp-iter1-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Syntax.hs                   Span，Statement，Problem
src/Calc/Parser.hs                   parseLine，parseProgram
src/Calc/Summary.hs                  countLines
src/Lsp/Convert.hs                   toRange，toDiagnostic
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/Calc/ParserSpec.hs         parseLineとparseProgramの単体テスト
test/unit/Calc/SummarySpec.hs        countLinesの単体テスト
test/unit/Lsp/ConvertSpec.hs         toRangeとtoDiagnosticの単体テスト
test/integration/DiagnosticsSpec.hs  publishDiagnosticsの統合テスト
test/integration/LogMessageSpec.hs   window/logMessageの統合テスト
test/integration/TestServer.hs       サーバをテストの中で動かす
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-1.md                  解説
```
