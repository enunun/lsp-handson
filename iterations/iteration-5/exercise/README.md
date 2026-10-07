# Iteration 5(演習)：補完する

入力中の語を補う候補を出す．
手順は[docs/iteration-5.md](docs/iteration-5.md)にある．
コード，テスト，設計文書は，[Iteration 4の模範解答](../../iteration-4/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 5のノート](../../../docs/haskell/iteration-5.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter5-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 4のモジュール
test/                          Iteration 4のテスト
design/                        Iteration 4の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-5.md            演習の手順
```
