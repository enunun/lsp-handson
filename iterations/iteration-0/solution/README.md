# Iteration 0(模範解答)：サーバを起動してエディタとつなぐ

エディタとつながり，文書を開いたときと変えたときに`<ファイル名>: <N> lines`をエディタのログに書くCalcサーバである．
各段階の解説は[docs/iteration-0.md](docs/iteration-0.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter0-solution
mise run use-server calc-lsp-iter0-solution
```

VS Codeで`examples/sample.calc`を開くと，出力パネル「Calc Language Server」に`sample.calc: 5 lines`が出る．

## 構成

```text
calc-lsp-iter0-solution.cabal     パッケージの定義
app/Main.hs                       実行ファイルcalc-lsp
src/Calc/Summary.hs               countLines
src/Lsp/Server.hs                 サーバの定義，didOpenとdidChangeのハンドラ
test/unit/Calc/SummarySpec.hs     countLinesの単体テスト
test/integration/TestServer.hs    サーバをテストの中で動かす
test/integration/LogMessageSpec.hs  window/logMessageの統合テスト
design/                           設計文書の模範解答
TESTLIST.md                       テストリストの模範解答
docs/iteration-0.md               解説
```
