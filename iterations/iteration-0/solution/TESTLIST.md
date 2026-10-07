# テストリスト

## 単体テスト

`Calc.Summary.countLines`(`test/unit/Calc/SummarySpec.hs`)

- [x] 空の文書は0行
- [x] 改行のない1行は1行
- [x] 改行で区切られた3行は3行
- [x] 末尾の改行のあとに行は数えない
- [x] 空行も1行として数える

## 統合テスト

`window/logMessage`(`test/integration/LogMessageSpec.hs`)

- [x] 2行の文書`sample.calc`を開くと，ログに「sample.calc: 2 lines」が出る
- [x] 文書を3行に変えると，ログに「sample.calc: 3 lines」が出る
