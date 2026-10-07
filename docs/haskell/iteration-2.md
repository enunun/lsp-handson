# Iteration 2のノート：megaparsecと再帰的なデータ型

Iteration 2では，`=`の右辺を式として構文解析し，未定義の変数と二重定義を見つける．
このノートでは，パーサコンビネータのライブラリmegaparsec，式を表す再帰的なデータ型と再帰関数，`mapAccumL`と`Data.Set`による名前の検査を説明する．

## megaparsecの考え方

megaparsecでは，「文字列から値を読み取るもの」を`Parser a`という型の値として扱う．
小さなパーサ(文字列`let`，整数，名前)を組み合わせて，大きなパーサ(文，式)を作る．

```haskell
import Data.Text (Text)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L

type Parser = Parsec Void Text
```

`Parsec Void Text`は，「独自のエラーを持たず(`Void`)，`Text`を読むパーサ」である．
REPLでは，`parseTest`で結果やエラーを表示できる．

```text
ghci> parseTest (string "let" :: Parser Text) "let x"
"let"
ghci> parseTest (string "let" :: Parser Text) "lex"
1:1:
  |
1 | lex
  | ^^^
unexpected "lex"
expecting "let"
ghci> parseTest (L.decimal :: Parser Integer) "1200 yen"
1200
```

`parseTest`は，読めたところまでの結果を表示する．
入力の最後まで読んだことを確かめるには，`eof`を続ける．

```text
ghci> parseTest (L.decimal <* eof :: Parser Integer) "12a"
1:3:
  |
1 | 12a
  |   ^
unexpected 'a'
expecting digit or end of input
```

プログラムの中では`parse`を使う．
結果は`Either (ParseErrorBundle Text Void) a`で，失敗なら`Left`にエラーが入る．

```haskell
parse (hspace *> statement lineNo <* eof) "" line
```

2つ目の引数は，エラーの表示に使うファイル名である．

## 組み合わせ方

| 書き方 | 意味 |
| --- | --- |
| `f <$> p` | `p`で読み，結果に`f`を使う |
| `f <$> p <*> q` | `p`，`q`の順に読み，2つの結果を`f`に渡す |
| `p <* q` | `p`，`q`の順に読み，`p`の結果を返す |
| `p *> q` | `p`，`q`の順に読み，`q`の結果を返す |
| `x <$ p` | `p`で読み，結果の代わりに`x`を返す |
| `p <\|> q` | `p`を試し，入力を消費せずに失敗したら`q`を試す |
| `many p` | `p`を0回以上くり返して読み，結果の一覧を返す |
| `notFollowedBy p` | 次の入力が`p`で読めないことを確かめる．入力は消費しない |
| `p <?> "name"` | `p`が失敗したときのメッセージで，期待したものを`name`と呼ぶ |
| `getOffset` | 今読んでいる位置(入力の先頭から何文字目か)を返す |

```text
ghci> parseTest ((,) <$> (L.decimal <* hspace) <*> string "yen" :: Parser (Integer, Text)) "1200 yen"
(1200,"yen")
ghci> parseTest (many (char 'a') :: Parser String) "aab"
"aa"
ghci> parseTest (string "let" <* notFollowedBy letterChar :: Parser Text) "letter"
1:4:
  |
1 | letter
  |    ^
unexpected 't'
ghci> parseTest (Left <$> L.decimal <|> Right <$> string "x" :: Parser (Either Integer Text)) "x"
Right "x"
ghci> parseTest (L.decimal <?> "price" :: Parser Integer) "abc"
1:1:
  |
1 | abc
  | ^
unexpected 'a'
expecting price
ghci> parseTest (string "ab" *> getOffset :: Parser Int) "abc"
2
```

`do`記法でも書ける．
読んだ結果に名前を付けたいときは`do`が読みやすい．

```haskell
located :: Int -> Parser a -> Parser (a, Span)
located lineNo p = do
  start <- getOffset
  result <- p
  end <- getOffset
  pure (result, Span lineNo start end)
```

Calcでは1行ずつ読むので，`getOffset`の値がそのまま列になる．

## 空白とコメント(`Text.Megaparsec.Char.Lexer`)

字句(語)のあとの空白とコメントを読み飛ばす部品が，`Text.Megaparsec.Char.Lexer`にある．

```haskell
-- | Spaces and a comment that runs to the end of the line.
spaces :: Parser ()
spaces = L.space hspace1 (L.skipLineComment "--") empty

lexeme :: Parser a -> Parser a
lexeme = L.lexeme spaces

symbol :: Text -> Parser Text
symbol = L.symbol spaces
```

- `L.space`は，空白(`hspace1`は改行以外の空白)，行コメント，ブロックコメント(`empty`はなし)を読み飛ばす．
- `lexeme p`は，`p`で読んだあとの空白とコメントを読み飛ばす．
- `symbol "="`は，`=`を読み，そのあとの空白とコメントを読み飛ばす．
- `L.decimal`は10進数の整数を読む．

