# Code: 型と関数の流れ

文書から解析結果を作ってキャッシュに入れる流れと，キャッシュの解析結果から各リクエストの結果を作る流れを表す．

```mermaid
flowchart LR
  Uri -->|"getVirtualFile"| VirtualFile["Maybe VirtualFile"]
  VirtualFile -->|"virtualFileText"| Text
  Text -->|"analyze"| Analysis
  Analysis -->|"updateAnalysis"| Cache["Cache = TVar (Map NormalizedUri Analysis)"]
  Text -->|"countLines, summary"| LogMessage["window/logMessage"]
  Analysis -->|"anProblems, map toDiagnostic"| Publish["textDocument/publishDiagnostics"]
```

- `analyze`は，`parseProgram`，`checkProgram`，`occurrences`，`evalProgram`を1回ずつ呼び，結果を`Analysis`にまとめる．
- `anProblems`は，構文の問題，名前の問題の順である．
- `updateAnalysis`は，`atomically`の中で`modifyTVar'`を使い，文書のURIの解析結果を置き換える．
- 差分同期では，`didChange`は変わった部分だけを運ぶ．`lsp`ライブラリがVFSの文書に差分を適用してからハンドラを呼ぶので，`virtualFileText`は常に文書全体である．

```mermaid
flowchart LR
  Uri -->|"lookupAnalysis"| Found["Maybe Analysis"]
  Position -->|"fromPosition"| LineColumn["(Int, Int)"]
  Found -->|"anOccurrences, occurrenceAt"| Here["Maybe Occurrence"]
  LineColumn -->|"occurrenceAt"| Here
  Here -->|"anValues, hoverText"| Hover["Hover |? Null"]
  Here -->|"definitionOf, toLocation"| Definition["Definition |? ([DefinitionLink] |? Null)"]
  Here -->|"referencesOf, toLocation"| References["[Location] |? Null"]
  Here -->|"toRange"| Prepare["PrepareRenameResult |? Null"]
  Here -->|"renameEdits"| Rename["WorkspaceEdit |? Null, またはエラー"]
  Found -->|"anLines, anStatements, candidates"| Completion["[CompletionItem]"]
  Found -->|"anStatements, anValues, toDocumentSymbol"| Symbols["[DocumentSymbol]"]
```

- 解析結果がない(開かれていない)文書では，どのリクエストも結果なしを返す．
- `occurrenceAt`は，位置を含む最初の出現を返す．`Span`の終わりの列は含まない．出現は評価の順(各文の式の使用，名前の定義)に並ぶ．
- `definitionOf`は最初の定義を返す．`referencesOf`は，名前が定義されていなければ空である．
- `renameEdits`は，新しい名前が規則に合わないか`let`なら`InvalidName`，すでに定義されていれば`AlreadyDefined`を返す．失敗は`TResponseError`(`InvalidParams`)になる．
- `candidates`は，カーソルの行の文字列から入力中の語を取り出す．行頭なら`let`，右辺なら上の行で定義された変数を，入力中の語で絞って返す．
- アウトラインは，文の順に名前と値(`valueText`)を並べる．同じ名前の2回目の定義には，最初の定義の値が付く．
