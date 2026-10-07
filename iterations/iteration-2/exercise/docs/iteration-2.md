# Iteration 2: 式を解析して名前の誤りを見つける

このIterationでは，`=`の右辺を式として構文解析し，定義されていない変数と，同じ名前の二重定義に診断を付ける．
パーサコンビネータのmegaparsec，再帰的なデータ型，`mapAccumL`と`Data.Set`による名前の検査を学ぶ．

## 2-1 準備

1. ルートの`cabal.project`の`packages`に，`iterations/iteration-2/exercise`の行を足す．
2. ビルドし，Iteration 1から引き継いだテストがすべて通ることを確かめる．
3. エディタが起動するサーバをこのパッケージにして，`examples/sample.calc`を開く．`fee`は定義されていないが，まだ波線は出ない．

## 2-2 文法と概念

[Iteration 2のノート](../../../../docs/haskell/iteration-2.md)を読み，最後の「REPLの課題」を解く．
megaparsecをREPLで使うには，先に2-5の「依存パッケージ」の手順で`build-depends`に`megaparsec`を足す．

## 2-3 テストリスト

次の要求と使用例から，テストの項目を`TESTLIST.md`に書き出す．

### 要求

- `=`の右辺を式として解析する．式は整数，変数，`+` `-` `*` `/`，括弧からなる．`*` `/`は`+` `-`より強く結合し，同じ強さの演算子は左から結合する．
- 字句の間の空白は省略できる．行末の`-- コメント`を許す．
- `let <name> =`の部分が読めない行には，これまでどおり行全体に`expected: let <name> = <expr>`を付ける．
- 右辺の式が読めない行には，読めなかった位置から行末までに，megaparsecのエラーメッセージを付ける．1行の誤りは，ほかの行の解析に影響しない．
- 変数が，それより前の行で定義されていなければ，その変数に`undefined variable '名前'`を付ける．
- 同じ名前を2回定義したら，2回目の名前に`'名前' is already defined`を付ける．

### 使用例

```text
let price = 1200
let tax = price * 8 / 100
let total = price + tax + fee    ← fee に診断: undefined variable 'fee'
let price = 1000                 ← price に診断: 'price' is already defined
let broken = (1 + 2              ← 行末に診断: unexpected end of input ...
```

### 作るもの

| モジュール | 作るもの |
| --- | --- |
| `Calc.Syntax` | `data Expr = Number Integer \| Var Text Span \| BinOp Op Expr Expr`，`data Op = Add \| Sub \| Mul \| Div`．`Statement`に`stmtExpr :: Expr`を足す |
| `Calc.Parser` | megaparsecで書き直す．`parseLine`と`parseProgram`の型は変えない |
| `Calc.Check` | `checkProgram :: [Statement] -> [Problem]` |
| `Lsp.Server` | 診断を，`parseProgram`と`checkProgram`の両方の問題から作る |

`Var`の`Span`は，変数を使った位置である．

### 書くときに考えること

- 式の読み方で結果が分かれるのはどこか．変数，1つの演算子，同じ強さの演算子の並び，強さの違う演算子の並び，括弧，空白のない書き方，行末のコメントを1つずつ確かめる．
- 式が読めないときの位置とメッセージを，どの入力で確かめるか．行の途中で止まる場合と，行末で止まる場合がある．
- 名前の検査で，定義より前の行で使う場合と，自分の定義の中で使う場合はどうなるか．
- 1つの文書に複数の問題があるとき，どの順に並ぶか．
- 引き継いだテストのうち，期待値が変わるものはどれか．`Statement`に式が加わること，右辺の誤りのメッセージが変わることを考える．

## 2-4 設計文書

- `c4-context.md`: 診断の種類が増える．
- `c4-component.md`: 名前を検査する新しいモジュールと，外部ライブラリ(megaparsec，containers)への依存を足す．名前の検査が，構文解析のモジュールを使う必要があるかを考える．
- `code-flow.md`: `parseProgram`の結果の2つの部分が，それぞれどこへ流れるか．2種類の問題をどこで合わせるか．`parseLine`の読み方の決まり(どこまで読めたら式の誤りとみなすか)を図の下に書く．
- `lsp-sequence.md`: 変える必要があるかを確かめる．

## 2-5 テストファーストの実装

### 依存パッケージ

`.cabal`ファイルの`library`の`build-depends`に`megaparsec`と`containers`を足す．
`Calc.Check`を`exposed-modules`に，テストのモジュールを`other-modules`に足す．
テストで`Data.Text`の`Text`を書くなら，`test-suite unit`の`build-depends`に`text`を足す．

### `Statement`に式を足す

最初に`Expr`と`Op`を定義し，`Statement`に`stmtExpr`を足す．
引き継いだテストはコンパイルできなくなる．
エラーを読み，テストリストで見つけた「期待値が変わるテスト」と一致するかを確かめてから，期待値を直す．
このとき`parseLine`は，右辺をまだ読まない仮の実装(例：常に`Number 0`)でよい．

### megaparsecへの書き換え

- まず，引き継いだテストが通ったまま，`parseLine`の中身をmegaparsecで書き直す(Refactor)．`let <name> =`の部分を読むパーサと，そのあとに続く式のパーサに分けると，「どこまで読めたら式の誤りか」を決めやすい．
- `let`のあとに英数字が続く場合(`letx`)は，`let`と読まない．
- 名前と変数の位置は`getOffset`で取る．
- 字句ごとに`lexeme`か`symbol`を使い，空白とコメントを読み飛ばす．
- `parse`は，`eof`を続けないと，読めたところまでで成功する．

### 式

- 被演算子と演算子の並びを左から木に組み立てる補助関数を1つ作り，強さの段ごとに使う．
- 括弧の中は，最初の段(式全体)に戻る．

### 式の誤り

- 誤りの位置は`errorOffset`，メッセージは`parseErrorTextPretty`で取り出せる．メッセージの末尾には改行が付くので取り除く．
- テストの期待値に書くメッセージは，REPLで`parseLine`を実行して確かめる．

### `checkProgram`

- 式に含まれる変数を左から集める再帰関数を作る．
- `mapAccumL`で，定義済みの名前の`Set`を持ち回る．各文では，まず式の変数を調べ，それから名前を集合に加える．

### 統合テスト

`DiagnosticsSpec.hs`に，未定義の変数に診断が付くテストを足す．

### エディタで確かめる

`examples/sample.calc`の`fee`に波線が付くこと，`let fee = 50`を上に足すと消えることを確かめる．

## 2-6 振り返り

1. 自分の`TESTLIST.md`と，模範解答の`TESTLIST.md`を見比べる．
2. `let <name> =`の部分と式の部分を分けて読んだのはなぜか．分けないと，`price * 2`のような行のメッセージはどうなるか．
3. `chainLeft`(または自分で作った補助関数)を`foldr`で書くと，`1 - 2 - 3`はどんな木になるか．
4. `Calc.Check`を`Calc.Parser`と別のモジュールにしたことで，テストはどう書きやすくなったか．
5. 設計文書と実装を見比べ，違うところがあれば設計文書を直す．`mise run lint:design`で照合する．

## 2-7 発展課題

単項のマイナス(`-5`，`-(1 + 2)`)を読めるようにする．
`Expr`に`Neg Expr`を足すか，`BinOp Sub (Number 0) …`として読むかを，設計文書で比べてから決める．
`2 * -3`や`- - 1`をどう扱うかもテストリストに書く．
