-- | Runs the Calc server in the test process and talks to it through lsp-test.
module TestServer (runCalcSession) where

import Control.Concurrent (forkIO, killThread)
import Control.Exception (bracket)
import Control.Monad (void)
import Language.LSP.Server (runServerWithHandles)
import Language.LSP.Test (
  Session,
  SessionConfig (ignoreLogNotifications, messageTimeout),
  defaultConfig,
  fullLatestClientCaps,
  runSessionWithHandles,
 )
import Lsp.Server (serverDefinition)
import System.Process (createPipe)

-- | Starts a server connected by two pipes, runs the session as its client, and stops the server.
runCalcSession :: Session a -> IO a
runCalcSession session = do
  (serverIn, clientOut) <- createPipe
  (clientIn, serverOut) <- createPipe
  bracket
    (forkIO (void (runServerWithHandles mempty mempty serverIn serverOut serverDefinition)))
    killThread
    (const (runSessionWithHandles clientOut clientIn config fullLatestClientCaps "." session))
 where
  -- The tests read window/logMessage, which lsp-test drops by default.
  config = defaultConfig {ignoreLogNotifications = False, messageTimeout = 5}
