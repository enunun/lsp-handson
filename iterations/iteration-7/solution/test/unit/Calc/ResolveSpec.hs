{-# LANGUAGE OverloadedStrings #-}

module Calc.ResolveSpec (spec) where

import Calc.Parser (parseProgram)
import Calc.Resolve (OccKind (..), Occurrence (..), occurrences)
import Calc.Syntax (Span (..))
import Data.Text (Text)
import Test.Hspec

spec :: Spec
spec = describe "occurrences" $ do
  it "finds nothing in an empty program" $
    resolve "" `shouldBe` []
  it "finds the definition of a name" $
    resolve "let price = 1200\n" `shouldBe` [Occurrence "price" (Span 0 4 9) Definition]
  it "finds the variables of an expression from left to right" $
    resolve "let total = price + tax\n"
      `shouldBe` [ Occurrence "price" (Span 0 12 17) Use
                 , Occurrence "tax" (Span 0 20 23) Use
                 , Occurrence "total" (Span 0 4 9) Definition
                 ]
  it "lists the uses of a statement before its definition, and the statements in order" $
    resolve "let a = 1\nlet b = a\n"
      `shouldBe` [ Occurrence "a" (Span 0 4 5) Definition
                 , Occurrence "a" (Span 1 8 9) Use
                 , Occurrence "b" (Span 1 4 5) Definition
                 ]
 where
  resolve :: Text -> [Occurrence]
  resolve = occurrences . snd . parseProgram
