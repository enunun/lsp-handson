# Iteration 7(模範解答)：アウトラインと差分同期

コースの完成形のCalcサーバである．
診断，ホバー，定義へ移動，参照，補完，リネーム，アウトラインに応え，エディタから変更部分だけを受け取る．
文書の解析結果は，開かれたときと変わったときに1回だけ作り，キャッシュから使い回す．
各段階の解説は[docs/iteration-7.md](docs/iteration-7.md)にある．

## 動かし方

```sh
cabal test calc-lsp-iter7-solution
mise run use-server calc-lsp-iter7-solution
```

VS Codeで`examples/sample.calc`を開くと，[ロードマップ](../../../docs/ROADMAP.md)の冒頭の使用例がすべて動く．

## 構成

```text
calc-lsp-iter7-solution.cabal           パッケージの定義
app/Main.hs                             実行ファイルcalc-lsp
src/Calc/Analysis.hs                    Analysis，analyze
src/Calc/                               ほかの言語の処理
src/Lsp/State.hs                        Cache，newCache，updateAnalysis，lookupAnalysis
src/Lsp/Convert.hs                      LSPの型への変換(valueText，toDocumentSymbolを追加)
src/Lsp/Server.hs                       サーバの定義とハンドラ(キャッシュを使う)
test/unit/Calc/AnalysisSpec.hs          analyzeの単体テスト
test/unit/Lsp/StateSpec.hs              キャッシュの単体テスト
test/unit/                              ほかの単体テスト
test/integration/DocumentSymbolSpec.hs  documentSymbolの統合テスト
test/integration/SyncSpec.hs            差分同期の統合テスト
test/integration/                       ほかの統合テストとTestServer
design/                                 設計文書の模範解答
TESTLIST.md                             テストリストの模範解答
docs/iteration-7.md                     解説
```
