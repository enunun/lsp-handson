{-# LANGUAGE OverloadedStrings #-}

module Calc.ParserSpec (spec) where

import Calc.Parser (parseLine, parseProgram)
import Calc.Syntax (Expr (..), Op (..), Problem (..), Span (..), Statement (..))
import Test.Hspec

spec :: Spec
spec = do
  describe "parseLine" $ do
    it "reads a let statement and the position of its name" $
      parseLine 0 "let price = 1200"
        `shouldBe` Just (Right (Statement "price" (Span 0 4 9) (Number 1200)))
    it "uses the line number for the position" $
      parseLine 3 "let tax = price * 8"
        `shouldBe` Just
          (Right (Statement "tax" (Span 3 4 7) (BinOp Mul (Var "price" (Span 3 10 15)) (Number 8))))
    it "counts the indentation and the spaces after let in the position" $
      parseLine 0 "  let   a = 1"
        `shouldBe` Just (Right (Statement "a" (Span 0 8 9) (Number 1)))
    it "reports a line that does not start with let" $
      parseLine 1 "price * 2" `shouldBe` Just (Left (expected (Span 1 0 9)))
    it "reports a name that starts with a digit" $
      parseLine 0 "let 1x = 3" `shouldBe` Just (Left (expected (Span 0 0 10)))
    it "reports a line without =" $
      parseLine 0 "let a 1" `shouldBe` Just (Left (expected (Span 0 0 7)))
    it "reports a line without an expression after = at the end of the line" $
      parseLine 0 "let a ="
        `shouldBe` Just
          (Left (Problem (Span 0 7 7) "unexpected end of input\nexpecting '(', integer, or name"))
    it "skips a blank line" $
      parseLine 0 "   " `shouldBe` Nothing
    it "skips a comment line" $
      parseLine 0 "  -- total price" `shouldBe` Nothing

  describe "parseLine (expressions)" $ do
    it "reads a variable and the position where it is used" $
      parseLine 0 "let total = price"
        `shouldBe` Just (Right (Statement "total" (Span 0 4 9) (Var "price" (Span 0 12 17))))
    it "reads an addition" $
      exprOf "let a = 1 + 2" `shouldBe` Just (BinOp Add (Number 1) (Number 2))
    it "groups operators of the same strength to the left" $
      exprOf "let a = 1 - 2 - 3"
        `shouldBe` Just (BinOp Sub (BinOp Sub (Number 1) (Number 2)) (Number 3))
    it "binds * more tightly than +" $
      exprOf "let a = 1 + 2 * 3"
        `shouldBe` Just (BinOp Add (Number 1) (BinOp Mul (Number 2) (Number 3)))
    it "binds / as tightly as * and groups them to the left" $
      exprOf "let a = 8 / 2 * 3"
        `shouldBe` Just (BinOp Mul (BinOp Div (Number 8) (Number 2)) (Number 3))
    it "reads parentheses first" $
      exprOf "let a = (1 + 2) * 3"
        `shouldBe` Just (BinOp Mul (BinOp Add (Number 1) (Number 2)) (Number 3))
    it "reads a statement without spaces" $
      exprOf "let a=1+2" `shouldBe` Just (BinOp Add (Number 1) (Number 2))
    it "allows a comment at the end of the line" $
      exprOf "let a = 1 -- one" `shouldBe` Just (Number 1)
    it "reports where the expression stops, up to the end of the line" $
      parseLine 0 "let a = 12abc"
        `shouldBe` Just
          ( Left
              ( Problem
                  (Span 0 10 13)
                  "unexpected 'a'\nexpecting '*', '+', '-', '/', digit, or end of input"
              )
          )
    it "reports an unclosed parenthesis at the end of the line" $
      parseLine 0 "let broken = (1 + 2"
        `shouldBe` Just
          ( Left
              ( Problem
                  (Span 0 19 19)
                  "unexpected end of input\nexpecting ')', '*', '+', '-', '/', or digit"
              )
          )

  describe "parseProgram" $ do
    it "reads nothing from an empty program" $
      parseProgram "" `shouldBe` ([], [])
    it "collects the problems and the statements in order" $
      parseProgram "let price = 1200\nprice * 2\n\n-- note\nlet tax = 96\nlet 1x = 3\n"
        `shouldBe` ( [expected (Span 1 0 9), expected (Span 5 0 10)]
                   ,
                     [ Statement "price" (Span 0 4 9) (Number 1200)
                     , Statement "tax" (Span 4 4 7) (Number 96)
                     ]
                   )
 where
  expected s = Problem s "expected: let <name> = <expr>"
  exprOf line = case parseLine 0 line of
    Just (Right statement) -> Just (stmtExpr statement)
    _ -> Nothing
