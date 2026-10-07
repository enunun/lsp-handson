# Iteration 1: 最初の診断を出す

このIterationでは，`let 名前 = 式`の形をしていない行に波線を付ける．
LSPの診断の送り方と，Haskellのレコード，`Maybe`と`Either`の組み合わせ，`Data.Text`による行の検査を学ぶ．

## 1-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-1/exercise`の行を足す．
2. ビルドし，Iteration 0から引き継いだテストがすべて通ることを確かめる．
3. `mise run use-server calc-lsp-iter1-exercise`を実行し，「Calc: Restart Server」でサーバを起動し直す．`examples/sample.calc`を開き，ログに行数が出ることを確かめる．まだ波線は出ない．

## 1-2 文法と概念

[Iteration 1のノート](../../../../docs/haskell/iteration-1.md)を読み，最後の「REPLの課題」を`cabal repl calc-lsp-iter1-exercise`で解く．

## 1-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- 文書を開いたとき，および編集するたびに，サーバは文書を検査して診断を送る．
- 空行と，`--`で始まるコメント行は検査しない．行頭の空白は無視する．
- それ以外の行が`let 名前 = 何か`の形をしていなければ，その行全体に`expected: let <name> = <expr>`という診断を付ける．名前は英字で始まり，英数字が続く．`let`，名前，`=`，何かの間は空白で区切る．
- 正しい形の行だけなら，診断は空になる(以前の波線が消える)．
- 診断の重さはエラー，出どころは`calc`である．

### 使用例

```text
let price = 1200
price * 2          ← 診断: expected: let <name> = <expr>
let 1x = 3         ← 診断: expected: let <name> = <expr>
-- コメント
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Syntax` | `data Span = Span {spanLine :: Int, spanStart :: Int, spanEnd :: Int}`，`data Statement = Statement {stmtName :: Text, stmtSpan :: Span}`，`data Problem = Problem {problemSpan :: Span, problemMessage :: Text}` |
| `Calc.Parser` | `parseLine :: Int -> Text -> Maybe (Either Problem Statement)`(行番号と行の文字列を受け取る)，`parseProgram :: Text -> ([Problem], [Statement])` |
| `Lsp.Convert` | `toRange :: Span -> Range`，`toDiagnostic :: Problem -> Diagnostic` |
| `Lsp.Server` | `didOpen`と`didChange`のハンドラで，診断を送る |

`Statement`の`stmtSpan`は名前の位置を，`Problem`の`problemSpan`は誤りの範囲を表す．
`Span`の列は0から数え，`spanEnd`の位置の文字は含まない．

### 書くときに考えること

- `parseLine`の結果は3通り(調べない，誤り，正しい文)ある．それぞれの例を挙げる．
- 正しい文の名前の位置は，行頭の空白や`let`のあとの空白の数で変わる．
- `let`の形をしていない行には，どんな崩れ方があるか．`let`がない行や，名前が規則に合わない行など，崩れ方ごとに1つの項目にする．
- 単体テストで確かめることと，統合テストで確かめること(開いたときの診断，直したときに診断が消えること)を分ける．
- Iteration 0から引き継いだテストのうち，サーバが診断の通知も送るようになると影響を受けるものはあるか．

## 1-4 設計文書

設計文書を，このIterationの機能に合わせて更新する．

- `c4-context.md`: エディタとサーバの間に，新しいやり取りが1つ増える．利用者に見えるものも増える．
- `c4-component.md`: 新しいモジュールを3つ足す．`Calc.*`がLSPの型に依存しないように，変換を受け持つモジュールをどちら側に置くかを考える．
- `code-flow.md`: `Text`から`publishDiagnostics`までの流れを足す．途中の`([Problem], [Statement])`から何を取り出すか．
- `lsp-sequence.md`: `didOpen`と`didChange`のあとに送るメッセージを足す．

更新したら，`mise run lint:mermaid`で図の構文を確かめる．

## 1-5 テストファーストの実装

テストリストの項目を1つずつ，Red → Green → Refactorで実装する．
新しいモジュールは`.cabal`ファイルの`exposed-modules`に，新しいテストのモジュールは各テストスイートの`other-modules`に足す．
単体テストだけを実行するには，次のコマンドを使う．

```sh
cabal test calc-lsp-iter1-exercise:test:unit
```

### `Calc.Syntax`

- ロードマップのとおりにレコードを定義し，`deriving (Eq, Show)`を付ける．テストの`shouldBe`は，この2つを使う．

### `parseLine`

- 最初のテストは正しい文1つにし，定数を返す仮実装で通す．次のテスト(別の行番号や名前)で，`T.words`を使った本物の実装へ進める．
- 名前の開始列は，行頭の空白の幅，`let`の3文字，`let`のあとの空白の幅の合計である．`T.stripStart`と`T.takeWhile isSpace`が使える．
- 誤りの項目を足すたびに，パターンを1つずつ厳しくする．`("let" : name : "=" : _ : _)`のように，一覧のパターンで語の並びを表せる．
- 名前の判定には`Data.Char`の`isAsciiLower`，`isAsciiUpper`，`isDigit`を使う．

### `parseProgram`

- `T.lines`で行に分け，`zip [0 ..]`で行番号を付ける．
- `mapMaybe`で調べない行を除き，`partitionEithers`で誤りと文に分ける．

### `Lsp.Convert`

- `Position`の行と列の型は`UInt`である．`fromIntegral`で変える．
- `Diagnostic`をレコード構文で作るなら，`DisambiguateRecordFields`を有効にする．

### 診断を送るハンドラ

- 統合テストは`test/integration/DiagnosticsSpec.hs`に書き，lsp-testの`waitForDiagnostics`で診断を待つ．
- ハンドラは，VFSから文書を取り出し，`parseProgram`の誤りを`toDiagnostic`で変えて，`SMethod_TextDocumentPublishDiagnostics`で送る．文書の版は`virtualFileVersion`で取り出せる．
- 誤りがないときも，空の一覧を送る．
- 統合テストが，予想と違うメッセージを受け取って失敗したら，その出力の`But the last message received was:`を読む．

### エディタで確かめる

`mise run use-server calc-lsp-iter1-exercise`を実行してサーバを起動し直し，`examples/sample.calc`に`let`の形でない行を書いて波線が出ること，直すと消えることを確かめる．

## 1-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．崩れた行の種類を，どこまで挙げられたか．
2. `parseLine`が`Maybe (Either Problem Statement)`を返すことで，`parseProgram`はどう書けたか．`Either Problem (Maybe Statement)`だったら，どう変わるか．
3. `Lsp.Convert`を`Calc.*`に置かなかったのはなぜか．
4. 引き継いだテストのうち，どれが，なぜ失敗したか．どう直したか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 1-7 発展課題

行末に空白が残っている行に，重さが警告(`DiagnosticSeverity_Warning`)の診断`trailing whitespace`を付ける．
範囲は，行末の空白の部分だけにする．
`Problem`に重さを持たせるか，別の型を作るかを設計文書で決めてから，テストリスト，実装の順に進める．
