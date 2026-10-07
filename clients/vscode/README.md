# Calc Language Client

`.calc`ファイルを開くと，ワークスペースの`.bin/calc-lsp`をCalcサーバとして起動するVS Codeの拡張機能．
`mise run client`でビルドしてVS Codeに入れる．

| 設定 | 意味 |
| --- | --- |
| `calc.server.path` | 起動するサーバのパス．ワークスペースからの相対パスでもよい．既定は`.bin/calc-lsp` |
| `calc.trace.server` | `verbose`にすると，出力パネル「Calc Language Server」にJSON-RPCのメッセージが出る |

コマンド「Calc: Restart Server」で，サーバを起動し直す．
