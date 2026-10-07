# C4: Component

サーバのモジュールと，importの向きを表す．
`Lsp.Server`がLSPのメッセージを受け取り，文書の解析，名前の検査，評価，位置の検索は純粋な`Calc.*`に任せる．
名前の定義と使用の一覧は`Calc.Resolve`が一度作り，`Calc.Check`と`Calc.Query`が使う．

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
    Calc_Resolve["Calc.Resolve"]
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
  Lsp_Server --> Calc_Resolve
  Lsp_Server --> Calc_Syntax
  Lsp_Server --> Lsp_Convert
  Lsp_Server --> ext_lsp
  Lsp_Convert --> Calc_Syntax
  Lsp_Convert --> Calc_Eval
  Lsp_Convert --> ext_lsp
  Calc_Parser --> Calc_Syntax
  Calc_Parser --> ext_megaparsec
  Calc_Check --> Calc_Resolve
  Calc_Check --> Calc_Syntax
  Calc_Check --> ext_containers
  Calc_Eval --> Calc_Syntax
  Calc_Eval --> ext_containers
  Calc_Query --> Calc_Resolve
  Calc_Query --> Calc_Syntax
  Calc_Resolve --> Calc_Syntax
```

- `Calc.*`は`lsp`に依存しない．LSPの型への変換は`Lsp.Convert`だけが行う．
- 式の木をたどって名前を集めるのは`Calc.Resolve`(`occurrences`)と`Calc.Eval`だけである．`Calc.Check`と`Calc.Query`は`[Occurrence]`を使う．
