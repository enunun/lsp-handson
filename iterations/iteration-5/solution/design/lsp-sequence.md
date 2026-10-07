# LSPのメッセージの順序

エディタがサーバを起動してから，文書を開いて編集し，変数のホバー，定義，参照，補完を求めるまでのメッセージを表す．

```mermaid
sequenceDiagram
  participant Editor as VS Code(Calc拡張機能)
  participant Server as Calcサーバ
  Editor->>Server: initialize
  Server-->>Editor: InitializeResult(serverInfo, textDocumentSync = Full, hoverProvider, definitionProvider, referencesProvider, completionProvider)
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
```

- `initialize`，`textDocument/hover`，`textDocument/definition`，`textDocument/references`，`textDocument/completion`はリクエストで，同じ`id`の応答がある．ほかは通知で，応答はない．
- `publishDiagnostics`は，その文書の診断をすべて送り直す．エディタは前の診断を新しい一覧で置き換える．
