{-# LANGUAGE OverloadedStrings #-}

module Calc.QuerySpec (spec) where

import Calc.Parser (parseProgram)
import Calc.Query (definitionOf, occurrenceAt, referencesOf)
import Calc.Resolve (OccKind (..), Occurrence (..), occurrences)
import Calc.Syntax (Span (..))
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = do
  describe "occurrenceAt" $ do
    it "finds the name of a definition" $
      occName <$> at 0 4 `shouldBe` Just "price"
    it "finds a variable in an expression" $
      occName <$> at 1 10 `shouldBe` Just "price"
    it "finds a name from its last character" $
      occName <$> at 0 8 `shouldBe` Just "price"
    it "finds nothing just after a name" $
      at 0 9 `shouldBe` Nothing
    it "finds nothing on a number or an operator" $
      (at 1 16, at 1 18) `shouldBe` (Nothing, Nothing)
    it "finds nothing on a line without statements" $
      at 3 0 `shouldBe` Nothing

  describe "definitionOf" $ do
    it "finds the definition of a name" $
      definitionOf "price" occs `shouldBe` Just (Occurrence "price" (Span 0 4 9) Definition)
    it "finds the first definition of a name defined twice" $
      definitionOf "a" (occurrencesOf "let a = 1\nlet a = 2\n")
        `shouldBe` Just (Occurrence "a" (Span 0 4 5) Definition)
    it "finds nothing for a name that is not defined" $
      definitionOf "fee" occs `shouldBe` Nothing

  describe "referencesOf" $ do
    it "finds the uses of a name" $
      map occSpan (referencesOf False "price" occs) `shouldBe` [Span 1 10 15, Span 2 12 17]
    it "adds the definition when asked to" $
      map occSpan (referencesOf True "price" occs)
        `shouldBe` [Span 0 4 9, Span 1 10 15, Span 2 12 17]
    it "finds nothing for a name that is not defined" $
      referencesOf True "fee" occs `shouldBe` []
 where
  program :: Text
  program = "let price = 1200\nlet tax = price * 8 / 100\nlet total = price + tax + fee\n"
  occurrencesOf = occurrences . snd . parseProgram
  occs = occurrencesOf program
  at line column = occurrenceAt line column occs
