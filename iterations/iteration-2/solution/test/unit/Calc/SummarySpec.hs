{-# LANGUAGE OverloadedStrings #-}

module Calc.SummarySpec (spec) where

import Calc.Summary (countLines)
import Test.Hspec

spec :: Spec
spec = describe "countLines" $ do
  it "counts no lines in an empty document" $
    countLines "" `shouldBe` 0
  it "counts one line without a newline" $
    countLines "let a = 1" `shouldBe` 1
  it "counts every line separated by newlines" $
    countLines "let a = 1\nlet b = 2\nlet c = 3" `shouldBe` 3
  it "does not count a line after the final newline" $
    countLines "let a = 1\n" `shouldBe` 1
  it "counts empty lines" $
    countLines "let a = 1\n\nlet b = 2\n" `shouldBe` 3
