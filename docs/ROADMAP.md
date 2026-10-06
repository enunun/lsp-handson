# ロードマップ

このコースでは，小さな式言語Calcのための言語サーバ(LSPサーバ)をHaskellで作る．
Iteration 0で「エディタとつながるだけのサーバ」を作り，Iterationごとに機能を1〜2個ずつ足して，最後に下の使用例を完成させる．

## 完成したプログラムの使用例

Calcのプログラムは，`let 名前 = 式`の行を並べたものである．
式は整数，変数，四則演算(`+` `-` `*` `/`)と括弧からなり，`--`から行末まではコメントである．

```text
-- sample.calc
let rate = 8
let price = 1200
let tax = price * rate / 100
let total = price + tax + fee
```

VS Codeで`sample.calc`を開くと，同梱の拡張機能がCalcサーバを起動し，次のように動く．

| 操作 | 結果 |
| --- | --- |
| ファイルを開く | 5行目の`fee`に波線が付き，「undefined variable 'fee'」と表示される |
| `tax`にカーソルを重ねる | `tax = 96`と表示される |
| `tax`で「定義へ移動」 | 4行目の`let tax`へ移動する |
| `price`で「すべての参照を検索」 | 3行目の定義と，4・5行目の2か所の使用が一覧になる |
| 5行目の末尾で`p`と入力する | 補完候補に`price`が出る |
| `rate`を`taxRate`にリネームする | 2行目と4行目の`rate`がまとめて書き換わる |
| アウトラインを開く | `rate` `price` `tax` `total`の4つの定義が並ぶ |

出力パネルの「Calc Language Server」を開くと，エディタとサーバが交わしたJSON-RPCのメッセージを確認できる．

## Iteration の進め方

どのIterationも同じ順で進める．

| 手順 | すること |
| --- | --- |
| 1. 準備 | `iterations/iteration-N/exercise`をビルドし，前のIterationから引き継いだテストがすべて通ることを確かめる |
| 2. 文法と概念 | `docs/haskell/iteration-N.md`を読み，REPLで小さな課題を解く |
| 3. テストリスト | 要求と使用例から，テストの項目を`TESTLIST.md`に書き出す |
| 4. 設計文書 | `design/`の設計文書を更新する |
| 5. テストファーストの実装 | テストリストの項目を1つずつRed → Green → Refactorで実装する |
| 6. 振り返り | 模範解答と見比べ，設計文書を実装に合わせて直す |

手を動かす場所は`exercise/`で，`solution/`には完成したコードと模範解答がある．
Iteration Nの`exercise/`は，Iteration N-1の`solution/`と同じ内容から始まる．

## テストの分け方

| 種類 | 確かめること | 置き場所 | 使う道具 |
| --- | --- | --- | --- |
| 単体テスト | `Calc.*`と`Lsp.Convert`の関数を1つずつ，入力と出力の対応で確かめる | `test/unit/` | hspec |
| 統合テスト | サーバを起動し，エディタの代わりにLSPのメッセージを送って，返ってくる応答や通知を確かめる | `test/integration/` | hspec，lsp-test |

## Iteration の一覧

| Iteration | 作る機能 | 学ぶこと |
| --- | --- | --- |
| 0 | サーバの起動，エディタのログへの行数の出力 | LSPの仕組み(JSON-RPC，初期化，通知)，`lsp`ライブラリの骨組み，`Text`，cabal，hspec，lsp-test |
| 1 | `let`の形をしていない行の診断 | `publishDiagnostics`，`Diagnostic`と`Range`，レコード，`Maybe`と`Either` |
| 2 | 式の構文解析，未定義変数と二重定義の診断 | megaparsec，再帰的なデータ型，`Applicative`，`Data.Set` |
| 3 | ホバーで変数の値を表示 | リクエストとレスポンス，位置の変換，`Either`による評価，`Data.Map` |
| 4 | 定義へ移動，すべての参照を検索 | 名前解決の表，`Location`，リファクタリング |
| 5 | 補完 | 書きかけの行の扱い，`CompletionItem`，接頭辞による絞り込み |
| 6 | リネーム | `WorkspaceEdit`，エラーレスポンス，QuickCheckによる性質のテスト |
| 7 | アウトライン，差分同期と解析結果のキャッシュ | `DocumentSymbol`，差分同期とVFS，STM(`TVar`) |

## Iteration 0: サーバを起動してエディタとつなぐ

### 要求

