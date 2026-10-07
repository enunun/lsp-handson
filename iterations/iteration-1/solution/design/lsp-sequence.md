# LSPのメッセージの順序

エディタがサーバを起動してから，文書を開いて編集するまでのメッセージを表す．

```mermaid
sequenceDiagram
  participant Editor as VS Code(Calc拡張機能)
  participant Server as Calcサーバ
  Editor->>Server: initialize
  Server-->>Editor: InitializeResult(serverInfo, textDocumentSync = Full)
  Editor->>Server: initialized
  Editor->>Server: textDocument/didOpen(uri, 全文)
  Server->>Editor: window/logMessage("sample.calc: 5 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
  Editor->>Server: textDocument/didChange(uri, 全文)
  Server->>Editor: window/logMessage("sample.calc: 6 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
```

- `initialize`だけがリクエストで，応答がある．ほかは通知で，応答はない．
- `publishDiagnostics`は，その文書の診断をすべて送り直す．エディタは前の診断を新しい一覧で置き換える．
