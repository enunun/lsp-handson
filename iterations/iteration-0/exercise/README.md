# Iteration 0(演習)：サーバを起動してエディタとつなぐ

エディタとつながり，開いた文書の行数をエディタのログに書くCalcサーバを作る．
手順は[docs/iteration-0.md](docs/iteration-0.md)にある．

## 進め方

1. 準備：パッケージを`cabal.project`に登録し，ビルドとテストを確かめる．
2. 文法と概念：[Iteration 0のノート](../../../docs/haskell/iteration-0.md)を読む．
3. テストリスト：`TESTLIST.md`に，確かめる振る舞いを書き出す．
4. 設計文書：`design/`の4つの文書の最初の版を書く．
5. テストファーストの実装．
6. 振り返り：[模範解答](../solution/)と見比べる．

## 構成

```text
calc-lsp-iter0-exercise.cabal  パッケージの定義
app/Main.hs                    実行ファイルcalc-lsp
src/Calc/Summary.hs            文書の行数(本体はこれから書く)
src/Lsp/Server.hs              サーバの定義とハンドラ(初期化に応じるだけ)
test/unit/                     単体テスト(hspec-discoverの入口だけ)
test/integration/              統合テスト(hspec-discoverの入口だけ)
design/                        設計文書(見出しと，何を描くかのコメントだけ)
TESTLIST.md                    テストリスト(見出しだけ)
docs/iteration-0.md            演習の手順
```
