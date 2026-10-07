{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Conversions from Calc values to LSP types.
module Lsp.Convert (toRange, toDiagnostic) where

import Calc.Syntax (Problem (..), Span (..))
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
