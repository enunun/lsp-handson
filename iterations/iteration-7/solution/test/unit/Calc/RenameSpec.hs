{-# LANGUAGE OverloadedStrings #-}

module Calc.RenameSpec (spec) where

import Calc.Parser (parseProgram)
import Calc.Rename (RenameError (..), renameEdits)
import Calc.Resolve (occurrences)
import Calc.Syntax (Span (..))
import Data.List (sortOn)
import Data.Ord (Down (..))
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, elements, forAll, listOf, suchThat, (===))

spec :: Spec
spec = describe "renameEdits" $ do
  it "replaces the definition and every use of a name" $
    edits "rate" "taxRate" `shouldBe` Right [(Span 0 4 8, "taxRate"), (Span 1 17 21, "taxRate")]
  it "rejects a new name that breaks the rule of names" $
    edits "rate" "1x" `shouldBe` Left (InvalidName "1x")
  it "rejects let as a new name" $
    edits "rate" "let" `shouldBe` Left (InvalidName "let")
  it "rejects a new name that is already defined" $
    edits "rate" "tax" `shouldBe` Left (AlreadyDefined "tax")
  it "accepts the same name" $
    edits "rate" "rate" `shouldBe` Right [(Span 0 4 8, "rate"), (Span 1 17 21, "rate")]
  it "gives a program that reads as before" $
    renameIn "rate" "taxRate" program
      `shouldBe` Just "let taxRate = 8\nlet tax = 1200 * taxRate / 100\n"
  prop "gives back the program when a name is renamed and renamed back" $
    forAll newName $ \name ->
      (renameIn name "rate" =<< renameIn "rate" name program) === Just program
 where
  program :: Text
  program = "let rate = 8\nlet tax = 1200 * rate / 100\n"
  edits old new = renameEdits old new (occurrences (snd (parseProgram program)))

-- | Renames a name in a program and applies the edits to its text.
renameIn :: Text -> Text -> Text -> Maybe Text
renameIn old new text = case renameEdits old new (occurrences (snd (parseProgram text))) of
  Left _ -> Nothing
  Right edits -> Just (applyEdits edits text)

-- | Applies edits on single lines. On each line, the edits are applied from the right.
applyEdits :: [(Span, Text)] -> Text -> Text
applyEdits edits text = T.unlines (zipWith editLine [0 ..] (T.lines text))
 where
  editLine lineNo line =
    foldl
      apply
      line
      (sortOn (Down . spanStart . fst) [edit | edit@(s, _) <- edits, spanLine s == lineNo])
  apply line (Span _ start end, new) = T.take start line <> new <> T.drop end line

-- | Valid names that are not defined in the program, except rate itself.
newName :: Gen Text
newName =
  (T.pack <$> ((:) <$> elements letters <*> listOf (elements (letters <> digits))))
    `suchThat` (`notElem` ["let", "tax"])
 where
  letters = ['a' .. 'z'] <> ['A' .. 'Z']
  digits = ['0' .. '9']
