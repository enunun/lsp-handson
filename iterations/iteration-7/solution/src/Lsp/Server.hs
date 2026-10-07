{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The Calc language server: its capabilities and the handlers for LSP messages.
module Lsp.Server (run, serverDefinition, handlers) where

import Calc.Analysis (Analysis (..))
import Calc.Complete (Candidate, candidates)
import Calc.Query (definitionOf, occurrenceAt, referencesOf)
import Calc.Rename (renameEdits)
import Calc.Resolve (Occurrence (..))
import Calc.Summary (countLines)
import Calc.Syntax (Statement (..))
import Control.Lens ((^.))
import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Language.LSP.Protocol.Lens qualified as L
import Language.LSP.Protocol.Message
import Language.LSP.Protocol.Types
import Language.LSP.Server
import Language.LSP.VFS (virtualFileText, virtualFileVersion)
import Lsp.Convert (
  fromPosition,
  hoverText,
  renameErrorMessage,
  toCompletionItem,
  toDiagnostic,
  toDocumentSymbol,
  toLocation,
  toRange,
  toWorkspaceEdit,
 )
import Lsp.State (Cache, lookupAnalysis, newCache, updateAnalysis)

-- | Runs the server over standard input and output.
run :: IO ()
run = do
  cache <- newCache
  void (runServer (serverDefinition cache))

serverDefinition :: Cache -> ServerDefinition ()
serverDefinition cache =
  ServerDefinition
    { defaultConfig = ()
    , configSection = "calc"
    , parseConfig = \_ _ -> Right ()
    , onConfigChange = const (pure ())
    , doInitialize = \env _request -> pure (Right env)
    , staticHandlers = const (handlers cache)
    , interpretHandler = \env -> Iso (runLspT env) liftIO
    , options =
        defaultOptions
          { optTextDocumentSync = Just syncOptions
          , optServerInfo = Just (ServerInfo "calc-lsp" Nothing)
          }
    }

-- | The editor sends open and close notifications, and only the changed parts of a document.
syncOptions :: TextDocumentSyncOptions
syncOptions =
  TextDocumentSyncOptions
    { _openClose = Just True
    , _change = Just TextDocumentSyncKind_Incremental
    , _willSave = Nothing
    , _willSaveWaitUntil = Nothing
    , _save = Nothing
    }

handlers :: Cache -> Handlers (LspM ())
handlers cache =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_notification -> pure ()
    , notificationHandler SMethod_TextDocumentDidOpen $ \notification ->
        checkDocument cache (notification ^. L.params . L.textDocument . L.uri)
    , notificationHandler SMethod_TextDocumentDidChange $ \notification ->
        checkDocument cache (notification ^. L.params . L.textDocument . L.uri)
    , requestHandler SMethod_TextDocumentHover $ \request respond -> do
        let params = request ^. L.params
        analysis <- analysisOf cache (params ^. L.textDocument . L.uri)
        respond (Right (maybe (InR Null) InL (hoverAt (fromPosition (params ^. L.position)) =<< analysis)))
    , requestHandler SMethod_TextDocumentDefinition $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
        analysis <- analysisOf cache uri
        let found = definitionAt (fromPosition (params ^. L.position)) =<< analysis
        respond (Right (maybe (InR (InR Null)) (InL . Definition . InL . toLocation uri . occSpan) found))
    , requestHandler SMethod_TextDocumentReferences $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            includeDefinitions = params ^. L.context . L.includeDeclaration
        analysis <- analysisOf cache uri
        let found = maybe [] (referencesAt includeDefinitions (fromPosition (params ^. L.position))) analysis
        respond (Right (InL (map (toLocation uri . occSpan) found)))
    , requestHandler SMethod_TextDocumentCompletion $ \request respond -> do
        let params = request ^. L.params
        analysis <- analysisOf cache (params ^. L.textDocument . L.uri)
        let found = maybe [] (completionsAt (fromPosition (params ^. L.position))) analysis
        respond (Right (InL (map toCompletionItem found)))
    , requestHandler SMethod_TextDocumentPrepareRename $ \request respond -> do
        let params = request ^. L.params
            (line, column) = fromPosition (params ^. L.position)
        analysis <- analysisOf cache (params ^. L.textDocument . L.uri)
        let found = occurrenceAt line column . anOccurrences =<< analysis
        respond (Right (maybe (InR Null) (InL . PrepareRenameResult . InL . toRange . occSpan) found))
    , requestHandler SMethod_TextDocumentRename $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            (line, column) = fromPosition (params ^. L.position)
        analysis <- analysisOf cache uri
        let occs = maybe [] anOccurrences analysis
        respond $ case occurrenceAt line column occs of
          Nothing -> Right (InR Null)
          Just occurrence -> case renameEdits (occName occurrence) (params ^. L.newName) occs of
            Left err -> Left (TResponseError (InR ErrorCodes_InvalidParams) (renameErrorMessage err) Nothing)
            Right edits -> Right (InL (toWorkspaceEdit uri edits))
    , requestHandler SMethod_TextDocumentDocumentSymbol $ \request respond -> do
        analysis <- analysisOf cache (request ^. L.params . L.textDocument . L.uri)
        respond (Right (InR (InL (maybe [] symbols analysis))))
    ]

