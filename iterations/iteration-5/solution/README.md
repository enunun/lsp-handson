# Iteration 5(模範解答)：補完する

行頭では`let`を，右辺では上の行で定義された変数を，値を添えて補完の候補に出すCalcサーバである．
書きかけで解析できない行でも補完できる．
各段階の解説は[docs/iteration-5.md](docs/iteration-5.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter5-solution
mise run use-server calc-lsp-iter5-solution
```

VS Codeで`examples/sample.calc`の末尾に`let x = p`と入力すると，`price`が`price = 1200`を添えて候補に出る．

## 構成

```text
calc-lsp-iter5-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Complete.hs                 Candidate，candidates
src/Calc/                            ほかの言語の処理(Iteration 4と同じ)
src/Lsp/Convert.hs                   LSPの型への変換(toCompletionItemを追加)
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/Calc/CompleteSpec.hs       candidatesの単体テスト
test/unit/                           ほかの単体テスト
test/integration/CompletionSpec.hs   completionの統合テスト
test/integration/                    ほかの統合テストとTestServer
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-5.md                  解説
```