字句ごとに`lexeme`か`symbol`を使うと，空白を読み飛ばす処理を文法から切り離せる．

## エラーの取り出し

`ParseErrorBundle`は，1つ以上のエラー(`ParseError`)をまとめたものである．

| 関数 | 結果 |
| --- | --- |
| `bundleErrors bundle` | エラーの一覧(`NonEmpty (ParseError Text Void)`) |
| `errorOffset err` | エラーが起きた位置 |
| `parseErrorTextPretty err` | `unexpected …`と`expecting …`の行からなるメッセージ(`String`) |

`NonEmpty`は，要素を1つ以上持つことを型で保証した一覧である．
`Data.List.NonEmpty`の`NE.head`で最初の要素を取り出せる．

## 再帰的なデータ型

式は，整数，変数，2つの式を演算子でつないだもの，のどれかである．
最後の場合の中にも式が入るので，型の定義が自分自身を使う．

```haskell
data Expr
  = Number Integer
  | Var Text Span
  | BinOp Op Expr Expr
  deriving (Eq, Show)

data Op = Add | Sub | Mul | Div
  deriving (Eq, Show)
```

`1 + 2 * 3`は`BinOp Add (Number 1) (BinOp Mul (Number 2) (Number 3))`になる．
木の形が，計算の順序(優先順位)を表している．

再帰的なデータ型は，同じ形の再帰関数で処理する．
コンストラクタごとに1つの式を書き，中の式には同じ関数を使う．

```haskell
-- | The variables used in an expression, from left to right.
variables :: Expr -> [(Text, Span)]
variables (Number _) = []
variables (Var name location) = [(name, location)]
variables (BinOp _ left right) = variables left <> variables right
```

## 演算子の優先順位と左結合

`1 - 2 - 3`は`(1 - 2) - 3`と読む(左結合)．
`1 + 2 * 3`は`1 + (2 * 3)`と読む(`*`が`+`より強く結合する)．

これをパーサで表すには，強さごとに段を分ける．

```text
expression = term   { (+|-) term }      弱い段
term       = factor { (*|/) factor }    強い段
factor     = 整数 | 変数 | ( expression )
```

`{ … }`は0回以上のくり返しである．
「被演算子1つと，(演算子，被演算子)の組の一覧」を読み，`foldl`で左から木に組み立てる．

```haskell
chainLeft :: Parser Expr -> Parser Op -> Parser Expr
chainLeft operand operator = foldl combine <$> operand <*> many ((,) <$> operator <*> operand)
 where
  combine left (op, right) = BinOp op left right
```

`foldl f z [x1, x2, x3]`は`f (f (f z x1) x2) x3`で，左から順に畳み込む．

```text
ghci> foldl (\acc x -> acc * 10 + x) 0 [1, 2, 3 :: Int]
123
```

`1 - 2 - 3`なら，`Number 1`と`[(Sub, Number 2), (Sub, Number 3)]`から`BinOp Sub (BinOp Sub (Number 1) (Number 2)) (Number 3)`ができる．

## 名前を持ち回る(`mapAccumL`と`Data.Set`)

未定義の変数を見つけるには，上の行から順に「ここまでに定義された名前」を覚えておく必要がある．
`mapAccumL`は，状態を持ち回りながら一覧の各要素を変換する．

```haskell
mapAccumL :: (s -> a -> (s, b)) -> s -> [a] -> (s, [b])
```

```text
ghci> import Data.List (mapAccumL)
ghci> mapAccumL (\total x -> (total + x, total + x)) 0 [1, 2, 3 :: Int]
(6,[1,3,6])
```

Calcでは，状態が定義済みの名前の集合，各要素の結果がその文の問題の一覧である．

集合は`containers`パッケージの`Data.Set`で表す．

```text
ghci> import Data.Set qualified as Set
ghci> Set.member "a" (Set.fromList ["a", "b" :: Text])
True
ghci> Set.insert "c" (Set.fromList ["a", "b" :: Text])
fromList ["a","b","c"]
```

`Set.empty`は空の集合である．
一覧の`elem`と違い，`Set.member`は要素が多くても速い．

## 依存パッケージを足す

新しいライブラリを使うときは，`.cabal`ファイルの`library`の`build-depends`に足す．

```text
  build-depends:
    , base        >=4.20 && <5
    , containers
    , lens
    , lsp         ==2.8.*
    , lsp-types
    , megaparsec
    , text
```

テストのモジュールが`Data.Text`を直接importする場合は，テストスイートの`build-depends`にも`text`を足す．

## REPLの課題

`cabal repl calc-lsp-iter2-exercise`で，`Parser`の型を定義してから次を試す．

1. `parseTest`で，`many (L.decimal <* hspace)`に`"1 2 3"`を読ませる．
2. `string "let"`と`string "let" <* notFollowedBy letterChar`に，それぞれ`"letter"`を読ませて結果を比べる．
3. `foldl1 (-)`と`foldr1 (-)`で`[1, 2, 3]`を畳み込み，結果を比べる．`1 - 2 - 3`と同じになるのはどちらか．
