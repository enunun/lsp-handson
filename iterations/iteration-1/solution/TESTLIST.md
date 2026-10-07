# テストリスト

## 単体テスト

`Calc.Parser.parseLine`(`test/unit/Calc/ParserSpec.hs`)

- [x] `let price = 1200`は文で，名前`price`の位置は0行の4〜9列
- [x] 行番号を位置に使う(3行目の`let tax = price * 8`は3行の4〜7列)
- [x] 字下げと`let`のあとの空白の幅を，名前の開始列に加える(字下げが2，`let`のあとの空白が3の`let a = 1`なら，名前は0行の8〜9列)
- [x] `let`で始まらない行(`price * 2`)は，行全体が誤り
- [x] 数字で始まる名前(`let 1x = 3`)は誤り
- [x] `=`がない行(`let a 1`)は誤り
- [x] `=`のあとが空の行(`let a =`)は誤り
- [x] 空白だけの行は調べない
- [x] 行頭の空白を除いて`--`で始まる行は調べない

`Calc.Parser.parseProgram`(`test/unit/Calc/ParserSpec.hs`)

- [x] 空のプログラムからは何も読まない
- [x] 誤りと文を，それぞれ行の順に集める(空行とコメント行を飛ばし，行番号は元の行のまま)

`Calc.Summary.countLines`(`test/unit/Calc/SummarySpec.hs`)

- 変更なし(Iteration 0の5項目)

`Lsp.Convert`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] `toRange`は行と列をそのまま`Range`にする
- [x] `toDiagnostic`は，重さがエラー，出どころが`calc`で，メッセージと範囲を持つ診断を作る

## 統合テスト

`textDocument/publishDiagnostics`(`test/integration/DiagnosticsSpec.hs`)

- [x] `let`の形でない行を含む文書を開くと，その行に診断が付く
- [x] 文書を直すと，診断が空になる

`window/logMessage`(`test/integration/LogMessageSpec.hs`)

- [x] 文書を変えたときのログのテストを，ほかのメッセージ(診断)を読み飛ばしてログを待つように変える
