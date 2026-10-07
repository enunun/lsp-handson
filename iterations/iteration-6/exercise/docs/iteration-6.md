# Iteration 6: リネームする

このIterationでは，変数の名前を，定義と使用のすべての場所でまとめて変える．
LSPのリネームの2つのリクエスト，`WorkspaceEdit`，エラーレスポンス，QuickCheckによる性質のテストを学ぶ．

## 6-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-6/exercise`の行を足す．
2. ビルドし，Iteration 5から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにする．`examples/sample.calc`の`rate`で「シンボルの名前変更」(`F2`)を選んでも，名前は変えられない．サーバが`renameProvider`を宣言していないからである．

## 6-2 文法と概念

[Iteration 6のノート](../../../../docs/haskell/iteration-6.md)を読み，最後の「REPLの課題」を解く．
QuickCheckを使う課題は，6-5の「依存パッケージ」の手順で`QuickCheck`を足してから解く．

## 6-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- 変数の上でリネームを始めると，その変数の範囲を返す(変数以外では始められない)．
- 新しい名前を受け取ると，定義と使用のすべてを書き換える編集を返す．
- 新しい名前が名前の規則に合わない場合と`let`である場合は`'名前' is not a valid name`，ほかの定義の名前と重なる場合は`'名前' is already defined`のエラーを返す．このとき文書は書き換えない．
- 名前を変えてから元に戻すと，元の文書になる．

### 使用例

```text
let rate = 8
let tax = 1200 * rate / 100

rate → taxRate にリネーム:
let taxRate = 8
let tax = 1200 * taxRate / 100

rate → tax にリネーム: エラー「'tax' is already defined」
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Parser` | 名前の規則を確かめる`isValidName :: Text -> Bool`を公開する |
| `Calc.Rename` | `data RenameError = InvalidName Text \| AlreadyDefined Text`，`renameEdits :: Text -> Text -> [Occurrence] -> Either RenameError [(Span, Text)]`(元の名前，新しい名前，出現) |
| `Lsp.Convert` | `toWorkspaceEdit :: Uri -> [(Span, Text)] -> WorkspaceEdit`，`renameErrorMessage :: RenameError -> Text` |
| `Lsp.Server` | `textDocument/prepareRename`と`textDocument/rename`のハンドラ |

### 書くときに考えること

- `isValidName`は，名前の規則のほかに何を断るか．規則は`Calc.Parser`のどこにすでに書かれているか．
- `renameEdits`が断る場合と，同じ名前に変える場合をどうするか．
- 「変えてから元に戻すと元の文書になる」を，性質のテストとして書く．そのために，編集を文書に適用する補助の関数と，正しい新しい名前を作る`Gen`が必要になる．
- 統合テストでは，`prepareRename`の範囲と`null`，リネームの成功と失敗を確かめる．

## 6-4 設計文書

- `c4-context.md`: リネームの要求と，その結果(編集かエラー)を足す．サーバが文書を書き換えないことを書く．
- `c4-component.md`: 新しいモジュールを足す．名前の規則をどのモジュールから使うか．
- `code-flow.md`: リネームの流れを4つ目の図にする．`renameEdits`の成功と失敗が，それぞれどの型になってエディタへ返るか．
- `lsp-sequence.md`: `prepareRename`から`rename`までを描き，成功とエラーを`alt`で分ける．成功したあと，エディタが何を送るかも書く．

## 6-5 テストファーストの実装

### 依存パッケージ

`Calc.Rename`を`exposed-modules`に，テストのモジュールを`other-modules`に足す．
`test-suite unit`の`build-depends`に`QuickCheck`を足す．
`prop`は`hspec`の`Test.Hspec.QuickCheck`にある．

### `isValidName`

- `Calc.Parser`の`name`パーサに，`eof`を続けて文字列全体を読ませれば，同じ規則で確かめられる．
- `Data.Either`の`isRight`が使える．

### `renameEdits`

- まず，元の名前のすべての出現を新しい名前に置き換える編集を作る．
- 断る場合は，ガードで先に調べる．定義済みかどうかは`Calc.Query`の`definitionOf`で分かる．
- 性質のテストのための補助の関数(`applyEdits`)は，テストのファイルに書く．1行に複数の編集があるときは，右から適用する．

### ハンドラ

- `prepareRename`は，位置の出現の範囲を`PrepareRenameResult`で返す．
- `rename`のパラメータの新しい名前は`^. L.newName`で読む．
- エラーは`TResponseError (InR ErrorCodes_InvalidParams) メッセージ Nothing`で返す．
- 統合テストは`test/integration/RenameSpec.hs`に書く．lsp-testの`rename`は，返った編集を自分の文書に適用するので，`documentContents`で結果を確かめられる．エラーを確かめるときは，`request SMethod_TextDocumentRename`で応答をそのまま受け取る．

### エディタで確かめる

`examples/sample.calc`の`rate`を`taxRate`に変える．
`tax`に変えようとすると，エラーのメッセージが表示され，文書は変わらない．

## 6-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. 性質のテストは，例を並べるテストと比べて，何を見つけやすいか．見つけにくいものは何か．REPLの課題2の結果も踏まえて考える．
3. `prepareRename`で`null`を返すことと，`rename`でエラーを返すことは，利用者から見て何が違うか．
4. 名前の規則を`Calc.Parser`から公開したのはなぜか．`Calc.Rename`に同じ規則を書くと，何が困るか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 6-7 発展課題

未定義の変数の名前に変えようとしたときにも，エラーを返す．
例えば`fee`が使われているが定義されていない文書で，`rate`を`fee`に変えると，未定義だった`fee`の使用が`rate`の値を指すようになってしまう．
エラーのメッセージ(`'fee' is already used`など)を決め，`RenameError`に新しい場合を足す．
