-- | Finds what is at a position in a Calc program.
module Calc.Query (nameAt) where

import Calc.Syntax (Expr (..), Span (..), Statement (..))
import Data.Maybe (listToMaybe)
import Data.Text (Text)

-- | The name defined or used at a line and column, if any.
nameAt :: Int -> Int -> [Statement] -> Maybe Text
nameAt line column statements =
  listToMaybe
    [name | (name, location) <- concatMap names statements, location `contains` (line, column)]
 where
  names (Statement name location expr) = (name, location) : variables expr

-- | The variables used in an expression, from left to right.
variables :: Expr -> [(Text, Span)]
variables (Number _) = []
variables (Var name location) = [(name, location)]
variables (BinOp _ left right) = variables left <> variables right

-- | Whether a position is on one of the characters of a span.
contains :: Span -> (Int, Int) -> Bool
contains (Span line start end) (l, c) = line == l && start <= c && c < end