- エディタが`.calc`ファイルを開くと，サーバが起動して初期化に応じる．サーバは名前を名乗り，文書を全文で受け取ることを宣言する．
- 文書を開いたとき，および編集するたびに，サーバはエディタのログに「ファイル名：N lines」を書く．
- 行数は改行で区切られた行の数である．空の文書は0行で，末尾の改行のあとに行は数えない．

### 使用例

```text
-- sample.calc を開いたとき，出力パネル「Calc Language Server」に出る行
sample.calc: 5 lines
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Summary` | `countLines :: Text -> Int` |
| `Lsp.Server` | `serverDefinition :: ServerDefinition ()`，`handlers :: Handlers (LspM ())`(`initialized`，`didOpen`，`didChange`) |
| `app/Main.hs` | `main :: IO ()` |

### 設計文書の更新

- `c4-context.md`: エディタ，拡張機能，Calcサーバ，`.calc`ファイルを描き，「開く・編集する」「ログ」の関係を書く．
- `c4-component.md`: 上の3つのモジュールと依存の矢印を描く．
- `code-flow.md`: VFSから取り出した`Text`が`countLines`を通ってログの文字列になる流れを描く．
- `lsp-sequence.md`: `initialize` → `initialized` → `didOpen` → `window/logMessage` → `didChange` → `window/logMessage`の順を描く．

### 学ぶこと

- LSP: クライアントとサーバ，JSON-RPCのリクエスト・レスポンス・通知，`Content-Length`ヘッダ，初期化とcapabilities，`window/logMessage`．
- `lsp`ライブラリ：`ServerDefinition`，`runServer`，`notificationHandler`，`LspM`，`sendNotification`，仮想ファイルシステム(VFS)からの文書の取得．
- Haskell: `Text`と`OverloadedStrings`，lensの`^.`によるメッセージの読み出し．
- 道具：cabalのパッケージとテストスイート，hspec，lsp-test，VS Codeの拡張機能でJSON-RPCを覗く．

### 既存のテストへの影響

なし(最初のIteration)．

### 受講者が行う道具の操作

- ルートの`cabal.project`にパッケージを登録する．
- `cabal build`，`cabal test`，`cabal repl`を使う．
- `mise run use-server`で，エディタが起動するサーバを自分のパッケージに切り替える．

## Iteration 1: 最初の診断を出す

### 要求

- 文書を開いたとき，および編集するたびに，サーバは文書を検査して診断を送る．
- 空行と，`--`で始まるコメント行は検査しない．
- それ以外の行が`let 名前 = 何か`の形をしていなければ，その行全体に「`expected: let <name> = <expr>`」という診断を付ける．名前は英字で始まり，英数字が続く．
- 正しい形の行だけなら，診断は空になる(以前の波線が消える)．

### 使用例

```text
let price = 1200
price * 2          ← 診断: expected: let <name> = <expr>
let 1x = 3         ← 診断: expected: let <name> = <expr>
-- コメント
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Syntax` | `data Span = Span {spanLine :: Int, spanStart :: Int, spanEnd :: Int}`，`data Statement = Statement {stmtName :: Text, stmtSpan :: Span}`，`data Problem = Problem {problemSpan :: Span, problemMessage :: Text}` |
| `Calc.Parser` | `parseLine :: Int -> Text -> Maybe (Either Problem Statement)`，`parseProgram :: Text -> ([Problem], [Statement])` |
| `Lsp.Convert` | `toRange :: Span -> Range`，`toDiagnostic :: Problem -> Diagnostic` |
| `Lsp.Server` | `didOpen`と`didChange`のハンドラで，診断を送る |

### 設計文書の更新

- `c4-context.md`:「診断」の関係を加える．
- `c4-component.md`: `Calc.Syntax`，`Calc.Parser`，`Lsp.Convert`と依存の矢印を加え，純粋な`Calc.*`とIOを扱う`Lsp.*`の境界を示す．
- `code-flow.md`: `Text`から`parseProgram`を通って`[Problem]`になり，`toDiagnostic`で`[Diagnostic]`になる流れを加える．
- `lsp-sequence.md`: `didOpen`と`didChange`のあとに`publishDiagnostics`を加える．

### 学ぶこと

- LSP: `textDocument/publishDiagnostics`，`Diagnostic`と`Range`，前の診断を空のリストで消す仕組み．
- Haskell: レコード，`Maybe`と`Either`，`Data.Text`による行の分割と検査．

### 既存のテストへの影響

なし．

### 受講者が行う道具の操作

