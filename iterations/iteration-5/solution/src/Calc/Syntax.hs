-- | The parts of a Calc program and the problems found in it.
module Calc.Syntax (
  Span (..),
  Statement (..),
  Expr (..),
  Op (..),
  Problem (..),
) where

import Data.Text (Text)

-- | A range of characters on one line. Lines and columns start at 0, and the end is exclusive.
data Span = Span
  { spanLine :: Int
  , spanStart :: Int
  , spanEnd :: Int
  }
  deriving (Eq, Show)

-- | A line of the form @let <name> = <expr>@. The span covers the name.
data Statement = Statement
  { stmtName :: Text
  , stmtSpan :: Span
  , stmtExpr :: Expr
  }
  deriving (Eq, Show)

-- | An expression. A variable keeps the position where it is used.
data Expr
  = Number Integer
  | Var Text Span
  | BinOp Op Expr Expr
  deriving (Eq, Show)

data Op = Add | Sub | Mul | Div
  deriving (Eq, Show)

-- | Something wrong in the program, reported to the editor as a diagnostic.
data Problem = Problem
  { problemSpan :: Span
  , problemMessage :: Text
  }
  deriving (Eq, Show)
