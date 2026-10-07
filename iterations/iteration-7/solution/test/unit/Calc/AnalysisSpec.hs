{-# LANGUAGE OverloadedStrings #-}

module Calc.AnalysisSpec (spec) where

import Calc.Analysis (Analysis (..), analyze)
import Calc.Check (checkProgram)
import Calc.Eval (evalProgram)
import Calc.Parser (parseProgram)
import Calc.Resolve (occurrences)
import Calc.Syntax (Problem (..), Span (..))
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = describe "analyze" $ do
  it "keeps the lines of the document" $
    anLines (analyze program) `shouldBe` ["let price = 1200", "price * 2", "let total = price + fee"]
  it "puts the problems of reading before the problems of names" $
    anProblems (analyze program)
      `shouldBe` [ Problem (Span 1 0 9) "expected: let <name> = <expr>"
                 , Problem (Span 2 20 23) "undefined variable 'fee'"
                 ]
  it "gives the same statements, occurrences and values as the functions it combines" $ do
    let analysis = analyze program
        statements = snd (parseProgram program)
    (anStatements analysis, anOccurrences analysis, anValues analysis)
      `shouldBe` (statements, occurrences statements, evalProgram statements)
    anProblems analysis `shouldBe` fst (parseProgram program) <> checkProgram statements
 where
  program :: Text
  program = "let price = 1200\nprice * 2\nlet total = price + fee\n"
