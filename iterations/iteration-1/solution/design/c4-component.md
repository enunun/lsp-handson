# C4: Component

サーバのモジュールと，importの向きを表す．
`Lsp.Server`がLSPのメッセージを受け取り，文書の解析は純粋な`Calc.*`に任せる．
`Lsp.Convert`が，`Calc.*`の値をLSPの型に変える．

```mermaid
flowchart LR
  subgraph io["IO(LSP)"]
    Main["Main"]
    Lsp_Server["Lsp.Server"]
    Lsp_Convert["Lsp.Convert"]
  end
  subgraph pure["純粋(Calc)"]
    Calc_Summary["Calc.Summary"]
    Calc_Parser["Calc.Parser"]
    Calc_Syntax["Calc.Syntax"]
  end
  ext_lsp[["lsp"]]
  Main --> Lsp_Server
  Lsp_Server --> Calc_Summary
  Lsp_Server --> Calc_Parser
  Lsp_Server --> Lsp_Convert
  Lsp_Server --> ext_lsp
  Lsp_Convert --> Calc_Syntax
  Lsp_Convert --> ext_lsp
  Calc_Parser --> Calc_Syntax
```

- `Calc.*`は`lsp`に依存しない．LSPの型(`Range`，`Diagnostic`)への変換は`Lsp.Convert`だけが行う．
- `Lsp.Convert`は純粋な関数だけを持つが，LSPの型を扱うので`Lsp.*`の側に置く．
