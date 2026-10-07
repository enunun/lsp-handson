# C4: Component

サーバのモジュールと，importの向きを表す．
`Lsp.Server`がLSPのメッセージを受け取る．
文書が開かれたときと変わったときに，`Calc.Analysis`が文書を1回だけ解析し，`Lsp.State`のキャッシュに入れる．
リクエストのハンドラは，キャッシュの解析結果を純粋な`Calc.*`の関数で検索する．

```mermaid
flowchart LR
  subgraph io["IO(LSP)"]
    Main["Main"]
    Lsp_Server["Lsp.Server"]
    Lsp_State["Lsp.State"]
    Lsp_Convert["Lsp.Convert"]
  end
  subgraph pure["純粋(Calc)"]
    Calc_Analysis["Calc.Analysis"]
    Calc_Summary["Calc.Summary"]
    Calc_Parser["Calc.Parser"]
    Calc_Check["Calc.Check"]
    Calc_Complete["Calc.Complete"]
    Calc_Eval["Calc.Eval"]
    Calc_Query["Calc.Query"]
    Calc_Rename["Calc.Rename"]
    Calc_Resolve["Calc.Resolve"]
    Calc_Syntax["Calc.Syntax"]
  end
  ext_lsp[["lsp"]]
  ext_stm[["stm"]]
  ext_megaparsec[["megaparsec"]]
  ext_containers[["containers"]]
  Main --> Lsp_Server
  Lsp_Server --> Lsp_State
  Lsp_Server --> Lsp_Convert
  Lsp_Server --> Calc_Analysis
  Lsp_Server --> Calc_Summary
  Lsp_Server --> Calc_Complete
  Lsp_Server --> Calc_Query
  Lsp_Server --> Calc_Rename
  Lsp_Server --> Calc_Resolve
  Lsp_Server --> Calc_Syntax
  Lsp_Server --> ext_lsp
  Lsp_State --> Calc_Analysis
  Lsp_State --> ext_stm
  Lsp_State --> ext_containers
  Lsp_State --> ext_lsp
  Lsp_Convert --> Calc_Syntax
  Lsp_Convert --> Calc_Eval
  Lsp_Convert --> Calc_Complete
  Lsp_Convert --> Calc_Rename
  Lsp_Convert --> ext_containers
  Lsp_Convert --> ext_lsp
  Calc_Analysis --> Calc_Parser
  Calc_Analysis --> Calc_Check
  Calc_Analysis --> Calc_Eval
  Calc_Analysis --> Calc_Resolve
  Calc_Analysis --> Calc_Syntax
  Calc_Analysis --> ext_containers
  Calc_Parser --> Calc_Syntax
  Calc_Parser --> ext_megaparsec
  Calc_Check --> Calc_Resolve
  Calc_Check --> Calc_Syntax
  Calc_Check --> ext_containers
  Calc_Complete --> Calc_Eval
  Calc_Complete --> Calc_Syntax
  Calc_Complete --> ext_containers
  Calc_Eval --> Calc_Syntax
  Calc_Eval --> ext_containers
  Calc_Query --> Calc_Resolve
  Calc_Query --> Calc_Syntax
  Calc_Rename --> Calc_Parser
  Calc_Rename --> Calc_Query
  Calc_Rename --> Calc_Resolve
  Calc_Rename --> Calc_Syntax
  Calc_Resolve --> Calc_Syntax
```

- `Calc.*`は`lsp`に依存しない．LSPの型への変換は`Lsp.Convert`だけが行う．
- 解析(`parseProgram`，`checkProgram`，`occurrences`，`evalProgram`)を呼ぶのは`Calc.Analysis`だけである．`Lsp.Server`は解析結果(`Analysis`)を受け取って使う．
- 共有する状態(キャッシュ)を持つのは`Lsp.State`だけである．
- `Calc.Rename`は，名前の規則を`Calc.Parser`の`isValidName`で確かめる．
- `Calc.Complete`は，解析できた文に加えて，カーソルのある行の文字列を受け取る．書きかけで解析できない行でも候補を出すためである．
