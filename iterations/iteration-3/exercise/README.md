# Iteration 3(演習)：ホバーで値を見る

変数にカーソルを重ねると，その値を表示する．
手順は[docs/iteration-3.md](docs/iteration-3.md)にある．
コード，テスト，設計文書は，[Iteration 2の模範解答](../../iteration-2/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 3のノート](../../../docs/haskell/iteration-3.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter3-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 2のモジュール
test/                          Iteration 2のテスト
design/                        Iteration 2の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-3.md            演習の手順
```
