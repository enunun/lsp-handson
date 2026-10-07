{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Conversions from Calc values to LSP types.
module Lsp.Convert (
  toRange,
  toDiagnostic,
  toLocation,
  fromPosition,
  hoverText,
  toCompletionItem,
  toWorkspaceEdit,
  renameErrorMessage,
) where

import Calc.Complete (Candidate (..))
import Calc.Eval (EvalError (..))
import Calc.Rename (RenameError (..))
import Calc.Syntax (Problem (..), Span (..))
import Control.Lens ((&), (?~))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Types

toRange :: Span -> Range
toRange (Span line start end) =
  Range
    (Position (fromIntegral line) (fromIntegral start))
    (Position (fromIntegral line) (fromIntegral end))

toDiagnostic :: Problem -> Diagnostic
toDiagnostic (Problem location message) =
  Diagnostic
    { _range = toRange location
    , _severity = Just DiagnosticSeverity_Error
    , _code = Nothing
    , _codeDescription = Nothing
    , _source = Just "calc"
    , _message = message
    , _tags = Nothing
    , _relatedInformation = Nothing
    , _data_ = Nothing
    }

-- | A span in a document.
toLocation :: Uri -> Span -> Location
toLocation uri location = Location uri (toRange location)

-- | The line and the column of a position.
fromPosition :: Position -> (Int, Int)
fromPosition (Position line character) = (fromIntegral line, fromIntegral character)

-- | The text shown when hovering over a name.
hoverText :: Text -> Either EvalError Integer -> Text
hoverText name (Right value) = name <> " = " <> T.pack (show value)
hoverText name (Left err) = name <> ": cannot evaluate (" <> reason err <> ")"
 where
  reason DivisionByZero = "division by zero"
  reason (UndefinedVariable var) = "undefined variable '" <> var <> "'"

-- | A completion item. A variable shows its value, as in a hover.
toCompletionItem :: Candidate -> CompletionItem
toCompletionItem (Keyword word) = plainItem word & L.kind ?~ CompletionItemKind_Keyword
toCompletionItem (Variable name value) =
  plainItem name & L.kind ?~ CompletionItemKind_Variable & L.detail ?~ hoverText name value

-- | A completion item with only a label.
plainItem :: Text -> CompletionItem
plainItem label =
  CompletionItem
    { _label = label
    , _labelDetails = Nothing
    , _kind = Nothing
    , _tags = Nothing
    , _detail = Nothing
    , _documentation = Nothing
    , _deprecated = Nothing
    , _preselect = Nothing
    , _sortText = Nothing
    , _filterText = Nothing
    , _insertText = Nothing
    , _insertTextFormat = Nothing
    , _insertTextMode = Nothing
    , _textEdit = Nothing
    , _textEditText = Nothing
    , _additionalTextEdits = Nothing
    , _commitCharacters = Nothing
    , _command = Nothing
    , _data_ = Nothing
    }

-- | Edits to one document.
toWorkspaceEdit :: Uri -> [(Span, Text)] -> WorkspaceEdit
toWorkspaceEdit uri edits =
  WorkspaceEdit
    { _changes = Just (Map.singleton uri [TextEdit (toRange location) new | (location, new) <- edits])
    , _documentChanges = Nothing
    , _changeAnnotations = Nothing
    }

-- | The message of an error response to a rename.
renameErrorMessage :: RenameError -> Text
renameErrorMessage (InvalidName name) = "'" <> name <> "' is not a valid name"
renameErrorMessage (AlreadyDefined name) = "'" <> name <> "' is already defined"
