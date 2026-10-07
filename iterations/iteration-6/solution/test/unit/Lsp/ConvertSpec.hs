{-# LANGUAGE OverloadedStrings #-}

module Lsp.ConvertSpec (spec) where

import Calc.Complete (Candidate (..))
import Calc.Eval (EvalError (..))
import Calc.Rename (RenameError (..))
import Calc.Syntax (Problem (..), Span (..))
import Control.Lens ((^.))
import Data.Map.Strict qualified as Map
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types
import Lsp.Convert (
  fromPosition,
  hoverText,
  renameErrorMessage,
  toCompletionItem,
  toDiagnostic,
  toLocation,
  toRange,
  toWorkspaceEdit,
 )
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

  describe "toLocation"
    $ it "puts the range of a span in a document"
    $ toLocation (Uri "file:///sample.calc") (Span 2 4 9)
      `shouldBe` Location (Uri "file:///sample.calc") (Range (Position 2 4) (Position 2 9))

  describe "fromPosition"
    $ it "gives the line and the column"
    $ fromPosition (Position 2 7) `shouldBe` (2, 7)

  describe "hoverText" $ do
    it "shows the value of a name" $
      hoverText "tax" (Right 96) `shouldBe` "tax = 96"
    it "shows a division by zero" $
      hoverText "bad" (Left DivisionByZero) `shouldBe` "bad: cannot evaluate (division by zero)"
    it "shows a variable that is not defined" $
      hoverText "total" (Left (UndefinedVariable "fee"))
        `shouldBe` "total: cannot evaluate (undefined variable 'fee')"

  describe "toCompletionItem" $ do
    it "makes a keyword item" $ do
      let item = toCompletionItem (Keyword "let")
      (item ^. L.label, item ^. L.kind) `shouldBe` ("let", Just CompletionItemKind_Keyword)
    it "makes a variable item that shows the value" $ do
      let item = toCompletionItem (Variable "price" (Right 1200))
      (item ^. L.label, item ^. L.kind, item ^. L.detail)
        `shouldBe` ("price", Just CompletionItemKind_Variable, Just "price = 1200")

  describe "toWorkspaceEdit"
    $ it "puts the edits under the document"
    $ toWorkspaceEdit (Uri "file:///sample.calc") [(Span 0 4 8, "taxRate")]
      `shouldBe` WorkspaceEdit
        ( Just
            (Map.singleton (Uri "file:///sample.calc") [TextEdit (Range (Position 0 4) (Position 0 8)) "taxRate"])
        )
        Nothing
        Nothing

  describe "renameErrorMessage"
    $ it "explains why a rename is rejected"
    $ map renameErrorMessage [InvalidName "1x", AlreadyDefined "tax"]
      `shouldBe` ["'1x' is not a valid name", "'tax' is already defined"]
