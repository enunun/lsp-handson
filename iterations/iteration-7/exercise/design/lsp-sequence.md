# LSPのメッセージの順序

エディタがサーバを起動してから，文書を開いて編集し，変数のホバー，定義，参照，補完，リネームを求めるまでのメッセージを表す．

```mermaid
sequenceDiagram
  participant Editor as VS Code(Calc拡張機能)
  participant Server as Calcサーバ
  Editor->>Server: initialize
  Server-->>Editor: InitializeResult(serverInfo, textDocumentSync = Full, hoverProvider, definitionProvider, referencesProvider, completionProvider, renameProvider(prepareProvider))
  Editor->>Server: initialized
  Editor->>Server: textDocument/didOpen(uri, 全文)
  Server->>Editor: window/logMessage("sample.calc: 5 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
  Editor->>Server: textDocument/didChange(uri, 全文)
  Server->>Editor: window/logMessage("sample.calc: 6 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
  Editor->>Server: textDocument/hover(id, uri, position)
  alt 位置に定義済みの変数がある
    Server-->>Editor: Hover("tax = 96")
  else 変数がない
    Server-->>Editor: null
  end
  Editor->>Server: textDocument/definition(id, uri, position)
  alt 定義された変数がある
    Server-->>Editor: Location(uri, 定義の名前の範囲)
  else ない
    Server-->>Editor: null
  end
  Editor->>Server: textDocument/references(id, uri, position, includeDeclaration)
  Server-->>Editor: [Location](使用と，求められたときは定義)
  Editor->>Server: textDocument/completion(id, uri, position)
  Server-->>Editor: [CompletionItem]
  Editor->>Server: textDocument/prepareRename(id, uri, position)
  Server-->>Editor: Range(変数の範囲)
  Editor->>Server: textDocument/rename(id, uri, position, newName)
  alt 新しい名前が使える
    Server-->>Editor: WorkspaceEdit(すべての出現の編集)
    Note over Editor: エディタが文書を編集し，didChangeを送る
  else 規則に合わない，または定義済み
    Server-->>Editor: エラー(InvalidParams, 理由)
  end
```

- `initialize`と，`textDocument/`で始まるメソッドのうち`didOpen`，`didChange`，`publishDiagnostics`以外はリクエストで，同じ`id`の応答がある．
- `initialized`，`didOpen`，`didChange`，`window/logMessage`，`publishDiagnostics`は通知で，応答はない．
- `publishDiagnostics`は，その文書の診断をすべて送り直す．エディタは前の診断を新しい一覧で置き換える．
