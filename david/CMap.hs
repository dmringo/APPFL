{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}


----------------------------  Alternative interface to ConMap idea ----------------------
-- Originally had a container for TyCons with an internal Assoc list of Con --> Arity,
-- but I'm not sure if that's useful.

module CMap
(
  toCMap,
  conArity,
  consExhaust,
  luDCons,
  luDCon,
  luTConInfo,
  luTCon,
  CMap
) where

import ADT
import PPrint
import qualified Data.Map as Map
import Data.Maybe (fromJust)
import Data.List ((\\), find)
import Data.Char (isNumber)

type CMap = Map.Map Con TyCon


-- Construct the CMap from a list of TyCons
toCMap :: [TyCon] -> CMap
toCMap tycons =
  let tab = concatMap (\t-> zip (map dConName $ tycDCons t) (repeat t)) tycons
  in Map.fromList tab


-- Lookup the arity of a DataCon by name     
conArity :: Con -> CMap -> Int      
conArity name conmap =
  let cons = luDCons name conmap
      (DataCon _ mtypes) = getDConInList name cons
  in length mtypes

-- From a Con, find the DataCon it belongs to
getDConInList :: Con -> [DataCon] -> DataCon
getDConInList name cons = fromJust $ find ((==name).dConName) cons


-- retrieve the Con of a DataCon
dConName :: DataCon -> Con
dConName (DataCon n _) = n


-- Given a list of Cons, check if they exhaust all the DataCon constructors
-- for their associated TyCon.
-- The head of the list is used to lookup the TyCon, but otherwise, validity
-- of constructors is *not* checked. (yet)
-- i.e. if given ["A","B","C"] as Cons and a TyCon has been made from
-- data T = A | B,
-- consExhaust will return True
consExhaust :: [Con] -> CMap -> Bool
consExhaust [] _ = False
consExhaust cc@(c:cs) conmap =
  let cons = luDCons c conmap
  in  null $ map dConName cons \\ cc

-- Given a Con and CMap, get the list of DataCons associated with it
luDCons :: Con -> CMap -> [DataCon]
luDCons con conmap = tycDCons $ luTCon con conmap


-- retrieve DataCons from a TyCon
tycDCons :: TyCon -> [DataCon]
tycDCons (TyCon _ _ _ cons) = cons


-- Lookup a DataCon in the CMap by Con
luDCon :: Con -> CMap -> DataCon
luDCon name conmap = getDConInList name $ luDCons name conmap


-- lookup TyCon info by con in the CMap
-- info is a triple of the form
-- (TyCon name, TyCon vars, MonoTypes of the DataCon name given)
luTConInfo :: Con -> CMap -> (Con,[TyVar],[Monotype])
luTConInfo name conmap =
   let (TyCon _ tname vars cons) = luTCon name conmap
       (DataCon _ mTypes) = getDConInList name cons
   in (tname, vars, mTypes)

-- lookup a TyCon by Con in the CMap
luTCon :: Con -> CMap -> TyCon
luTCon name conmap
  | isBuiltInType name = getBuiltInType name -- Short circuit built in literals as constructors?
  | otherwise = case Map.lookup name conmap of
                 Nothing -> error "constructor not in conmap"
                 (Just t) -> t

isInt :: String -> Bool
isInt = and . (map isNumber)

-- Pending
isBuiltInType :: Con -> Bool
isBuiltInType = const False -- isInt?
getBuiltInType :: Con -> TyCon
getBuiltInType = undefined -- TyCon False "Int#" [] [DataCon "Int# []]


instance PPrint CMap where
  toDoc m =
    let
      f (con, tyc) = text con <+> arw <+> tyDoc tyc
      tyDoc (TyCon b n vs dcs) = text "name:" <+> text n $+$
                                 text "boxed:" <+> boolean b $+$
                                 text "TyVars:" <+> varDoc vs $+$
                                 text "DataCons:" <+> dcsDoc dcs
      varDoc vars = brackets $ hsep $ punctuate comma $ map text vars
      dcsDoc dcs = brackets $ vcat $ punctuate comma $ map toDoc dcs
    in vcat $ map f $ Map.toList m
        
    