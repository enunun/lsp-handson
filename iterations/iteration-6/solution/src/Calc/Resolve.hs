-- | Where each name in a Calc program is defined and used.
module Calc.Resolve (Occurrence (..), OccKind (..), occurrences) where

import Calc.Syntax (Expr (..), Span, Statement (..))
import Data.Text (Text)

-- | A name at one position in the program.
data Occurrence = Occurrence
  { occName :: Text
  , occSpan :: Span
  , occKind :: OccKind
  }
  deriving (Eq, Show)

data OccKind = Definition | Use
  deriving (Eq, Show)

{- | Every occurrence of a name, in the order of evaluation: for each statement, the variables of
its expression from left to right, then the name it defines.
-}
occurrences :: [Statement] -> [Occurrence]
occurrences = concatMap statementOccurrences
 where
  statementOccurrences (Statement name location expr) =
    uses expr <> [Occurrence name location Definition]

uses :: Expr -> [Occurrence]
uses (Number _) = []
uses (Var name location) = [Occurrence name location Use]
uses (BinOp _ left right) = uses left <> uses right
