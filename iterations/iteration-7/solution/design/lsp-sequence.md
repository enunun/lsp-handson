# LSPのメッセージの順序

エディタがサーバを起動してから，文書を開いて編集し，各機能を求めるまでのメッセージと，サーバのキャッシュとのやり取りを表す．

```mermaid
sequenceDiagram
  participant Editor as VS Code(Calc拡張機能)
  participant Server as Calcサーバ
  participant Cache as キャッシュ(Lsp.State)
  Editor->>Server: initialize
  Server-->>Editor: InitializeResult(serverInfo, textDocumentSync = Incremental, 各機能のprovider)
  Editor->>Server: initialized
  Editor->>Server: textDocument/didOpen(uri, 全文)
  Server->>Cache: updateAnalysis(uri, 全文)
  Server->>Editor: window/logMessage("sample.calc: 5 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
  Editor->>Server: textDocument/didChange(uri, 変わった範囲と文字列)
  Note over Server: lspがVFSの文書に差分を適用する
  Server->>Cache: updateAnalysis(uri, VFSの全文)
  Server->>Editor: window/logMessage("sample.calc: 5 lines")
  Server->>Editor: textDocument/publishDiagnostics(uri, 診断の一覧)
  Editor->>Server: textDocument/hover(id, uri, position)
  Server->>Cache: lookupAnalysis(uri)
  alt 位置に定義済みの変数がある
    Server-->>Editor: Hover("tax = 96")
  else 変数がない
    Server-->>Editor: null
  end
  Editor->>Server: textDocument/definition，references，completion(id, uri, position)
  Server->>Cache: lookupAnalysis(uri)
  Server-->>Editor: Location，[Location]，[CompletionItem]
  Editor->>Server: textDocument/prepareRename(id, uri, position)
  Server-->>Editor: Range(変数の範囲)
  Editor->>Server: textDocument/rename(id, uri, position, newName)
  alt 新しい名前が使える
    Server-->>Editor: WorkspaceEdit(すべての出現の編集)
    Note over Editor: エディタが文書を編集し，didChangeを送る
  else 規則に合わない，または定義済み
    Server-->>Editor: エラー(InvalidParams, 理由)
  end
  Editor->>Server: textDocument/documentSymbol(id, uri)
  Server->>Cache: lookupAnalysis(uri)
  Server-->>Editor: [DocumentSymbol](定義の名前と値)
```

- `initialize`と，`textDocument/`で始まるメソッドのうち`didOpen`，`didChange`，`publishDiagnostics`以外はリクエストで，同じ`id`の応答がある．`Cache`への矢印は，サーバの中の関数呼び出しである．
- `initialized`，`didOpen`，`didChange`，`window/logMessage`，`publishDiagnostics`は通知で，応答はない．
- `publishDiagnostics`は，その文書の診断をすべて送り直す．エディタは前の診断を新しい一覧で置き換える．
- 文書の解析は`didOpen`と`didChange`のときだけ行う．リクエストはキャッシュの解析結果を読むだけである．
- `textDocumentSync = Incremental`なので，`didChange`は変わった部分だけを運ぶ．
