{-# LANGUAGE OverloadedStrings #-}

module Calc.ParserSpec (spec) where

import Calc.Parser (parseLine, parseProgram)
import Calc.Syntax (Problem (..), Span (..), Statement (..))
import Test.Hspec

spec :: Spec
spec = do
  describe "parseLine" $ do
    it "reads a let statement and the position of its name" $
      parseLine 0 "let price = 1200" `shouldBe` Just (Right (Statement "price" (Span 0 4 9)))
    it "uses the line number for the position" $
      parseLine 3 "let tax = price * 8" `shouldBe` Just (Right (Statement "tax" (Span 3 4 7)))
    it "counts the indentation and the spaces after let in the position" $
      parseLine 0 "  let   a = 1" `shouldBe` Just (Right (Statement "a" (Span 0 8 9)))
    it "reports a line that does not start with let" $
      parseLine 1 "price * 2" `shouldBe` Just (Left (expected (Span 1 0 9)))
    it "reports a name that starts with a digit" $
      parseLine 0 "let 1x = 3" `shouldBe` Just (Left (expected (Span 0 0 10)))
    it "reports a line without =" $
      parseLine 0 "let a 1" `shouldBe` Just (Left (expected (Span 0 0 7)))
    it "reports a line without an expression after =" $
      parseLine 0 "let a =" `shouldBe` Just (Left (expected (Span 0 0 7)))
    it "skips a blank line" $
      parseLine 0 "   " `shouldBe` Nothing
    it "skips a comment line" $
      parseLine 0 "  -- total price" `shouldBe` Nothing

  describe "parseProgram" $ do
    it "reads nothing from an empty program" $
      parseProgram "" `shouldBe` ([], [])
    it "collects the problems and the statements in order" $
      parseProgram "let price = 1200\nprice * 2\n\n-- note\nlet tax = 96\nlet 1x = 3\n"
        `shouldBe` ( [expected (Span 1 0 9), expected (Span 5 0 10)]
                   , [Statement "price" (Span 0 4 9), Statement "tax" (Span 4 4 7)]
                   )
 where
  expected s = Problem s "expected: let <name> = <expr>"
