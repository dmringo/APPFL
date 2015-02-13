-- TODO: 
-- letrec: turn into nested let?
-- data types

module Parser
( program
, declaration -- for testing
, expression -- for testing
, Variable
, Constructor
, Literal(..)
, Atom(..)
, FunctionArity(..)
, Expression(..)
, Alternative(..)
, Object(..)
, Declaration(..)
, Program(..)
, Primitive(..)
) where

-- stg like parser

import Parsing
import Lexer

-- Syntax from "Making a Fast Curry..." by Simon Marlow and Simon Peyton Jones
-- pg 

type Variable = String

type Constructor = String

data Literal = Int Int | Double Double deriving (Eq, Show, Read)

-- Literal or Varaible
data Atom = Literal Literal | Variable Variable deriving (Eq, Show, Read)

-- Deal with possible unknown arity
type FunctionArity = Maybe Int

data Expression = Atom Atom
                | FunctionCall Variable FunctionArity [Atom]
                | SatPrimCall Primitive [Atom] 
                | Let [(Variable,Object)] Expression
                | Case Expression [Alternative]
                deriving (Eq, Show, Read)
               
data Alternative = Alt Constructor [Variable] Expression
                 | DefaultAlt Variable Expression
                 deriving (Eq, Show, Read)
                 
data Object = FUN [Variable] Expression
            | PAP Variable [Atom]
            | CON Constructor [Atom]
            | THUNK Expression
            | BLACKHOLE
            | ERROR
            deriving (Eq, Show, Read)

data Declaration = Declaration Variable Object deriving (Show)

data Program = Program [Declaration] deriving (Show)

data Primitive = Add | Sub | Mul | Eq deriving (Eq, Show, Read)

sym :: [Char] -> Parser (Pos Token) [Char]
sym xs = literal (Symbol,xs) `using` snd

obj :: [Char] -> Parser (Pos Token) [Char]
obj xs = literal (Obj,xs) `using` snd

key :: [Char] -> Parser (Pos Token) [Char]
key xs = literal (Keyword,xs) `using` snd

kind :: Tag -> Parser (Pos Token) [Char]
kind t = (satisfy ((==t).fst)) `using` snd

atom :: Parser (Pos Token) Atom
atom = (kind Integer `using` intFN) `alt`
       (kind Floating `using` doubleFN) `alt`
       (kind Ident `using` Variable)
 
intFN :: String -> Atom
intFN xs = Literal (Int (read xs :: Int))

doubleFN :: String -> Atom
doubleFN xs = Literal (Double (read xs :: Double))


expression :: Parser (Pos Token) Expression
expression = ((kind Ident `then'` some atom) `using` funcallFN)
             `alt`
             ((kind Prim `then'` some atom) `using` primcallFN)
             `alt` 
             ((key "let" `xthen` sym "{" `xthen` some vo
             `thenx` sym "}" `thenx` key "in" `then'` expression) `using` letFN)
             `alt`
             ((key "case" `xthen` expression `thenx` key "of" `thenx`
             sym "{" `then'` alternative `then'` many (sym ";" `xthen`
             alternative) `thenx` sym "}" ) `using` caseFN)
             `alt`
             (atom `using` Atom) 
             -- want atom last otherwise funccall could get parsed as atom 

-- not sure what to do w/ arity yet            
funcallFN :: (Variable, [Atom]) -> Expression
funcallFN (f,as) = FunctionCall f Nothing as

-- only doing some primitives
primcallFN :: (String, [Atom]) -> Expression
primcallFN (p,as) | p == "plus#" = SatPrimCall Add as
                  | p == "sub#" = SatPrimCall Sub as
                  | p == "mult#" = SatPrimCall Mul as
                  | p == "eq#" = SatPrimCall Eq as

vo :: Parser (Pos Token) (Variable, Object)
vo = (kind Ident `thenx` sym "=" `then'` object) 
     `alt`
     (kind Ident `thenx` sym "=" `then'` object `thenx` sym ";")

letFN :: ([(Variable, Object)], Expression) -> Expression
letFN (vos,e) = Let vos e

caseFN :: ((Expression, Alternative), [Alternative]) -> Expression
caseFN ((e,a),as) = Case e (a:as) 

alternative :: Parser (Pos Token) Alternative
alternative = ((kind Ident `thenx` sym "->" `then'` expression)
              `using` defAltFN)
              `alt`
              ((kind Construct `then'` many (kind Ident) `thenx`
              sym "->" `then'` expression) `using` altFN )
 
altFN :: ((Constructor, [Variable]), Expression) -> Alternative
altFN ((c,vs),e) = Alt c vs e

defAltFN :: (Variable, Expression) -> Alternative
defAltFN (v,e) = DefaultAlt v e

object :: Parser (Pos Token) Object
object = ((obj "PAP" `xthen` sym "(" `xthen` kind Ident 
            `then'` some atom `thenx` sym ")") `using` papFN) 
         `alt`
         ((obj "CON" `xthen` sym "(" `xthen` kind Construct 
            `then'` many atom `thenx` sym ")") `using` conFN) 
         `alt`
         ((obj "FUN" `xthen` sym "(" `xthen` some (kind Ident) 
            `thenx` sym "->" `then'` expression `thenx` sym ")") 
            `using` funFN)
         `alt`
         ((obj "THUNK" `xthen` sym "(" `xthen` expression 
         `thenx` sym ")") `using` THUNK)
         `alt`
         ((obj "ERROR") `using` (\_ -> ERROR))

funFN :: ([Variable], Expression) -> Object
funFN (vs, e) = FUN vs e

papFN :: (Variable, [Atom]) -> Object
papFN (v, as) = PAP v as

conFN :: (Constructor, [Atom]) -> Object
conFN (c,as) = CON c as 

declaration :: Parser (Pos Token) Declaration
declaration = (kind Ident `thenx` sym "=" `then'` object) 
                `using` declFN

declFN :: (Variable, Object) -> Declaration
declFN (v,o) = Declaration v o

program :: Parser (Pos Token) Program
program = (declaration `then'` many (sym ";" `xthen` declaration)) `using` progFN

progFN :: (Declaration, [Declaration]) -> Program
progFN (a,b) = Program (a:b)

