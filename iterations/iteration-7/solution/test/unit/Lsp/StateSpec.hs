{-# LANGUAGE OverloadedStrings #-}

module Lsp.StateSpec (spec) where

import Calc.Analysis (Analysis (..), analyze)
import Language.LSP.Protocol.Types (Uri (..), toNormalizedUri)
import Lsp.State (lookupAnalysis, newCache, updateAnalysis)
import Test.Hspec

spec :: Spec
spec = do
  describe "lookupAnalysis" $
    it "finds nothing for a document that has not been analyzed" $ do
      cache <- newCache
      found <- lookupAnalysis cache first
      found `shouldBe` Nothing

  describe "updateAnalysis" $ do
    it "keeps the analysis of a document" $ do
      cache <- newCache
      analysis <- updateAnalysis cache first "let a = 1\n"
      found <- lookupAnalysis cache first
      (analysis, found) `shouldBe` (analyze "let a = 1\n", Just (analyze "let a = 1\n"))
    it "replaces the analysis when the document changes" $ do
      cache <- newCache
      _ <- updateAnalysis cache first "let a = 1\n"
      _ <- updateAnalysis cache first "let a = 2\n"
      found <- lookupAnalysis cache first
      fmap anLines found `shouldBe` Just ["let a = 2"]
    it "keeps the analyses of different documents apart" $ do
      cache <- newCache
      _ <- updateAnalysis cache first "let a = 1\n"
      _ <- updateAnalysis cache second "let b = 2\n"
      found <- lookupAnalysis cache first
      fmap anLines found `shouldBe` Just ["let a = 1"]
 where
  first = toNormalizedUri (Uri "file:///first.calc")
  second = toNormalizedUri (Uri "file:///second.calc")
