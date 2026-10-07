# Iteration 2(演習)：式を解析して名前の誤りを見つける

`=`の右辺を式として読み，定義されていない変数と二重定義に診断を付ける．
手順は[docs/iteration-2.md](docs/iteration-2.md)にある．
コード，テスト，設計文書は，[Iteration 1の模範解答](../../iteration-1/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 2のノート](../../../docs/haskell/iteration-2.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter2-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 1のモジュール
test/                          Iteration 1のテスト
design/                        Iteration 1の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-2.md            演習の手順
```
