# Iteration 1(演習)：最初の診断を出す

`let 名前 = 式`の形をしていない行に，エディタで波線が付くようにする．
手順は[docs/iteration-1.md](docs/iteration-1.md)にある．
コード，テスト，設計文書は，[Iteration 0の模範解答](../../iteration-0/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 1のノート](../../../docs/haskell/iteration-1.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter1-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 0のモジュール(Calc.Summary，Lsp.Server)
test/                          Iteration 0のテスト
design/                        Iteration 0の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-1.md            演習の手順
```
