-- | Renames a name everywhere it occurs.
module Calc.Rename (RenameError (..), renameEdits) where

import Calc.Parser (isValidName)
import Calc.Query (definitionOf)
import Calc.Resolve (Occurrence (..))
import Calc.Syntax (Span)
import Data.Maybe (isJust)
import Data.Text (Text)

-- | Why a name cannot be renamed.
data RenameError
  = InvalidName Text
  | AlreadyDefined Text
  deriving (Eq, Show)

{- | The edits that rename every occurrence of the first name to the second name. The new name must
be a valid name that no other definition uses.
-}
renameEdits :: Text -> Text -> [Occurrence] -> Either RenameError [(Span, Text)]
renameEdits old new occs
  | not (isValidName new) = Left (InvalidName new)
  | new /= old && isJust (definitionOf new occs) = Left (AlreadyDefined new)
  | otherwise = Right [(occSpan occurrence, new) | occurrence <- occs, occName occurrence == old]
