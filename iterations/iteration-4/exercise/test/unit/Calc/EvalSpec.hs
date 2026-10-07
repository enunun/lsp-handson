{-# LANGUAGE OverloadedStrings #-}

module Calc.EvalSpec (spec) where

import Calc.Eval (EvalError (..), evalProgram)
import Calc.Parser (parseProgram)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = describe "evalProgram" $ do
  it "gives nothing for an empty program" $
    eval "" `shouldBe` Map.empty
  it "gives the value of a number" $
    eval "let price = 1200\n" `shouldBe` Map.fromList [("price", Right 1200)]
  it "uses the values of the variables defined above" $
    Map.lookup "total" (eval "let price = 1200\nlet total = price + 96\n") `shouldBe` Just (Right 1296)
  it "subtracts and multiplies" $
    Map.lookup "a" (eval "let a = 10 - 2 * 3\n") `shouldBe` Just (Right 4)
  it "divides integers, dropping the fraction" $
    Map.lookup "a" (eval "let a = 7 / 2\n") `shouldBe` Just (Right 3)
  it "rounds a negative quotient down" $
    Map.lookup "a" (eval "let a = (0 - 7) / 2\n") `shouldBe` Just (Right (-4))
  it "reports a division by zero" $
    Map.lookup "a" (eval "let a = 1 / (2 - 2)\n") `shouldBe` Just (Left DivisionByZero)
  it "reports a variable that is not defined above" $
    Map.lookup "a" (eval "let a = b + 1\n") `shouldBe` Just (Left (UndefinedVariable "b"))
  it "passes on the error of a variable used in the expression" $
    Map.lookup "c" (eval "let a = 1 / 0\nlet c = a + 1\n") `shouldBe` Just (Left DivisionByZero)
  it "keeps the value of the first definition of a name" $
    Map.lookup "a" (eval "let a = 1\nlet a = 2\n") `shouldBe` Just (Right 1)
 where
  eval :: Text -> Map Text (Either EvalError Integer)
  eval = evalProgram . snd . parseProgram
