# C4: Context と Container

利用者はVS Codeで`.calc`ファイルを編集する．
Calc拡張機能がCalcサーバ(`calc-lsp`)を起動し，VS CodeとサーバはLSPで文書の内容，ログ，診断をやり取りする．

```mermaid
flowchart LR
  user(["利用者"])
  subgraph editor["VS Code"]
    vscode["エディタ"]
    client["Calc拡張機能"]
  end
  server["Calcサーバ(calc-lsp)"]
  file[(".calcファイル")]
  user -->|"開く・編集する"| vscode
  vscode -->|"波線とメッセージ，ホバー，定義と参照の場所，補完の候補，リネームの結果，アウトライン"| user
  vscode -->|"読む・保存する"| file
  vscode --> client
  client -->|"起動する(標準入出力)"| server
  client -->|"開いた文書，変わった部分"| server
  server -->|"ログ(行数)"| client
  server -->|"診断(構文の誤り，未定義の変数，二重定義)"| client
  client -->|"ホバーの要求(位置)"| server
  server -->|"変数の値"| client
  client -->|"定義・参照の要求(位置)"| server
  server -->|"定義と参照の場所"| client
  client -->|"補完の要求(位置)"| server
  server -->|"補完の候補"| client
  client -->|"リネームの要求(位置，新しい名前)"| server
  server -->|"文書の編集，またはエラー"| client
  client -->|"アウトラインの要求"| server
  server -->|"定義の一覧と値"| client
```

- サーバはファイルを直接読まない．文書の内容は，エディタから届いた通知で知る．
- サーバはファイルを直接書き換えない．リネームでは編集を返し，エディタが文書に適用する．
- 診断は文書ごとに，そのときの問題をすべて送る．問題がなければ空の一覧を送り，前の波線を消す．
