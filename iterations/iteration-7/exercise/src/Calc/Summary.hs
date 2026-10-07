-- | Facts about a Calc document as a whole.
module Calc.Summary (countLines) where

import Data.Text (Text)
import Data.Text qualified as T

-- | The number of lines in a document. A newline at the end does not start a new line.
countLines :: Text -> Int
countLines = length . T.lines
