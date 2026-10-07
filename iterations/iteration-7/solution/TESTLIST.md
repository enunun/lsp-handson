# テストリスト

## 単体テスト

### 解析のまとめ

`Calc.Analysis.analyze`(`test/unit/Calc/AnalysisSpec.hs`)

- [x] 文書の行を持つ
- [x] 問題は，構文の問題，名前の問題の順に並ぶ
- [x] 文，出現，評価結果，問題は，これまでの関数の結果と同じ

### キャッシュ

`Lsp.State`(`test/unit/Lsp/StateSpec.hs`)

- [x] 解析していない文書では何も見つからない
- [x] 解析した文書の結果が見つかる
- [x] 同じ文書を解析し直すと，結果が置き換わる
- [x] 別の文書の結果とは混ざらない

### 変換

`Lsp.Convert`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] `valueText`は，値か，計算できない理由を表す
- [x] `toDocumentSymbol`は，名前，値の詳細，変数の種類，名前の範囲を持つ項目を作る
- [x] `hoverText`を`valueText`を使う形に書き換えても，3つのテストがそのまま通る

ほかのモジュールのテストは変えない．

## 統合テスト

### 引き継いだテストの変更

- [x] `TestServer.hs`で，キャッシュを作ってから`serverDefinition`に渡す(期待値は変えない)

### 新しいテスト

`textDocument/documentSymbol`(`test/integration/DocumentSymbolSpec.hs`)

- [x] 定義を上から順に，値とともに並べる

文書の同期(`test/integration/SyncSpec.hs`)

- [x] `initialize`の応答で，差分同期を求める
- [x] 一部を変える差分を送ると，診断とホバーに変更が反映される
