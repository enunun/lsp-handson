# テストリスト

## 単体テスト

### 出現の一覧

`Calc.Resolve.occurrences`(`test/unit/Calc/ResolveSpec.hs`)

- [x] 空のプログラムには出現がない
- [x] 文の名前は定義
- [x] 式の変数は，左から順に使用
- [x] 各文で使用が定義より先に並び，文は上から順に並ぶ

### 名前の検査(リファクタリング)

`Calc.Check.checkProgram`(`test/unit/Calc/CheckSpec.hs`)

- [x] `occurrences`を使う形に書き換えても，Iteration 2からの6つのテストがそのまま通る

### 位置と名前の検索

`Calc.Query`(`test/unit/Calc/QuerySpec.hs`)

- [x] `nameAt`の6つのテストを，`occurrenceAt`の結果の名前を確かめる形に書き換える
- [x] `definitionOf`は名前の定義を見つける
- [x] `definitionOf`は2回定義された名前の最初の定義を見つける
- [x] `definitionOf`は定義されていない名前では`Nothing`
- [x] `referencesOf False`は名前の使用を見つける
- [x] `referencesOf True`は定義も含める
- [x] `referencesOf`は定義されていない名前では空

### 変換

`Lsp.Convert.toLocation`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] 文書のURIと，`Span`の範囲を持つ`Location`を作る

`Calc.Parser`，`Calc.Eval`，`Calc.Summary`のテストは変えない．

## 統合テスト

`textDocument/definition`(`test/integration/DefinitionSpec.hs`)

- [x] 変数の使用から，定義の名前の場所を返す
- [x] 定義されていない変数では何も返さない

`textDocument/references`(`test/integration/ReferencesSpec.hs`)

- [x] 変数の使用の場所を一覧にする
- [x] エディタが求めれば，定義の場所も含める

`textDocument/hover`(`test/integration/HoverSpec.hs`)

- [x] `occurrenceAt`を使う形に書き換えても，3つのテストがそのまま通る
