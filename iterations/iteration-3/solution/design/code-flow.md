# Code: 型と関数の流れ

文書のURIから，エディタへ送るログと診断を作るまでの流れと，ホバーの位置から表示する文字列を作るまでの流れを表す．

```mermaid
flowchart LR
  Uri -->|"getVirtualFile"| VirtualFile["Maybe VirtualFile"]
  VirtualFile -->|"virtualFileText"| Text
  Text -->|"countLines"| Int
  Int -->|"summary"| Message["Text(ログの文字列)"]
  Uri -->|"fileName"| Message
  Message -->|"LogMessageParams"| LogMessage["window/logMessage"]
  Text -->|"parseProgram"| Parsed["([Problem], [Statement])"]
  Parsed -->|"fst"| ParseProblems["[Problem](構文)"]
  Parsed -->|"snd"| Statements["[Statement]"]
  Statements -->|"checkProgram"| NameProblems["[Problem](名前)"]
  ParseProblems -->|"<>"| Problems["[Problem]"]
  NameProblems -->|"<>"| Problems
  Problems -->|"map toDiagnostic"| Diagnostics["[Diagnostic]"]
  Diagnostics -->|"PublishDiagnosticsParams"| Publish["textDocument/publishDiagnostics"]
```

- `parseLine`は，まず`let <name> =`の部分(`header`)を読む．読めなければ，行全体に`expected: let <name> = <expr>`を付ける．読めれば，行全体を文(`statement`)として読み，読めなかった位置から行末までにmegaparsecのメッセージを付ける．
- 式は`chainLeft`で読む．`+` `-`は`*` `/`より弱く結合し，同じ強さの演算子は左から結合する．`--`から行末まではコメントとして読み飛ばす．
- `Var`は，変数を使った位置の`Span`を持つ．
- `checkProgram`は，`mapAccumL`で定義済みの名前の`Set`を上の行から持ち回る．各文で，式の`variables`のうち未定義のものと，名前の二重定義を問題にする．
- 診断は，構文の問題，名前の問題の順に並べる．

```mermaid
flowchart LR
  HoverParams -->|"fromPosition"| LineColumn["(Int, Int)"]
  VirtualFile -->|"virtualFileText"| Text
  Text -->|"parseProgram"| Statements["[Statement]"]
  LineColumn -->|"nameAt"| Name["Maybe Text"]
  Statements -->|"nameAt"| Name
  Statements -->|"evalProgram"| Values["Map Text (Either EvalError Integer)"]
  Name -->|"Map.lookup"| Value["Maybe (Either EvalError Integer)"]
  Values -->|"Map.lookup"| Value
  Value -->|"hoverText"| HoverText["Text"]
  HoverText -->|"Hover"| Result["Hover |? Null"]
```

- `hoverAt`は，`Maybe`の`do`で`nameAt`と`Map.lookup`をつなぐ．どちらかが`Nothing`なら，応答は`Null`になる．
- `nameAt`は，名前の`Span`に位置が含まれる最初の名前を返す．`Span`の終わりの列は含まない．
- `evalProgram`は上の文から順に評価する．値は`Either`の`do`で計算し，0での割り算と未定義の変数を`Left`で伝える．同じ名前の2回目の定義は評価しない．
- `/`は`div`で，小数部分を小さいほうへ丸める．
