{-# LANGUAGE OverloadedStrings #-}

module Calc.CompleteSpec (spec) where

import Calc.Complete (Candidate (..), candidates)
import Calc.Eval (EvalError (..))
import Calc.Parser (parseProgram)
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

spec :: Spec
spec = describe "candidates" $ do
  it "offers let at the start of an empty line" $
    complete ["let price = 1200", ""] `shouldBe` [Keyword "let"]
  it "offers let while it is being typed" $
    complete ["let price = 1200", "  le"] `shouldBe` [Keyword "let"]
  it "offers nothing for another word at the start of a line" $
    complete ["let price = 1200", "x"] `shouldBe` []
  it "offers the variables defined above after =" $
    complete ["let price = 1200", "let pages = 30", "let total = "]
      `shouldBe` [Variable "price" (Right 1200), Variable "pages" (Right 30)]
  it "keeps only the variables that start with the word being typed" $
    complete ["let price = 1200", "let tax = 96", "let total = 2 * p"]
      `shouldBe` [Variable "price" (Right 1200)]
  it "offers nothing while the name of a definition is typed" $
    complete ["let price = 1200", "let p"] `shouldBe` []
  it "leaves out the variables defined on the line and below" $
    completeOn 1 ["let price = 1200", "let total = p", "let pages = 30"]
      `shouldBe` [Variable "price" (Right 1200)]
  it "offers variables on a line that cannot be read yet" $
    complete ["let price = 1200", "let total = (price + p"]
      `shouldBe` [Variable "price" (Right 1200)]
  it "offers a name defined twice once, with its first value" $
    complete ["let a = 1", "let a = 2", "let b = "] `shouldBe` [Variable "a" (Right 1)]
  it "offers a variable whose value cannot be computed" $
    complete ["let bad = 1 / 0", "let b = "] `shouldBe` [Variable "bad" (Left DivisionByZero)]
 where
  -- Completes at the end of the last line.
  complete :: [Text] -> [Candidate]
  complete ls = completeOn (length ls - 1) ls
  -- Completes at the end of a line.
  completeOn :: Int -> [Text] -> [Candidate]
  completeOn line ls =
    let current = ls !! line
     in candidates line (T.length current) current (snd (parseProgram (T.unlines ls)))
