{-# LANGUAGE MagicHash, UnboxedTuples #-}
module Test where
import AppflPrelude
import APPFL.Prim

myHead (x:xs) = x

main = myHead [True, False]
