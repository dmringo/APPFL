{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE CPP #-}

#include "../options.h"

module CMap
(
  toCMap,
  conArity,
  consExhaust,
  luDCons,
  luDCon,
  luTConInfo,
  luTCon,
  luConTag,
  isBoxedTCon,
  CMap,
  instantiateDataConAt,
  showTypeEnums,
  cTypeEnums,
) where

import Util
import ADT
import PPrint
import qualified Data.Map as Map
import BU(apply)
import Data.Maybe (fromJust, fromMaybe)
import Data.List ((\\), find, intercalate)
import Data.Char (isNumber)
import Debug.Trace
import Language.C.Syntax (Definition)
import Language.C.Quote.GCC


type CMap = Map.Map Con TyCon

cTypeEnums = error "cTypeEnums" -- not used in text version

showTypeEnums :: [TyCon] -> [Definition]
showTypeEnums tycons = map showTypeEnum tycons

showTypeEnum :: TyCon -> Definition
showTypeEnum (TyCon _ con _ dataCons) =
  let es = [ [cenum| $id:("con_" ++  _mhsSanitize c) |] | DataCon c _ <- dataCons ]
      typ = [cty| enum $id:("tycon_" ++ con) { $enums:es} |]
  in [cedecl| $ty:typ;|]


-- MHS HACK FIX, see also CMap.luConTag
_mhsSanitize c | c == "D#" = "D"
               | c == "I#" = "I"
               | otherwise = c

-- Construct the CMap from a list of TyCons
toCMap :: [TyCon] -> CMap
toCMap tycons =
  let tab = concatMap (\t-> zip (map dataConName $ getDataCons t) (repeat t)) tycons
  in Map.fromList tab


-- Lookup the arity of a DataCon by name
conArity :: Con -> CMap -> Int
conArity name conmap
  | isBuiltInType name = 0 -- short circuit for builtins (0,1,2..)
  | otherwise          =
      let cons = luDCons name conmap
          (DataCon _ mtypes) = getDConInList name cons
      in length mtypes

-- From a Con, find the DataCon it belongs to
getDConInList :: Con -> [DataCon] -> DataCon
getDConInList name cons =
  if isBuiltInType name
  then getBuiltInDataCon name
  else fromJust $ find ((==name).dataConName) cons




-- Given a list of Cons, check if they exhaust all the DataCon constructors
-- for their associated TyCon.
-- The head of the list is used to lookup the TyCon, but otherwise, validity
-- of constructors is *not* checked. (yet)
-- i.e. if given ["A","B","C"] as Cons and a TyCon has been made from
-- data T = A | B,
-- consExhaust will return True
consExhaust :: [Con] -> CMap -> Bool
consExhaust [] _ = False
consExhaust cc@(c:cs) conmap
  | isBuiltInType c = False -- assume Int# and Double# cannot be enumerated
  | otherwise =
      let cons = luDCons c conmap
      in  null $ map dataConName cons \\ cc

-- Given a Con and CMap, get the list of DataCons associated with it
luDCons :: Con -> CMap -> [DataCon]
luDCons con conmap = getDataCons $ luTCon con conmap


-- Lookup a DataCon in the CMap by Con
luDCon :: Con -> CMap -> DataCon
luDCon name conmap = getDConInList name $ luDCons name conmap

-- check boxedness of a TyCon name
isBoxedTCon :: Con -> CMap -> Bool
isBoxedTCon c cmap
  | c `elem` primTypeNames = False
  | otherwise    =
      let tcons = map snd $ Map.toList cmap
      in
       case find ((== c) . tyConName) tcons of
        Just (TyCon boxed _ _ _) -> boxed
        Nothing                  -> error $
                                    "TyCon for " ++ c ++ " not found in CMap"


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
  | isBuiltInType name = getBuiltInType name
  | otherwise = case Map.lookup name conmap of
                 Nothing -> error $ "constructor " ++ name ++
                   " not in conmap " ++ show conmap
                 (Just t) -> t


-- Tags are returned as Strings for switch statements in codegen
luConTag :: Con -> CMap -> String
luConTag c cmap | isBuiltInType c = c
                | otherwise       =
                    let tyCon = luTCon c cmap
                    in case elem c (map dataConName $ luDCons c cmap) of
                         -- True -> tyConName tyCon ++ "_" ++ mhsSanitize c
                         True -> "con_" ++ _mhsSanitize c
                         False -> "Tag lookup failure for " ++ c ++ " in " ++
                                  show tyCon
{-
                        where  -- MHS HACK FIX, see also CMap.showTypeEnum
                          mhsSanitize c | c == "D#" = "D"
                                        | c == "I#" = "I"
                                        | otherwise = c
-}
{-
                  let tab = zip (map dataConName $ luDCons c cmap) [0..]
                  in case lookup c tab of
                      Just n -> show n
                      Nothing -> error $ "Tag lookup failing in CMap for " ++ c
-}

-- given a constructor map, data constructor, and list of monotypes to be
-- substituted for the arguments of the type constructor corresponding to
-- the data constructor, return the monotype arguments of the data constructor
-- as a result of the substitution
instantiateDataConAt :: Con -> CMap -> [Monotype] -> [Monotype]
instantiateDataConAt c cmap subms
  | isBuiltInType c = subms
  | otherwise =
    let TyCon _ tcon tvs dcs = luTCon c cmap
        -- get data constructor definition C [Monotype]
        ms = case [ ms | DataCon c' ms <- dcs, c == c' ] of
               [ms] -> ms
               _ -> error $ "instantiateDataConAt: not finding " ++ c ++ " in " ++ show dcs ++
                    " for TyCon: " ++ tcon ++
                    "\nCMap:\n" ++ (show . pprint) cmap
        -- instantiate the Monotypes
        subst = Map.fromList $ zzip tvs subms
    in apply subst ms

isBuiltInType :: Con -> Bool
isBuiltInType c = any ($ c) [isInt, isDouble]

getBuiltInType :: Con -> TyCon
getBuiltInType c
-- have to make a TyCon with at least a DataCon whose constructor
-- matches the query for the typechecker to build the correct
-- types.
-- (empty MonoType list is what it needs here, but it finds it
-- by looking through the DataCons of the TyCon until it finds
-- one whose name matches what it looked up)
  | isInt c    = makePrimTyCon PInt
  | isDouble c = makePrimTyCon PDouble
  | otherwise  = error "builtin TyCon not found!"

getBuiltInDataCon :: Con -> DataCon
getBuiltInDataCon c
  | isInt c = DataCon "I#" [MPrim PInt]
  | isDouble c = DataCon "D#" [MPrim PDouble]
  | otherwise = error "builtin DataCon not found!"

instance PPrint CMap where
  pprint m =
    let
      f (con, tyc) = text con <+> arw $+$ nest 4 (tyDoc tyc)
      tyDoc (TyCon b n vs dcs) = text "TyCon name:" <+> text n $+$
                                 text "boxed:" <+> boolean b $+$
                                 text "TyVars:" <+> listText vs $+$
                                 text "DataCons:" <+> brackList (map pprint dcs)
    in vcat $ map f $ Map.toList m
