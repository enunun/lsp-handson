{-# LANGUAGE OverloadedStrings #-}

-- | Reads the lines of a Calc program.
module Calc.Parser (parseLine, parseProgram) where

import Calc.Syntax (Problem (..), Span (..), Statement (..))
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, isSpace)
import Data.Either (partitionEithers)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T

-- | Reads one line, given its line number. Blank lines and comment lines give 'Nothing'.
parseLine :: Int -> Text -> Maybe (Either Problem Statement)
parseLine lineNo line
  | T.null body || "--" `T.isPrefixOf` body = Nothing
  | otherwise = Just (maybe (Left problem) Right statement)
 where
  body = T.stripStart line
  indent = T.length line - T.length body
  problem = Problem (Span lineNo 0 (T.length line)) "expected: let <name> = <expr>"
  statement = case T.words body of
    ("let" : name : "=" : _ : _) | isName name -> Just (Statement name (nameSpan name))
    _ -> Nothing
  nameSpan name =
    let start = indent + T.length "let" + T.length (T.takeWhile isSpace (T.drop 3 body))
     in Span lineNo start (start + T.length name)

-- | Reads every line of a program, collecting the problems and the statements in order.
parseProgram :: Text -> ([Problem], [Statement])
parseProgram text = partitionEithers (mapMaybe (uncurry parseLine) (zip [0 ..] (T.lines text)))

-- | A name starts with an ASCII letter and continues with ASCII letters and digits.
isName :: Text -> Bool
isName name = case T.uncons name of
  Just (first, rest) -> isLetter first && T.all (\c -> isLetter c || isDigit c) rest
  Nothing -> False
 where
  isLetter c = isAsciiLower c || isAsciiUpper c
