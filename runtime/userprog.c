#include "stg_header.h"
void registerSHOs();
FnPtr tnk_main();
InfoTab it_one = 
  { .name                = "one",
    .fvCount             = 0,
    .entryCode           = &stg_constructorcall,
    .objType             = CON,
    .conFields.arity     = 1,
    .conFields.tag       = 0,
    .conFields.conName   = "I",
  };
InfoTab it_main = 
  { .name                = "main",
    .fvCount             = 0,
    .entryCode           = &tnk_main,
    .objType             = THUNK,
  };

Obj sho_one =
{
  .infoPtr   = &it_one,
  .objType   = CON,
  .ident     = "one",
    .payload[ 0 ].argType = INT,
    .payload[ 0 ].i = 1,
  };
Obj sho_main =
{
  .infoPtr   = &it_main,
  .objType   = THUNK,
  .ident     = "main",
  };

void registerSHOs() {
  stgStatObj[stgStatObjCount++] = &sho_one;
  stgStatObj[stgStatObjCount++] = &sho_main;
}


DEFUN1(tnk_main, self) {
  fprintf(stderr, "main here\n");  stgThunk(self);
  stgCurVal = HOTOPL(&sho_one);
  STGEVAL(stgCurVal);
  STGRETURN0();
  ENDFUN;
}
DEFUN0(start) {
  registerSHOs();
  stgPushCont(showResultCont);
  STGEVAL(((PtrOrLiteral){.argType = HEAPOBJ, .op = &sho_main}));
  STGRETURN0();
  ENDFUN;
}

int main (int argc, char **argv) {
  initStg();
  initCmm();
  initGc();
  CALL0_0(start);
  showStgHeap();
  return 0;
}

