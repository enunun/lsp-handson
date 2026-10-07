{-# LANGUAGE OverloadedStrings #-}

-- | Checks the names in a Calc program.
module Calc.Check (checkProgram) where

import Calc.Syntax (Expr (..), Problem (..), Span, Statement (..))
import Data.List (mapAccumL)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

-- | Reports variables used before their definition, and names defined twice.
checkProgram :: [Statement] -> [Problem]
checkProgram statements = concat (snd (mapAccumL check Set.empty statements))

-- | Checks one statement against the names defined above it, and adds its name.
check :: Set Text -> Statement -> (Set Text, [Problem])
check defined (Statement name location expr) =
  (Set.insert name defined, undefinedUses <> redefinition)
 where
  undefinedUses =
    [ Problem used ("undefined variable '" <> var <> "'")
    | (var, used) <- variables expr
    , not (var `Set.member` defined)
    ]
  redefinition =
    [Problem location ("'" <> name <> "' is already defined") | name `Set.member` defined]

-- | The variables used in an expression, from left to right.
variables :: Expr -> [(Text, Span)]
variables (Number _) = []
variables (Var name location) = [(name, location)]
variables (BinOp _ left right) = variables left <> variables right
