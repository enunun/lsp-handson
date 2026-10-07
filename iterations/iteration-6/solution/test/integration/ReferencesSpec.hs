{-# LANGUAGE OverloadedStrings #-}

module ReferencesSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "textDocument/references" $ do
  it "lists the uses of a variable" $ do
    ranges <- referencesAt (Position 0 4) False
    ranges `shouldBe` [line 1 10 15, line 2 12 17]

  it "adds the definition when the editor asks for it" $ do
    ranges <- referencesAt (Position 0 4) True
    ranges `shouldBe` [line 0 4 9, line 1 10 15, line 2 12 17]
 where
  referencesAt position includeDeclaration = runCalcSession $ do
    document <- createDoc "sample.calc" "calc" program
    locations <- getReferences document position includeDeclaration
    pure (map (^. L.range) locations)
  program = "let price = 1200\nlet tax = price * 8 / 100\nlet total = price + tax\n"
  line l start end = Range (Position l start) (Position l end)
