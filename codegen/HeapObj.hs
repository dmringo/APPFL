{-
struct _Obj {
  InfoTab *infoPtr;         // canonical location of ObjType field
  ObjType objType;          // to distinguish PAP, FUN, BLACKHOLE, INDIRECT
  int argCount;             // for PAP, how many args already applied to?
  char ident[64];           // temporary, just for tracing
  PtrOrLiteral payload[32]; // fixed for now
};

(Obj) 
    { .objType = CON,
      .infoPtr = &it_Left,
      .payload[0] = (PtrOrLiteral) {.argType = HEAPOBJ, .op = &sho_one}
    };

Obj sho_main3 =
  { .objType = THUNK,
    .infoPtr = &it_main3,
  };

Obj sho_one = 
  { .objType = CON,
    .infoPtr = &it_I,
    .payload[0].argType = INT,
    .payload[0].i = 1
  };

-}

module HeapObj (
  showSHOs,
  shoNames
) where

import AST
import InfoTab
import Prelude

-- // two = CON(I 2)
-- Obj sho_two = 
--   { .objType = CON,
--     .infoPtr = &it_I,
--     .payload[0].argType = INT,
--     .payload[0].i = 2
--   };

-- HOs come from InfoTabs

shoNames :: [Obj InfoTab] -> [String]
shoNames = map (\o -> showITType o ++ "_" ++ (name . omd) o)

-- return list of forwards (static declarations) and (static) definitions
showSHOs :: [Obj InfoTab] -> (String,String)
showSHOs objs = 
    let (forwards, defs) = unzip $ map showSHO objs
    in (concat forwards, concat defs)
    

-- maybe should use "static" instead of "extern"
showSHO o =
    let base = "Obj " ++ showITType o ++ "_" ++ (name . omd) o
    in ("extern " ++ base ++ ";\n", 
                     base ++ " =\n" ++ showHO (omd o))

showHO it =
    "{\n" ++
    "  .infoPtr   = &it_" ++ name it ++ ",\n" ++
    "  .objType   = " ++ showObjType it      ++ ",\n" ++
    "  .ident     = " ++ show (name it)      ++ ",\n" ++
       showSHOspec it ++
    "  };\n"

showSHOspec it@(Fun {}) = ""

showSHOspec it@(Pap {}) = ""

showSHOspec it@(Con {}) = payloads $ args it

showSHOspec it@(Thunk {}) = ""

showSHOspec it@(Blackhole {}) = ""

showSHOspec it = ""

-- TODO make indent lib function and use here.
payloads as = "  .payload = {\n" ++ (concatMap payload $ zip [0..] as) ++ "},\n"


payload (ind, LitI i) = 
    "{.argType = INT, .i = " ++ show i ++ "},\n"

payload (ind, LitB b) = 
    "{.argType = BOOL, .b = " ++
    (if b then "true" else "false") ++ "},\n"

payload (ind, LitD d) = 
    "{.argType = DOUBLE, .i = " ++ show d ++ "},\n"

payload (ind, LitF d) = 
    "{.argType = FLOAT, .i = " ++ show d ++ "},\n"

payload (ind, LitC c) = 
    "{.argType = CHAR, .i = " ++ show c ++ "},\n"
   
-- for SHOs atoms that are variables must be SHOs, so not unboxed
payload (ind, Var v) = 
    "{.argType = HEAPOBJ, .op = &sho_" ++ v ++ "},\n"

ptrOrLitSHO a =
    "{ " ++
    case a of
      LitI i -> ".argType = INT, .i = " ++ show i
      LitB b -> ".argType = BOOL, .b = " ++ (if b then "true" else "false")
      LitD d -> ".argType = DOUBLE, .d = " ++ show d
      LitF f -> ".argType = FLOAT, .f = " ++ show f
      LitC c -> ".argType = CHAR, .c = " ++ show c
      Var v -> ".argType = HEAPOBJ, .op = &sho_" ++ v   -- these must be global
    ++ " }"
