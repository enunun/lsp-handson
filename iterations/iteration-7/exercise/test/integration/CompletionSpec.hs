{-# LANGUAGE OverloadedStrings #-}

module CompletionSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/completion" $ do
  it "offers the variables defined above, with their values" $ do
    items <- completionsAt (Position 2 13)
    map (\item -> (item ^. L.label, item ^. L.detail)) items
      `shouldBe` [("price", Just "price = 1200"), ("pages", Just "pages = 30")]

  it "offers let at the start of a line" $ do
    items <- completionsAt (Position 3 0)
    map (^. L.label) items `shouldBe` ["let"]
 where
  completionsAt position = runCalcSession $ do
    document <- createDoc "sample.calc" "calc" "let price = 1200\nlet pages = 30\nlet total = p\n\n"
    getCompletions document position
