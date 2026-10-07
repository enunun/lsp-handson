-- | Computes the values of the statements in a Calc program.
module Calc.Eval (EvalError (..), evalProgram) where

import Calc.Syntax (Expr (..), Op (..), Statement (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)

-- | Why a value cannot be computed.
data EvalError
  = DivisionByZero
  | UndefinedVariable Text
  deriving (Eq, Show)

{- | The value of every defined name. Statements are evaluated from top to bottom, and a name
defined twice keeps the value of its first definition.
-}
evalProgram :: [Statement] -> Map Text (Either EvalError Integer)
evalProgram = foldl' define Map.empty
 where
  define values (Statement name _ expr)
    | name `Map.member` values = values
    | otherwise = Map.insert name (evalExpr values expr) values

evalExpr :: Map Text (Either EvalError Integer) -> Expr -> Either EvalError Integer
evalExpr _ (Number n) = Right n
evalExpr values (Var name _) = fromMaybe (Left (UndefinedVariable name)) (Map.lookup name values)
evalExpr values (BinOp op left right) = do
  a <- evalExpr values left
  b <- evalExpr values right
  apply op a b

apply :: Op -> Integer -> Integer -> Either EvalError Integer
apply Add a b = Right (a + b)
apply Sub a b = Right (a - b)
apply Mul a b = Right (a * b)
apply Div _ 0 = Left DivisionByZero
apply Div a b = Right (a `div` b)