-- | Analyzes the latest text of a document, then logs its size and sends its diagnostics.
checkDocument :: Cache -> Uri -> LspM () ()
checkDocument cache uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents -> do
      let text = virtualFileText contents
      analysis <- liftIO (updateAnalysis cache (toNormalizedUri uri) text)
      sendNotification SMethod_WindowLogMessage $
        LogMessageParams MessageType_Info (summary uri text)
      sendNotification SMethod_TextDocumentPublishDiagnostics $
        PublishDiagnosticsParams
          uri
          (Just (virtualFileVersion contents))
          (map toDiagnostic (anProblems analysis))

-- | The latest analysis of a document.
analysisOf :: Cache -> Uri -> LspM () (Maybe Analysis)
analysisOf cache uri = liftIO (lookupAnalysis cache (toNormalizedUri uri))

-- | The value of the name at a position.
hoverAt :: (Int, Int) -> Analysis -> Maybe Hover
hoverAt (line, column) analysis = do
  occurrence <- occurrenceAt line column (anOccurrences analysis)
  let name = occName occurrence
  value <- Map.lookup name (anValues analysis)
  pure (Hover (InL (MarkupContent MarkupKind_PlainText (hoverText name value))) Nothing)

-- | The definition of the name at a position.
definitionAt :: (Int, Int) -> Analysis -> Maybe Occurrence
definitionAt (line, column) analysis = do
  let occs = anOccurrences analysis
  occurrence <- occurrenceAt line column occs
  definitionOf (occName occurrence) occs

-- | The references to the name at a position.
referencesAt :: Bool -> (Int, Int) -> Analysis -> [Occurrence]
referencesAt includeDefinitions (line, column) analysis =
  let occs = anOccurrences analysis
   in maybe
        []
        (\occurrence -> referencesOf includeDefinitions (occName occurrence) occs)
        (occurrenceAt line column occs)

-- | The completion candidates at a position, using the text of its line.
completionsAt :: (Int, Int) -> Analysis -> [Candidate]
completionsAt (line, column) analysis =
  let lineText = case drop line (anLines analysis) of
        current : _ -> current
        [] -> ""
   in candidates line column lineText (anStatements analysis)

-- | The outline: every definition with its value.
symbols :: Analysis -> [DocumentSymbol]
symbols analysis =
  [ toDocumentSymbol statement value
  | statement <- anStatements analysis
  , Just value <- [Map.lookup (stmtName statement) (anValues analysis)]
  ]

summary :: Uri -> Text -> Text
summary uri text =
  fileName uri <> ": " <> T.pack (show (countLines text)) <> " lines"

fileName :: Uri -> Text
fileName uri = T.takeWhileEnd (/= '/') (getUri uri)
