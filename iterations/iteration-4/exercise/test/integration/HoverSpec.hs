{-# LANGUAGE OverloadedStrings #-}

module HoverSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/hover" $ do
  it "shows the value of the variable under the cursor" $ do
    hover <- hoverOn (Position 1 4)
    fmap (^. L.contents) hover `shouldBe` Just (InL (MarkupContent MarkupKind_PlainText "tax = 96"))

  it "shows why a value cannot be computed" $ do
    hover <- hoverOn (Position 2 5)
    fmap (^. L.contents) hover
      `shouldBe` Just (InL (MarkupContent MarkupKind_PlainText "bad: cannot evaluate (division by zero)"))

  it "shows nothing outside a variable" $ do
    hover <- hoverOn (Position 0 0)
    hover `shouldBe` Nothing
 where
  hoverOn position = runCalcSession $ do
    document <- createDoc "sample.calc" "calc" program
    getHover document position
  program =
    "let price = 1200\nlet tax = price * 8 / 100\nlet bad = price / (tax - 96)\n"
