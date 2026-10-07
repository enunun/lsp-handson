{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Conversions from Calc values to LSP types.
module Lsp.Convert (toRange, toDiagnostic, fromPosition, hoverText) where

import Calc.Eval (EvalError (..))
import Calc.Syntax (Problem (..), Span (..))
import Data.Text (Text)
import Data.Text qualified as T
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
