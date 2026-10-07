{-# LANGUAGE OverloadedStrings #-}

module DefinitionSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/definition" $ do
  it "goes from a variable to its definition" $ do
    (document, definitions) <- definitionsAt (Position 2 13)
    definitions
      `shouldBe` InL (Definition (InL (Location (document ^. L.uri) (Range (Position 0 4) (Position 0 9)))))

  it "finds nothing for a variable that is not defined" $ do
    (_, definitions) <- definitionsAt (Position 2 27)
    definitions `shouldBe` InR (InR Null)
 where
  definitionsAt position = runCalcSession $ do
    document <- createDoc "sample.calc" "calc" program
    definitions <- getDefinitions document position
    pure (document, definitions)
  program = "let price = 1200\nlet tax = price * 8 / 100\nlet total = price + tax + fee\n"
