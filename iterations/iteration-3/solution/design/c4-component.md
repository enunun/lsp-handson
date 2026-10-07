# C4: Component

サーバのモジュールと，importの向きを表す．
`Lsp.Server`がLSPのメッセージを受け取り，文書の解析と名前の検査は純粋な`Calc.*`に任せる．
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
    Calc_Check["Calc.Check"]
    Calc_Eval["Calc.Eval"]
    Calc_Query["Calc.Query"]
    Calc_Syntax["Calc.Syntax"]
  end
  ext_lsp[["lsp"]]
  ext_megaparsec[["megaparsec"]]
  ext_containers[["containers"]]
  Main --> Lsp_Server
  Lsp_Server --> Calc_Summary
  Lsp_Server --> Calc_Parser
  Lsp_Server --> Calc_Check
  Lsp_Server --> Calc_Eval
  Lsp_Server --> Calc_Query
  Lsp_Server --> Lsp_Convert
  Lsp_Server --> ext_lsp
  Lsp_Convert --> Calc_Syntax
  Lsp_Convert --> Calc_Eval
  Lsp_Convert --> ext_lsp
  Calc_Parser --> Calc_Syntax
  Calc_Parser --> ext_megaparsec
  Calc_Check --> Calc_Syntax
  Calc_Check --> ext_containers
  Calc_Eval --> Calc_Syntax
  Calc_Eval --> ext_containers
  Calc_Query --> Calc_Syntax
```

- `Calc.*`は`lsp`に依存しない．LSPの型(`Range`，`Diagnostic`)への変換は`Lsp.Convert`だけが行う．
- `Calc.Parser`は1行ずつ読む．`Calc.Check`，`Calc.Eval`，`Calc.Query`は，読めた文の一覧(`[Statement]`)だけを受け取り，`Calc.Parser`を使わない．
- 式の変数を集める`variables`は，`Calc.Check`と`Calc.Query`の両方にある．
