{-# LANGUAGE OverloadedStrings #-}

module RenameSpec (spec) where

import Control.Lens ((^.))
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Message (
  SMethod (SMethod_TextDocumentPrepareRename, SMethod_TextDocumentRename),
 )
import Language.LSP.Protocol.Types
import Language.LSP.Test
import Test.Hspec
import TestServer (runCalcSession)

spec :: Spec
spec = do
  describe "textDocument/prepareRename" $ do
    it "gives the range of the variable under the cursor" $ do
      answer <- withProgram $ \document ->
        request SMethod_TextDocumentPrepareRename (PrepareRenameParams document (Position 1 18) Nothing)
      answer ^. L.result
        `shouldBe` Right (InL (PrepareRenameResult (InL (Range (Position 1 17) (Position 1 21)))))
    it "gives nothing outside a variable" $ do
      answer <- withProgram $ \document ->
        request SMethod_TextDocumentPrepareRename (PrepareRenameParams document (Position 1 12) Nothing)
      answer ^. L.result `shouldBe` Right (InR Null)

  describe "textDocument/rename" $ do
    it "renames the definition and every use" $ do
      contents <- withProgram $ \document -> do
        rename document (Position 0 4) "taxRate"
        documentContents document
      contents `shouldBe` "let taxRate = 8\nlet tax = 1200 * taxRate / 100\n"
    it "answers with an error when the new name is already defined" $ do
      answer <- withProgram $ \document ->
        request SMethod_TextDocumentRename (RenameParams Nothing document (Position 0 4) "tax")
      fmap (^. L.message) (either Just (const Nothing) (answer ^. L.result))
        `shouldBe` Just "'tax' is already defined"
 where
  withProgram action = runCalcSession $ do
    document <- createDoc "sample.calc" "calc" "let rate = 8\nlet tax = 1200 * rate / 100\n"
    action document
