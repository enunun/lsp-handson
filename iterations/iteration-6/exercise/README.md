# Iteration 6(演習)：リネームする

変数の名前を，定義と使用のすべての場所でまとめて変える．
手順は[docs/iteration-6.md](docs/iteration-6.md)にある．
コード，テスト，設計文書は，[Iteration 5の模範解答](../../iteration-5/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 6のノート](../../../docs/haskell/iteration-6.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter6-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 5のモジュール
test/                          Iteration 5のテスト
design/                        Iteration 5の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-6.md            演習の手順
```
