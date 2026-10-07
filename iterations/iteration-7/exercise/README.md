# Iteration 7(演習)：アウトラインと差分同期

アウトラインを表示し，エディタから変更部分だけを受け取るようにする．
文書の解析結果を1回だけ作ってキャッシュし，すべての機能で使い回すようにリファクタリングする．
このIterationで，ロードマップの冒頭の使用例が完成する．
手順は[docs/iteration-7.md](docs/iteration-7.md)にある．
コード，テスト，設計文書は，[Iteration 6の模範解答](../../iteration-6/solution/)と同じ内容から始まる．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，引き継いだテストが通ることを確かめる．
2. 文法と概念：[Iteration 7のノート](../../../docs/haskell/iteration-7.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書を更新する．
5. テストファーストの実装とリファクタリング．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter7-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/                           Iteration 6のモジュール
test/                          Iteration 6のテスト
design/                        Iteration 6の設計文書
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-7.md            演習の手順
```
