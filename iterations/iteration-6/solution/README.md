# Iteration 6(模範解答)：リネームする

変数の名前を，定義と使用のすべての場所でまとめて変えるCalcサーバである．
使えない名前やすでに定義された名前には，理由を添えたエラーを返す．
各段階の解説は[docs/iteration-6.md](docs/iteration-6.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter6-solution
mise run use-server calc-lsp-iter6-solution
```

VS Codeで`examples/sample.calc`の`rate`を`taxRate`に変えると，2行目と4行目がまとめて書き換わる．

## 構成

```text
calc-lsp-iter6-solution.cabal        パッケージの定義
app/Main.hs                          実行ファイルcalc-lsp
src/Calc/Rename.hs                   RenameError，renameEdits
src/Calc/Parser.hs                   構文解析(isValidNameを公開)
src/Calc/                            ほかの言語の処理(Iteration 5と同じ)
src/Lsp/Convert.hs                   LSPの型への変換(toWorkspaceEdit，renameErrorMessageを追加)
src/Lsp/Server.hs                    サーバの定義とハンドラ
test/unit/Calc/RenameSpec.hs         renameEditsの単体テストと性質のテスト
test/unit/                           ほかの単体テスト
test/integration/RenameSpec.hs       prepareRenameとrenameの統合テスト
test/integration/                    ほかの統合テストとTestServer
design/                              設計文書の模範解答
TESTLIST.md                          テストリストの模範解答
docs/iteration-6.md                  解説
```
