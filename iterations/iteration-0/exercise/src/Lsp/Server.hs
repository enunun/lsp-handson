{-# LANGUAGE OverloadedStrings #-}

-- | The Calc language server: its capabilities and the handlers for LSP messages.
module Lsp.Server (run, serverDefinition, handlers) where

import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import Language.LSP.Protocol.Message
import Language.LSP.Server

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
    , options = defaultOptions
    }

handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_notification -> pure ()
    ]
