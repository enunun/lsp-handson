{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The Calc language server: its capabilities and the handlers for LSP messages.
module Lsp.Server (run, serverDefinition, handlers) where

import Calc.Check (checkProgram)
import Calc.Eval (evalProgram)
import Calc.Parser (parseProgram)
import Calc.Query (nameAt)
import Calc.Summary (countLines)
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
import Language.LSP.VFS (VirtualFile, virtualFileText, virtualFileVersion)
import Lsp.Convert (fromPosition, hoverText, toDiagnostic)

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
        file <- getVirtualFile (toNormalizedUri (params ^. L.textDocument . L.uri))
        respond (Right (maybe (InR Null) InL (hoverAt (fromPosition (params ^. L.position)) =<< file)))
    ]

-- | The value of the name at a position in a document.
hoverAt :: (Int, Int) -> VirtualFile -> Maybe Hover
hoverAt (line, column) contents = do
  let (_problems, statements) = parseProgram (virtualFileText contents)
  name <- nameAt line column statements
  value <- Map.lookup name (evalProgram statements)
  pure (Hover (InL (MarkupContent MarkupKind_PlainText (hoverText name value))) Nothing)

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
