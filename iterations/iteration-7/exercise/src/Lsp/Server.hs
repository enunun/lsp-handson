{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The Calc language server: its capabilities and the handlers for LSP messages.
module Lsp.Server (run, serverDefinition, handlers) where

import Calc.Check (checkProgram)
import Calc.Complete (candidates)
import Calc.Eval (evalProgram)
import Calc.Parser (parseProgram)
import Calc.Query (definitionOf, occurrenceAt, referencesOf)
import Calc.Rename (renameEdits)
import Calc.Resolve (Occurrence (..), occurrences)
import Calc.Summary (countLines)
import Calc.Syntax (Statement)
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
  toLocation,
  toRange,
  toWorkspaceEdit,
 )

-- | Runs the server over standard input and output.
run :: IO ()
run = void (runServer serverDefinition)

serverDefinition :: ServerDefinition ()
serverDefinition =
  ServerDefinition
    { defaultConfig = ()
    , configSection = "calc"
    , parseConfig = \_ _ -> Right ()
    , onConfigChange = const (pure ())
    , doInitialize = \env _request -> pure (Right env)
    , staticHandlers = const handlers
    , interpretHandler = \env -> Iso (runLspT env) liftIO
    , options =
        defaultOptions
          { optTextDocumentSync = Just syncOptions
          , optServerInfo = Just (ServerInfo "calc-lsp" Nothing)
          }
    }

-- | The editor sends open and close notifications and the whole text on every change.
syncOptions :: TextDocumentSyncOptions
syncOptions =
  TextDocumentSyncOptions
    { _openClose = Just True
    , _change = Just TextDocumentSyncKind_Full
    , _willSave = Nothing
    , _willSaveWaitUntil = Nothing
    , _save = Nothing
    }

handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_notification -> pure ()
    , notificationHandler SMethod_TextDocumentDidOpen $ \notification ->
        checkDocument (notification ^. L.params . L.textDocument . L.uri)
    , notificationHandler SMethod_TextDocumentDidChange $ \notification ->
        checkDocument (notification ^. L.params . L.textDocument . L.uri)
    , requestHandler SMethod_TextDocumentHover $ \request respond -> do
        let params = request ^. L.params
        statements <- statementsOf (params ^. L.textDocument . L.uri)
        respond (Right (maybe (InR Null) InL (hoverAt (fromPosition (params ^. L.position)) statements)))
    , requestHandler SMethod_TextDocumentDefinition $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
        statements <- statementsOf uri
        let found = definitionAt (fromPosition (params ^. L.position)) statements
        respond (Right (maybe (InR (InR Null)) (InL . Definition . InL . toLocation uri . occSpan) found))
    , requestHandler SMethod_TextDocumentReferences $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            includeDefinitions = params ^. L.context . L.includeDeclaration
        statements <- statementsOf uri
        let found = referencesAt includeDefinitions (fromPosition (params ^. L.position)) statements
        respond (Right (InL (map (toLocation uri . occSpan) found)))
    , requestHandler SMethod_TextDocumentCompletion $ \request respond -> do
        let params = request ^. L.params
            (line, column) = fromPosition (params ^. L.position)
        file <- getVirtualFile (toNormalizedUri (params ^. L.textDocument . L.uri))
        let text = maybe "" virtualFileText file
            lineText = case drop line (T.lines text) of
              current : _ -> current
              [] -> ""
            (_problems, statements) = parseProgram text
        respond (Right (InL (map toCompletionItem (candidates line column lineText statements))))
    , requestHandler SMethod_TextDocumentPrepareRename $ \request respond -> do
        let params = request ^. L.params
            (line, column) = fromPosition (params ^. L.position)
        statements <- statementsOf (params ^. L.textDocument . L.uri)
        let found = occurrenceAt line column (occurrences statements)
        respond (Right (maybe (InR Null) (InL . PrepareRenameResult . InL . toRange . occSpan) found))
    , requestHandler SMethod_TextDocumentRename $ \request respond -> do
        let params = request ^. L.params
            uri = params ^. L.textDocument . L.uri
            (line, column) = fromPosition (params ^. L.position)
        statements <- statementsOf uri
        let occs = occurrences statements
        respond $ case occurrenceAt line column occs of
          Nothing -> Right (InR Null)
          Just occurrence -> case renameEdits (occName occurrence) (params ^. L.newName) occs of
            Left err -> Left (TResponseError (InR ErrorCodes_InvalidParams) (renameErrorMessage err) Nothing)
            Right edits -> Right (InL (toWorkspaceEdit uri edits))
    ]

-- | The statements of an open document. A document that is not open has none.
statementsOf :: Uri -> LspM () [Statement]
statementsOf uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  pure (maybe [] (snd . parseProgram . virtualFileText) file)

-- | The value of the name at a position.
hoverAt :: (Int, Int) -> [Statement] -> Maybe Hover
hoverAt (line, column) statements = do
  occurrence <- occurrenceAt line column (occurrences statements)
  let name = occName occurrence
  value <- Map.lookup name (evalProgram statements)
  pure (Hover (InL (MarkupContent MarkupKind_PlainText (hoverText name value))) Nothing)

-- | The definition of the name at a position.
definitionAt :: (Int, Int) -> [Statement] -> Maybe Occurrence
definitionAt (line, column) statements = do
  let occs = occurrences statements
  occurrence <- occurrenceAt line column occs
  definitionOf (occName occurrence) occs

-- | The references to the name at a position.
referencesAt :: Bool -> (Int, Int) -> [Statement] -> [Occurrence]
referencesAt includeDefinitions (line, column) statements =
  let occs = occurrences statements
   in maybe
        []
        (\occurrence -> referencesOf includeDefinitions (occName occurrence) occs)
        (occurrenceAt line column occs)

-- | Logs the size of the document and sends its diagnostics.
checkDocument :: Uri -> LspM () ()
checkDocument uri = do
  logSummary uri
  publishProblems uri

-- | Writes "<file name>: <n> lines" to the editor's log.
logSummary :: Uri -> LspM () ()
logSummary uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents ->
      sendNotification SMethod_WindowLogMessage $
        LogMessageParams MessageType_Info (summary uri (virtualFileText contents))

-- | Sends a diagnostic for every problem in the document. An empty list clears earlier ones.
publishProblems :: Uri -> LspM () ()
publishProblems uri = do
  file <- getVirtualFile (toNormalizedUri uri)
  case file of
    Nothing -> pure ()
    Just contents -> do
      let (problems, statements) = parseProgram (virtualFileText contents)
          diagnostics = map toDiagnostic (problems <> checkProgram statements)
      sendNotification SMethod_TextDocumentPublishDiagnostics $
        PublishDiagnosticsParams uri (Just (virtualFileVersion contents)) diagnostics

summary :: Uri -> Text -> Text
summary uri text =
  fileName uri <> ": " <> T.pack (show (countLines text)) <> " lines"

fileName :: Uri -> Text
fileName uri = T.takeWhileEnd (/= '/') (getUri uri)
