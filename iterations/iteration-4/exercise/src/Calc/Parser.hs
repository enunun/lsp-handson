{-# LANGUAGE OverloadedStrings #-}

-- | Reads the lines of a Calc program.
module Calc.Parser (parseLine, parseProgram) where

import Calc.Syntax (Expr (..), Op (..), Problem (..), Span (..), Statement (..))
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Either (partitionEithers)
import Data.List.NonEmpty qualified as NE
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char (hspace, hspace1, string)
import Text.Megaparsec.Char.Lexer qualified as L

type Parser = Parsec Void Text

-- | Reads one line, given its line number. Blank lines and comment lines give 'Nothing'.
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line
  | T.null body || "--" `T.isPrefixOf` body = Nothing
  | otherwise = Just $ case parse (hspace *> header lineNo) "" line of
      Left _ -> Left (Problem (Span lineNo 0 (T.length line)) "expected: let <name> = <expr>")
      Right _ -> case parse (hspace *> statement lineNo <* eof) "" line of
        Left errors -> Left (toProblem lineNo line errors)
        Right parsed -> Right parsed
 where
  body = T.stripStart line

-- | Reads every line of a program, collecting the problems and the statements in order.
parseProgram :: Text -> ([Problem], [Statement])
parseProgram text = partitionEithers (mapMaybe (uncurry parseLine) (zip [0 ..] (T.lines text)))

-- | The part before the expression: @let <name> =@.
header :: Int -> Parser (Text, Span)
header lineNo = do
  _ <- lexeme (string "let" <* notFollowedBy (satisfy isNameChar))
  named <- lexeme (located lineNo name)
  _ <- symbol "="
  pure named

statement :: Int -> Parser Statement
statement lineNo = do
  (named, location) <- header lineNo
  Statement named location <$> expression lineNo

-- | @+@ and @-@ bind more loosely than @*@ and @/@. Operators of the same strength group to the left.
expression :: Int -> Parser Expr
expression lineNo = chainLeft term (Add <$ symbol "+" <|> Sub <$ symbol "-")
 where
  term = chainLeft factor (Mul <$ symbol "*" <|> Div <$ symbol "/")
  factor =
    Number <$> lexeme L.decimal
      <|> uncurry Var <$> lexeme (located lineNo name)
      <|> (symbol "(" *> expression lineNo <* symbol ")")

-- | Reads one or more operands separated by operators, and combines them from the left.
chainLeft :: Parser Expr -> Parser Op -> Parser Expr
chainLeft operand operator = foldl combine <$> operand <*> many ((,) <$> operator <*> operand)
 where
  combine left (op, right) = BinOp op left right

-- | A name starts with an ASCII letter and continues with ASCII letters and digits.
name :: Parser Text
name = T.cons <$> satisfy isLetter <*> takeWhileP Nothing isNameChar <?> "name"

isLetter :: Char -> Bool
isLetter c = isAsciiLower c || isAsciiUpper c

isNameChar :: Char -> Bool
isNameChar c = isLetter c || isDigit c

-- | Runs a parser and returns its result with the columns it read.
located :: Int -> Parser a -> Parser (a, Span)
located lineNo p = do
  start <- getOffset
  result <- p
  end <- getOffset
  pure (result, Span lineNo start end)

-- | Spaces and a comment that runs to the end of the line.
spaces :: Parser ()
spaces = L.space hspace1 (L.skipLineComment "--") empty

lexeme :: Parser a -> Parser a
lexeme = L.lexeme spaces

symbol :: Text -> Parser Text
symbol = L.symbol spaces

-- | A problem at the position where the expression could not be read, up to the end of the line.
toProblem :: Int -> Text -> ParseErrorBundle Text Void -> Problem
toProblem lineNo line errors =
  Problem
    (Span lineNo column (max column (T.length line)))
    (T.strip (T.pack (parseErrorTextPretty firstError)))
 where
  firstError = NE.head (bundleErrors errors)
  column = errorOffset firstError
