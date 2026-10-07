# テストリスト

## 単体テスト

### 名前の規則

`Calc.Parser.isValidName`(`test/unit/Calc/ParserSpec.hs`)

- [x] 英字に英数字が続く名前は使える
- [x] 数字で始まる名前，英数字以外を含む名前，空の文字列は使えない
- [x] `let`は使えない

### リネーム

`Calc.Rename.renameEdits`(`test/unit/Calc/RenameSpec.hs`)

- [x] 定義とすべての使用を置き換える編集を返す
- [x] 規則に合わない新しい名前は`InvalidName`
- [x] `let`は`InvalidName`
- [x] すでに定義された名前は`AlreadyDefined`
- [x] 同じ名前に変えるのは断らない
- [x] 編集を適用すると，名前だけが変わった文書になる
- [x] (性質)正しい新しい名前に変えてから元に戻すと，元の文書になる

### 変換

`Lsp.Convert`(`test/unit/Lsp/ConvertSpec.hs`)

- [x] `toWorkspaceEdit`は，文書のURIの下に編集をまとめる
- [x] `renameErrorMessage`は，断った理由を表す

ほかのモジュールのテストは変えない．

## 統合テスト

`textDocument/prepareRename`と`textDocument/rename`(`test/integration/RenameSpec.hs`)

- [x] `prepareRename`は，変数の範囲を返す
- [x] `prepareRename`は，変数でない位置では`null`を返す
- [x] `rename`は，定義とすべての使用を書き換える
- [x] `rename`は，すでに定義された名前ではエラーを返す