- 新しいモジュールを`exposed-modules`に登録する．
- 単体テストだけを実行する(`cabal test <パッケージ>:test:unit`)．

## Iteration 2: 式を解析して名前の誤りを見つける

### 要求

- `=`の右辺を式として解析する．式は整数，変数，`+` `-` `*` `/`，括弧からなり，`*` `/`は`+` `-`より強く結合し，同じ強さの演算子は左から結合する．
- 行末の`-- コメント`を許す．
- 解析できない行には，解析できなかった位置にmegaparsecのエラーメッセージを付ける．1行の誤りは他の行の解析に影響しない．
- 変数が，それより前の行で定義されていなければ，その変数に「undefined variable '名前'」を付ける．
- 同じ名前を2回定義したら，2回目の名前に「'名前' is already defined」を付ける．

### 使用例

```text
let price = 1200
let tax = price * 8 / 100
let total = price + tax + fee    ← fee に診断: undefined variable 'fee'
let price = 1000                 ← price に診断: 'price' is already defined
let broken = (1 + 2              ← 行末に診断: unexpected end of input ...
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Syntax` | `data Expr = Number Integer \| Var Text Span \| BinOp Op Expr Expr`，`data Op = Add \| Sub \| Mul \| Div`を追加し，`Statement`に`stmtExpr :: Expr`を追加する |
| `Calc.Parser` | megaparsecで書き直す．`parseLine`と`parseProgram`の型は変えない |
| `Calc.Check`(新規) | `checkProgram :: [Statement] -> [Problem]` |
| `Lsp.Server` | 診断を`parseProgram`と`checkProgram`の結果の両方から作る |

### リファクタリング

`Calc.Parser`の中身を，`Data.Text`の関数による行の分割からmegaparsecのパーサに置き換える．Iteration 1のテストはそのまま通る．

### 設計文書の更新

- `c4-component.md`: `Calc.Check`と，外部ライブラリmegaparsecへの依存を加える．
- `code-flow.md`: `[Statement]`から`checkProgram`を通る枝と，2つの`[Problem]`を合わせる箇所を加える．
- `lsp-sequence.md`: 変化なしでよいかを確かめる(要求はすべて既存の通知の中で実現する)．
- `c4-context.md`: 診断の種類を書き足す．

### 学ぶこと

- megaparsec: `Parser`，`Applicative`のコンビネータ(`<$>` `<*>` `<*` `*>`)，`many`，`try`，演算子の優先順位，位置の取得．
- 再帰的なデータ型と再帰関数．
- `foldl'`で定義済みの名前の集合(`Data.Set`)を持ち回る．

### 既存のテストへの影響

- `parseLine`の結果の`Statement`に`stmtExpr`が加わるので，期待値を変える．
- Iteration 1で「`expected: let <name> = <expr>`」だった行のうち，右辺の誤りはmegaparsecのメッセージに変わる．

### 受講者が行う道具の操作

- `.cabal`ファイルの`build-depends`に`megaparsec`と`containers`を追加する．
- 新しいモジュールを`exposed-modules`に登録する．

## Iteration 3: ホバーで値を見る

### 要求

- 変数にカーソルを重ねると(定義と使用のどちらでもよい)，`名前 = 値`を表示する．
- 値は，それまでの定義を上から順に評価して求める．`/`は整数の割り算(切り捨て)である．
- 0で割った場合や，未定義の変数を含む場合は，`名前: 値を計算できません(理由)`を表示する．
- 変数以外の場所では何も表示しない．

### 使用例

```text
let price = 1200
let tax = price * 8 / 100     ← tax にホバー: tax = 96
let bad = price / (tax - 96)  ← bad にホバー: bad: 値を計算できません(division by zero)
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Eval`(新規) | `data EvalError = DivisionByZero \| UndefinedVariable Text`，`evalProgram :: [Statement] -> Map Text (Either EvalError Integer)` |
| `Calc.Query`(新規) | `nameAt :: Int -> Int -> [Statement] -> Maybe Text`(行と列にある変数名) |
| `Lsp.Convert` | `fromPosition :: Position -> (Int, Int)`，`hoverText :: Text -> Either EvalError Integer -> Text` |
| `Lsp.Server` | `textDocument/hover`のリクエストハンドラを追加し，capabilitiesでホバーを宣言する |

### 設計文書の更新

