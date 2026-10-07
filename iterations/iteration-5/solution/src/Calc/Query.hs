-- | Finds names and their occurrences in a Calc program.
module Calc.Query (occurrenceAt, definitionOf, referencesOf) where

import Calc.Resolve (OccKind (..), Occurrence (..))
import Calc.Syntax (Span (..))
import Data.List (find)
import Data.Text (Text)

-- | The occurrence at a line and column, if any.
occurrenceAt :: Int -> Int -> [Occurrence] -> Maybe Occurrence
occurrenceAt line column = find (\occurrence -> occSpan occurrence `contains` (line, column))

-- | The first definition of a name.
definitionOf :: Text -> [Occurrence] -> Maybe Occurrence
definitionOf name = find (\occurrence -> occName occurrence == name && occKind occurrence == Definition)

{- | The uses of a defined name, and its definitions when the first argument is 'True'.
A name that is never defined has no references.
-}
referencesOf :: Bool -> Text -> [Occurrence] -> [Occurrence]
referencesOf includeDefinitions name occs = case definitionOf name occs of
  Nothing -> []
  Just _ -> filter wanted occs
 where
  wanted occurrence =
    occName occurrence == name && (occKind occurrence == Use || includeDefinitions)

-- | Whether a position is on one of the characters of a span.
contains :: Span -> (Int, Int) -> Bool
contains (Span line start end) (l, c) = line == l && start <= c && c < end
