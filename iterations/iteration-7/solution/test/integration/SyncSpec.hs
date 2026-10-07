{-# LANGUAGE OverloadedStrings #-}

module SyncSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "text document synchronization" $ do
  it "asks the editor for the changed parts only" $ do
    answer <- runCalcSession initializeResponse
    fmap (^. L.capabilities . L.textDocumentSync) (answer ^. L.result)
      `shouldBe` Right
        ( Just
            ( InL
                (TextDocumentSyncOptions (Just True) (Just TextDocumentSyncKind_Incremental) Nothing Nothing Nothing)
            )
        )

  it "applies a change to a part of the document before answering" $ do
    (diagnostics, hover) <- runCalcSession $ do
      document <- createDoc "sample.calc" "calc" "let a = 1\nlet b = a + c\n"
      _ <- waitForDiagnostics
      changeDoc document [partial (Range (Position 1 12) (Position 1 13)) "a"]
      diagnostics <- waitForDiagnostics
      hover <- getHover document (Position 1 4)
      pure (diagnostics, fmap (^. L.contents) hover)
    diagnostics `shouldBe` []
    hover `shouldBe` Just (InL (MarkupContent MarkupKind_PlainText "b = 2"))
 where
  partial range text = TextDocumentContentChangeEvent (InL (TextDocumentContentChangePartial range Nothing text))
