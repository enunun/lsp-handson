{-# LANGUAGE OverloadedStrings #-}

-- | Completion candidates for the word being typed.
module Calc.Complete (Candidate (..), candidates) where

import Calc.Eval (EvalError, evalProgram)
import Calc.Syntax (Span (..), Statement (..))
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, isSpace)
import Data.List (nub)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

data Candidate
  = Keyword Text
  | Variable Text (Either EvalError Integer)
  deriving (Eq, Show)

{- | The candidates at a line and column, given the text of that line and the statements that
could be read. The keyword @let@ is offered at the start of a line, and the variables defined
on the lines above are offered after @=@. Only candidates that start with the word before the
cursor are kept.
-}
candidates :: Int -> Int -> Text -> [Statement] -> [Candidate]
candidates line column lineText statements = filter ((prefix `T.isPrefixOf`) . label) offered
 where
  typed = T.take column lineText
  prefix = T.takeWhileEnd isNameChar typed
  before = T.dropEnd (T.length prefix) typed
  offered
    | T.all isSpace before = [Keyword "let"]
    | "=" `T.isInfixOf` before = variablesAbove line statements
    | otherwise = []

-- | The variables defined on the lines above a line, in the order of their first definitions.
variablesAbove :: Int -> [Statement] -> [Candidate]
variablesAbove line statements =
  [Variable name value | name <- nub (map stmtName above), Just value <- [Map.lookup name values]]
 where
  above = filter (\statement -> spanLine (stmtSpan statement) < line) statements
  values = evalProgram above

label :: Candidate -> Text
label (Keyword word) = word
label (Variable name _) = name

isNameChar :: Char -> Bool
isNameChar c = isAsciiLower c || isAsciiUpper c || isDigit c
