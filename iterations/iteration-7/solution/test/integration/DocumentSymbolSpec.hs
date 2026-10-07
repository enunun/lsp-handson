{-# LANGUAGE OverloadedStrings #-}

module DocumentSymbolSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/documentSymbol" $
  it "lists the definitions from top to bottom with their values" $ do
    found <- runCalcSession $ do
      document <-
        createDoc "sample.calc" "calc" "let price = 1200\nlet tax = price * 8 / 100\nlet bad = 1 / 0\n"
      getDocumentSymbols document
    fmap (map (\symbol -> (symbol ^. L.name, symbol ^. L.detail))) found
      `shouldBe` Right
        [ ("price", Just "1200")
        , ("tax", Just "96")
        , ("bad", Just "cannot evaluate (division by zero)")
        ]
