# Iteration 5: 補完する

このIterationでは，入力中の語を補う候補を出す．
LSPの補完と`CompletionItem`，書きかけで解析できない入力の扱い方，lensでレコードの一部を設定する書き方を学ぶ．

## 5-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-5/exercise`の行を足す．
2. ビルドし，Iteration 4から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにする．`examples/sample.calc`の末尾に`let x = p`と入力しても，VS Codeは文書の中の単語を候補に出すだけで，値は表示されない．

## 5-2 文法と概念

[Iteration 5のノート](../../../../docs/haskell/iteration-5.md)を読み，最後の「REPLの課題」を解く．

## 5-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- `=`の右辺で補完を求めると，その行より上で定義された変数を候補に出す．候補には，ホバーと同じ`名前 = 値`を詳細として添える．
- 同じ名前が2回定義されていれば，最初の定義の値で1回だけ出す．
- 入力中の語の接頭辞で候補を絞る．
- 行頭で補完を求めると，キーワード`let`を候補に出す．定義の名前を入力している間(`let`と`=`の間)は，候補を出さない．
- 書きかけで解析できない行でも補完できる．

### 使用例

```text
let price = 1200
let pages = 30
let total = p|     ← 候補: price(詳細: price = 1200)，pages(詳細: pages = 30)
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Complete` | `data Candidate = Keyword Text \| Variable Text (Either EvalError Integer)`，`candidates :: Int -> Int -> Text -> [Statement] -> [Candidate]`(行，列，その行の文字列，解析できた文) |
| `Lsp.Convert` | `toCompletionItem :: Candidate -> CompletionItem` |
| `Lsp.Server` | `textDocument/completion`のハンドラ |

### 書くときに考えること

- カーソルの前の文字列によって，候補の種類が変わる．行頭，`let`の入力中，名前の入力中，右辺のそれぞれで何を出すか．
- 右辺の候補について，絞り込み，カーソルの行と下の行の変数，書きかけの行，二重定義，値が計算できない変数を確かめる．
- `candidates`のテストを書きやすくするために，複数の行の一覧から「最後の行の末尾で補完する」補助の関数を作るとよい．

## 5-4 設計文書

- `c4-context.md`: 補完の要求と候補のやり取りを足す．
- `c4-component.md`: 新しいモジュールを足す．`Calc.Complete`は値を添えるために何を使うか．`Lsp.Convert`の依存も増える．
- `code-flow.md`: 補完の流れを3つ目の図にする．`candidates`が受け取る3つの情報(位置，行の文字列，文)がどこから来るか．候補の種類を決める決まりを図の下に書く．
- `lsp-sequence.md`: 補完のリクエストと応答を足す．

## 5-5 テストファーストの実装

新しいモジュールを登録する．
`Lsp.Convert`のテストでlensを使うなら，`test-suite unit`の`build-depends`に`lens`を足す．

### `candidates`

- まずカーソルの前の文字列(`T.take column lineText`)を，入力中の語と，その前の部分に分ける．
- 前の部分が空白だけなら行頭，`=`を含むなら右辺である．
- 右辺の候補は，カーソルの行より上の文だけを使う．値は`evalProgram`で求める．
- 二重定義の扱いは，`Data.List`の`nub`が使える．
- 最後に，入力中の語で始まる候補だけを残す．

### `toCompletionItem`

- `CompletionItem`のすべてのフィールドを`Nothing`にしたひな形を作り，`&`と`?~`で`_kind`と`_detail`を設定する．
- 詳細の文字列は`hoverText`で作れる．

### 補完のハンドラ

- 統合テストは`test/integration/CompletionSpec.hs`に書き，lsp-testの`getCompletions`を使う．
- ハンドラは，VFSの文書から，カーソルのある行の文字列と，解析できた文の両方を取り出す．
- 行番号が文書の行数を超えていても失敗しないようにする．

### エディタで確かめる

`examples/sample.calc`の末尾で`let x = p`と入力すると，`price`と`p`で始まる変数が候補に出て，詳細に値が表示される．

## 5-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. 書きかけの行で候補を出すために，`candidates`は何を受け取るようにしたか．解析できた文だけを受け取ると，どんな場合に困るか．
3. `CompletionItem`をレコード構文だけで作る場合と，ひな形とlensで作る場合を比べる．
4. 候補を入力中の語で絞り込まなくても，VS Codeは候補を絞って表示する．それでもサーバで絞り込むのはなぜか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 5-7 発展課題

右辺で`(`を入力した直後にも，補完を自動で始める．
`optCompletionTriggerCharacters`に`(`を設定すると，エディタは`(`の入力で補完を要求する．
そのとき入力中の語は空なので，すべての変数が候補になることをテストリストに書く．
