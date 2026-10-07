{-# LANGUAGE OverloadedStrings #-}

module Calc.QuerySpec (spec) where

import Calc.Parser (parseProgram)
import Calc.Query (nameAt)
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = describe "nameAt" $ do
  it "finds the name of a definition" $
    at 0 4 `shouldBe` Just "price"
  it "finds a variable in an expression" $
    at 1 10 `shouldBe` Just "price"
  it "finds a name from its last character" $
    at 0 8 `shouldBe` Just "price"
  it "finds nothing just after a name" $
    at 0 9 `shouldBe` Nothing
  it "finds nothing on a number or an operator" $
    (at 1 16, at 1 18) `shouldBe` (Nothing, Nothing)
  it "finds nothing on a line without statements" $
    at 2 0 `shouldBe` Nothing
 where
  -- "let price = 1200" and "let tax = price * 8 / 100"
  program :: Text
  program = "let price = 1200\nlet tax = price * 8 / 100\n"
  at line column = nameAt line column (snd (parseProgram program))
