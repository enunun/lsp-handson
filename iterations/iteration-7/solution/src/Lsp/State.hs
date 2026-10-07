-- | The analyses of the open documents, shared by all handlers.
module Lsp.State (Cache, newCache, updateAnalysis, lookupAnalysis) where

import Calc.Analysis (Analysis, analyze)
import Control.Concurrent.STM (TVar, atomically, modifyTVar', newTVarIO, readTVarIO)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Language.LSP.Protocol.Types (NormalizedUri)

type Cache = TVar (Map NormalizedUri Analysis)

newCache :: IO Cache
newCache = newTVarIO Map.empty

-- | Analyzes the new text of a document and keeps the result.
updateAnalysis :: Cache -> NormalizedUri -> Text -> IO Analysis
updateAnalysis cache uri text = do
  let analysis = analyze text
  atomically (modifyTVar' cache (Map.insert uri analysis))
  pure analysis

-- | The latest analysis of a document, if it has been opened.
lookupAnalysis :: Cache -> NormalizedUri -> IO (Maybe Analysis)
lookupAnalysis cache uri = Map.lookup uri <$> readTVarIO cache