- `c4-component.md`: `Calc.Eval`と`Calc.Query`を加える．
- `code-flow.md`: `Position`から`nameAt`と`evalProgram`を通って`Hover`になる流れを加える．
- `lsp-sequence.md`: `textDocument/hover`のリクエストとレスポンスを加える．
- `c4-context.md`:「ホバー」の関係を加える．

### 学ぶこと

- LSP: リクエストとレスポンス，`Position`と`Range`(0始まり，列はUTF-16の単位)，`null`を返す応答．
- `lsp`ライブラリ：`requestHandler`，`responder`，`|?`型と`InL`/`InR`，`MarkupContent`．
- Haskell: `Data.Map`，`Either`のモナドで失敗を伝える評価器，`Maybe`の連鎖．

### 既存のテストへの影響

なし．

### 受講者が行う道具の操作

- 新しいモジュールを登録する．
- hspecの`--match`で，一部のテストだけを実行する(`cabal test <パッケージ>:test:unit --test-options='--match "Calc.Eval"'`)．

## Iteration 4: 定義と参照をたどる

### 要求

- 変数の使用箇所で「定義へ移動」すると，その変数を定義した行の名前へ移動する．
- 「すべての参照を検索」すると，その変数の使用箇所を一覧にする．エディタが定義も含めるよう求めた場合は，定義も含める．
- 未定義の変数では，どちらも空の結果を返す．

### 使用例

```text
let price = 1200               ← 定義
let tax = price * 8 / 100      ← 使用 1
let total = price + tax        ← 使用 2。ここの price で「定義へ移動」→ 1 行目
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Resolve`(新規) | `data Occurrence = Occurrence {occName :: Text, occSpan :: Span, occKind :: OccKind}`，`data OccKind = Definition \| Use`，`occurrences :: [Statement] -> [Occurrence]` |
| `Calc.Query` | `nameAt`を`occurrenceAt :: Int -> Int -> [Occurrence] -> Maybe Occurrence`に置き換え，`definitionOf :: Text -> [Occurrence] -> Maybe Occurrence`，`referencesOf :: Bool -> Text -> [Occurrence] -> [Occurrence]`を追加する |
| `Calc.Check` | 未定義と二重定義の検査を`occurrences`の結果から行うよう書き直す |
| `Lsp.Server` | `textDocument/definition`と`textDocument/references`のハンドラを追加する |

### リファクタリング

`Calc.Check`と`Calc.Query`が別々に構文木をたどっていた処理を，`Calc.Resolve`の`occurrences`にまとめる．Iteration 2・3のテストはそのまま通る．

### 設計文書の更新

- `c4-component.md`: `Calc.Resolve`を加え，`Calc.Check`と`Calc.Query`の依存先を変える．
- `code-flow.md`: `[Statement]` → `[Occurrence]`を中心に描き直す．
- `lsp-sequence.md`: 2つのリクエストを加える．
- `c4-context.md`:「定義へ移動」「参照」の関係を加える．

### 学ぶこと

- LSP: `Location`とURI，`ReferenceContext`(`includeDeclaration`)．
- 名前解決の表を一度作って使い回す設計．
- 既存のテストを安全網にしたリファクタリング．

### 既存のテストへの影響

- `nameAt`のテストを`occurrenceAt`のテストに書き換える．

### 受講者が行う道具の操作

- 新しいモジュールを登録する．
- 統合テストだけを実行する．

## Iteration 5: 補完する

### 要求

- `=`の右辺で補完を求めると，その行より前で定義された変数を候補に出す．候補には値を添える(`price = 1200`)．
- 入力中の単語の接頭辞で候補を絞る．
- 行頭で補完を求めると，キーワード`let`を候補に出す．
- 書きかけで解析できない行でも補完できる．

### 使用例

```text
let price = 1200
let pages = 30
let total = p|     ← 候補: price (= 1200)，pages (= 30)
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Complete`(新規) | `data Candidate = Keyword Text \| Variable Text (Either EvalError Integer)`，`candidates :: Int -> Int -> Text -> [Statement] -> [Candidate]`(行，列，その行の文字列，解析済みの文) |
| `Lsp.Convert` | `toCompletionItem :: Candidate -> CompletionItem` |
| `Lsp.Server` | `textDocument/completion`のハンドラを追加し，capabilitiesで補完を宣言する |

### 設計文書の更新

- `c4-component.md`: `Calc.Complete`を加える．
- `code-flow.md`: 行の文字列と`[Statement]`から`[Candidate]`を経て`[CompletionItem]`になる流れを加える．
- `lsp-sequence.md`: `textDocument/completion`を加える．
- `c4-context.md`:「補完」の関係を加える．

