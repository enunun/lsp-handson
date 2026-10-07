module Main (main) where

import Lsp.Server qualified

main :: IO ()
main = Lsp.Server.run
