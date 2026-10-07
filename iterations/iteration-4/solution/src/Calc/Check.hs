{-# LANGUAGE OverloadedStrings #-}

-- | Checks the names in a Calc program.
module Calc.Check (checkProgram) where

import Calc.Resolve (OccKind (..), Occurrence (..), occurrences)
import Calc.Syntax (Problem (..), Statement)
import Data.List (mapAccumL)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

-- | Reports variables used before their definition, and names defined twice.
checkProgram :: [Statement] -> [Problem]
checkProgram statements = concat (snd (mapAccumL check Set.empty (occurrences statements)))

-- | Checks one occurrence against the names defined before it.
check :: Set Text -> Occurrence -> (Set Text, [Problem])
check defined (Occurrence name location Use)
  | name `Set.member` defined = (defined, [])
  | otherwise = (defined, [Problem location ("undefined variable '" <> name <> "'")])
check defined (Occurrence name location Definition)
  | name `Set.member` defined = (defined, [Problem location ("'" <> name <> "' is already defined")])
  | otherwise = (Set.insert name defined, [])
