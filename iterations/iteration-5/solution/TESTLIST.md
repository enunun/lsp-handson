# テストリスト

## 単体テスト

### 候補

`Calc.Complete.candidates`(`test/unit/Calc/CompleteSpec.hs`)

- [x] 空の行の先頭では`let`
- [x] 行頭で`le`まで入力していても`let`
- [x] 行頭でほかの語(`x`)を入力していれば候補なし
- [x] `=`のあとでは，上の行で定義された変数を値とともに出す
- [x] 入力中の語で始まる変数だけを残す
- [x] 定義の名前を入力している間(`let p`)は候補なし
- [x] カーソルの行と下の行で定義された変数は出さない
- [x] 括弧が閉じていない行(解析できない行)でも変数を出す
- [x] 2回定義された名前は，最初の値で1回だけ出す
- [x] 値が計算できない変数も，その理由とともに出す

### 変換

`Lsp.Convert.toCompletionItem`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] キーワードの候補は，種類がキーワードの項目
- [x] 変数の候補は，種類が変数で，詳細に`名前 = 値`を持つ項目

ほかのモジュールのテストは変えない．

## 統合テスト

`textDocument/completion`(`test/integration/CompletionSpec.hs`)

- [x] 右辺では，上の行で定義された変数を値とともに出す
- [x] 行頭では`let`を出す
