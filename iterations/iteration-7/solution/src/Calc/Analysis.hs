-- | Everything the server knows about one version of a document.
module Calc.Analysis (Analysis (..), analyze) where

import Calc.Check (checkProgram)
import Calc.Eval (EvalError, evalProgram)
import Calc.Parser (parseProgram)
import Calc.Resolve (Occurrence, occurrences)
import Calc.Syntax (Problem, Statement)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Text qualified as T

data Analysis = Analysis
  { anLines :: [Text]
  , anProblems :: [Problem]
  , anStatements :: [Statement]
  , anOccurrences :: [Occurrence]
  , anValues :: Map Text (Either EvalError Integer)
  }
  deriving (Eq, Show)

-- | Reads, checks and evaluates a document once.
analyze :: Text -> Analysis
analyze text =
  Analysis
    { anLines = T.lines text
    , anProblems = parseProblems <> checkProgram statements
    , anStatements = statements
    , anOccurrences = occurrences statements
    , anValues = evalProgram statements
    }
 where
  (parseProblems, statements) = parseProgram text