### 学ぶこと

- LSP: `CompletionItem`と`CompletionItemKind`，補完の起点．
- 書きかけの入力を扱う考え方：解析できた部分と，カーソル前の文字列を組み合わせる．
- `Data.Text`の`takeWhileEnd`，`isPrefixOf`．

### 既存のテストへの影響

なし．

### 受講者が行う道具の操作

- 新しいモジュールを登録する．

## Iteration 6: リネームする

### 要求

- 変数の上でリネームを始めると，その変数の範囲を返す(変数以外では始められない)．
- 新しい名前を受け取ると，定義と使用のすべてを書き換える編集を返す．
- 新しい名前が規則に合わない場合，`let`である場合，既にある名前と重なる場合は，理由を添えたエラーを返す．このとき文書は書き換えない．

### 使用例

```text
let rate = 8
let tax = 1200 * rate / 100

rate → taxRate にリネーム:
let taxRate = 8
let tax = 1200 * taxRate / 100

rate → tax にリネーム: エラー「'tax' is already defined」
```

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Rename`(新規) | `data RenameError = InvalidName Text \| AlreadyDefined Text`，`renameEdits :: Text -> Text -> [Occurrence] -> Either RenameError [(Span, Text)]` |
| `Lsp.Convert` | `toWorkspaceEdit :: Uri -> [(Span, Text)] -> WorkspaceEdit` |
| `Lsp.Server` | `textDocument/prepareRename`と`textDocument/rename`のハンドラを追加する |

### 設計文書の更新

- `c4-component.md`: `Calc.Rename`を加える．
- `code-flow.md`: `renameEdits`の成功と失敗の枝を加える．
- `lsp-sequence.md`: `prepareRename` → `rename`の順と，エラーレスポンスの分岐(`alt`)を加える．
- `c4-context.md`:「リネーム」の関係を加える．

### 学ぶこと

- LSP: `WorkspaceEdit`と`TextEdit`，`ResponseError`によるエラーの返し方．
- QuickCheck:「リネームして元の名前に戻すと元の文書になる」という性質のテスト．

### 既存のテストへの影響

なし．

### 受講者が行う道具の操作

- テストスイートの`build-depends`に`QuickCheck`と`hspec`のQuickCheck連携を追加する．

## Iteration 7: アウトラインと差分同期

### 要求

- アウトラインに，文書の定義を上から順に並べる．各項目には値を添える．
- エディタからは変更部分だけを受け取る(差分同期)．
- 文書の解析結果は，文書が変わったときに1回だけ作り，ホバー・定義・参照・補完・リネーム・アウトラインで使い回す．
- これまでのIterationの機能は，そのまま動く．

### 使用例

冒頭の「完成したプログラムの使用例」がすべて動く．

### モジュール

| モジュール | 内容 |
| --- | --- |
| `Calc.Analysis`(新規) | `data Analysis = Analysis {...}`(問題，文，出現，評価結果)，`analyze :: Text -> Analysis` |
| `Lsp.Convert` | `toDocumentSymbol :: Statement -> Either EvalError Integer -> DocumentSymbol` |
| `Lsp.State`(新規) | `type Cache = TVar (Map NormalizedUri Analysis)`，`updateAnalysis`，`lookupAnalysis` |
| `Lsp.Server` | `textDocument/documentSymbol`のハンドラを追加し，同期の方式を差分に変え，各ハンドラがキャッシュを使うよう書き直す |

### リファクタリング

各ハンドラで文書の取得と解析を繰り返していた処理を，`Calc.Analysis`と`Lsp.State`にまとめる．Iteration 0〜6のテストはそのまま通る．

### 設計文書の更新

- `c4-component.md`: `Calc.Analysis`と`Lsp.State`を加え，依存を整理する．
- `code-flow.md`: `analyze`を起点に描き直す．
- `lsp-sequence.md`: `didChange`でキャッシュを更新し，以降のリクエストがキャッシュを読む流れにする．`documentSymbol`を加える．
- `c4-context.md`:「アウトライン」の関係を加え，完成形にする．

### 学ぶこと

- LSP: `DocumentSymbol`，`TextDocumentSyncKind`のFullとIncremental，VFSが差分を適用する仕組み．
- Haskell: STMと`TVar`による共有状態，`MonadIO`と`liftIO`．

### 既存のテストへの影響

なし(振る舞いは変えない)．

### 受講者が行う道具の操作

- `build-depends`に`stm`を追加する．
