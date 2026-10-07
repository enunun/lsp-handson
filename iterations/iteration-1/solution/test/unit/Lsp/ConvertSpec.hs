{-# LANGUAGE OverloadedStrings #-}

module Lsp.ConvertSpec (spec) where

import Calc.Syntax (Problem (..), Span (..))
import Language.LSP.Protocol.Types
import Lsp.Convert (toDiagnostic, toRange)
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
