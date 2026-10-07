{-# LANGUAGE OverloadedStrings #-}

module Lsp.ConvertSpec (spec) where

import Calc.Eval (EvalError (..))
import Calc.Syntax (Problem (..), Span (..))
import Language.LSP.Protocol.Types
import Lsp.Convert (fromPosition, hoverText, toDiagnostic, toLocation, toRange)
import Test.Hspec

spec :: Spec
spec = do
  describe "toRange"
    $ it "keeps the line and the columns"
    $ toRange (Span 2 4 9) `shouldBe` Range (Position 2 4) (Position 2 9)

  describe "toDiagnostic"
    $ it "makes an error from calc with the message and the range"
    $ toDiagnostic (Problem (Span 1 0 9) "expected: let <name> = <expr>")
      `shouldBe` Diagnostic
        (Range (Position 1 0) (Position 1 9))
        (Just DiagnosticSeverity_Error)
        Nothing
        Nothing
        (Just "calc")
        "expected: let <name> = <expr>"
        Nothing
        Nothing
        Nothing

  describe "toLocation"
    $ it "puts the range of a span in a document"
    $ toLocation (Uri "file:///sample.calc") (Span 2 4 9)
      `shouldBe` Location (Uri "file:///sample.calc") (Range (Position 2 4) (Position 2 9))

  describe "fromPosition"
    $ it "gives the line and the column"
    $ fromPosition (Position 2 7) `shouldBe` (2, 7)

  describe "hoverText" $ do
    it "shows the value of a name" $
      hoverText "tax" (Right 96) `shouldBe` "tax = 96"
    it "shows a division by zero" $
      hoverText "bad" (Left DivisionByZero) `shouldBe` "bad: cannot evaluate (division by zero)"
    it "shows a variable that is not defined" $
      hoverText "total" (Left (UndefinedVariable "fee"))
        `shouldBe` "total: cannot evaluate (undefined variable 'fee')"
