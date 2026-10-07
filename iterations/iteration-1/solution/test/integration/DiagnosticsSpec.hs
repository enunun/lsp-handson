{-# LANGUAGE OverloadedStrings #-}

module DiagnosticsSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/publishDiagnostics" $ do
  it "reports a line that is not a let statement when a document is opened" $ do
    diagnostics <- runCalcSession $ do
      _ <- createDoc "sample.calc" "calc" "let price = 1200\nprice * 2\n"
      waitForDiagnostics
    map (\d -> (d ^. L.range, d ^. L.message)) diagnostics
      `shouldBe` [(Range (Position 1 0) (Position 1 9), "expected: let <name> = <expr>")]

  it "clears the diagnostics when the document is fixed" $ do
    diagnostics <- runCalcSession $ do
      document <- createDoc "sample.calc" "calc" "price * 2\n"
      _ <- waitForDiagnostics
      changeDoc document [wholeDocument "let price = 1200\n"]
      waitForDiagnostics
    diagnostics `shouldBe` []
 where
  wholeDocument text = TextDocumentContentChangeEvent (InR (TextDocumentContentChangeWholeDocument text))
