{-# LANGUAGE OverloadedStrings #-}

module LogMessageSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Message (SMethod (SMethod_WindowLogMessage))
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = describe "window/logMessage" $ do
  it "reports the number of lines when a document is opened" $ do
    logged <- runCalcSession $ do
      _ <- createDoc "sample.calc" "calc" "let a = 1\nlet b = 2\n"
      message SMethod_WindowLogMessage
    logged ^. L.params . L.message `shouldBe` "sample.calc: 2 lines"

  it "reports the number of lines again when the document changes" $ do
    logged <- runCalcSession $ do
      document <- createDoc "sample.calc" "calc" "let a = 1\n"
      _ <- message SMethod_WindowLogMessage
      changeDoc document [wholeDocument "let a = 1\nlet b = 2\nlet c = 3\n"]
      message SMethod_WindowLogMessage
    logged ^. L.params . L.message `shouldBe` "sample.calc: 3 lines"
 where
  wholeDocument text = TextDocumentContentChangeEvent (InR (TextDocumentContentChangeWholeDocument text))
