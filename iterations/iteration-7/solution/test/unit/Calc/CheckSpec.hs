{-# LANGUAGE OverloadedStrings #-}

module Calc.CheckSpec (spec) where

import Calc.Check (checkProgram)
import Calc.Parser (parseProgram)
import Calc.Syntax (Problem (..), Span (..))
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = describe "checkProgram" $ do
  it "finds nothing when every variable is defined above" $
    check "let price = 1200\nlet tax = price * 8 / 100\nlet total = price + tax\n"
      `shouldBe` []
  it "reports a variable that is not defined" $
    check "let total = price + 1\n"
      `shouldBe` [Problem (Span 0 12 17) "undefined variable 'price'"]
  it "reports a variable that is defined only below" $
    check "let total = price\nlet price = 1200\n"
      `shouldBe` [Problem (Span 0 12 17) "undefined variable 'price'"]
  it "reports a variable used in its own definition" $
    check "let a = a + 1\n"
      `shouldBe` [Problem (Span 0 8 9) "undefined variable 'a'"]
  it "reports the second definition of a name" $
    check "let price = 1200\nlet price = 1000\n"
      `shouldBe` [Problem (Span 1 4 9) "'price' is already defined"]
  it "reports the problems in the order of the lines" $
    check "let a = b\nlet a = c\n"
      `shouldBe` [ Problem (Span 0 8 9) "undefined variable 'b'"
                 , Problem (Span 1 8 9) "undefined variable 'c'"
                 , Problem (Span 1 4 5) "'a' is already defined"
                 ]
 where
  check :: Text -> [Problem]
  check = checkProgram . snd . parseProgram
