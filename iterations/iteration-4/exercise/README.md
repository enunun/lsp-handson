# Iteration 4(演習)：定義と参照をたどる

変数の定義へ移動し，参照を一覧にする．
名前の出現の一覧を一度作り，名前の検査とホバーもそれを使うように書き直す．
手順は[docs/iteration-4.md](docs/iteration-4.md)にある．
コード，テスト，設計文書は，[Iteration 3の模範解答](../../iteration-3/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 4のノート](../../../docs/haskell/iteration-4.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装とリファクタリング．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter4-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 3のモジュール
test/                          Iteration 3のテスト
design/                        Iteration 3の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-4.md            演習の手順
```
