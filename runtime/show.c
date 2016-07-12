
// no header of this file's own for now
#include <inttypes.h>
#include <stdio.h>
#include "log.h"
#include "stg.h"
#include "heap.h"
#include "stack.h"
#include "obj.h"
#include "stdlib.h"
#include "string.h"


void showStgObj(LogLevel priority, Obj *p) {
  showStgObjPretty(priority, p);
  // showStgObjDebug(Obj *p)
}
void showStgVal(LogLevel priority, PtrOrLiteral v) {
  showStgValPretty(priority, v);
  // showStgValDebug(v);
}

static const int showDepthLimit = 1000;
static int depth;
static Obj *stack[1000];

void showStgObjRecDebug(LogLevel priority, Obj *p);
void showStgObjDebug(LogLevel priority, Obj *p) {
  depth = 0;
  showStgObjRecDebug(priority, p);
}

void showStgObjRecPretty(LogLevel priority, Obj *p);
void showStgObjPretty(LogLevel priority,Obj *p) {
  depth = 0;
  showStgObjRecPretty(priority, p);
  LOG(priority,"\n");
}

void showStgCont(LogLevel priority, Cont *c) {
  ContType type = getContType(c);
  switch (type) {
  case UPDCONT:
    LOG(priority, "UPDCONT  %s\n", c->ident);
    return;

  case CASECONT:
    LOG(priority, "CASECONT %s\n", c->ident);
    return;

  case CALLCONT:
    LOG(priority, "CALLCONT %s\n", c->ident);
    return;

  case STACKCONT:
    LOG(priority, "STACKCONT  %s\n", c->ident);
    return;

  case POPMECONT:
    LOG(priority, "POPMECONT  %s\n", c->ident);
    return;

  case LETCONT:
    LOG(priority, "LETCONT  %s\n", c->ident);
    return;

  default:
    LOG(LOG_ERROR, "showStgCont default case! %d %s\n", type, objTypeNames[type]);
    exit(0);
  }
}

void showStgObjRecPretty(LogLevel priority, Obj *p) {

  if (p == NULL) {
    LOG(priority, "NULL");
    return;
  }

  // depth check first
  if (depth+1 >= showDepthLimit) {
    LOG(LOG_ERROR, "******showStgObjRec depth exceeded\n");
    return;
  }

  InfoTab it = *(getInfoPtr(p));

  for (int i=0; i != depth; i++) {
    if (p == stack[i]) {
      LOG(priority, "((%s))", it.name);
      return;
    }
  }
  stack[depth++] = p;

  ObjType type = getObjType(p);
  if (type != BLACKHOLE &&
      type != INDIRECT &&
      type != it.objType) {
    if (!(type == PAP && it.objType == FUN)) {
      LOG(LOG_ERROR, "getObjType(p) = %s, it.objType = %s\n",
	      objTypeNames[type], objTypeNames[it.objType]);
      assert(false);
    }
  }
  if (strcmp(it.name, p->ident)) {
    if(type != PAP) {
      LOG(LOG_ERROR, "mismatch in infotab and object names \"%s\" != \"%s\"\n",
	      it.name, p->ident);
      assert(false);
    }
  }

  switch (type) {
  case PAP: {
    LOG(priority, "%s = <%s>", p->ident, objTypeNames[type]);
    int start = startPAPFVsB(p);
    int div = endPAPFVsB(p);
    int end = endPAPFVsU(p);
    LOG(priority, "[");
    for (int i = start; i != end; i++ ) {
      if (i == div) fprintf(stderr, "|");
      PtrOrLiteral v = p->payload[i];
      if (mayBeBoxed(v) && mayBeUnboxed(v)) fprintf(stderr, "?");
      else if (mayBeBoxed(v)) fprintf(stderr, "B");
           else LOG(priority, "U");
    }
    LOG(priority, "][");
    Bitmap64 bm = p->payload[end].b;
    int size = bm.bitmap.size;
    uint64_t mask = bm.bitmap.mask;
    LOG(priority, "%d,%" PRIx64 ",", size, mask);
    for ( int i = 0; i != size; i++, mask >>= 1 ) {
      PtrOrLiteral v = p->payload[end + 1 + i];
      if (mask & 0x1) {
	if (!mayBeBoxed(v)) LOG(priority, "!"); else LOG(priority, "B");
      } else {
	if (!mayBeUnboxed(v)) LOG(priority, "!"); else LOG(priority, "U");
      }
    }
    LOG(priority, "]");
    break;
  }

  case FUN:
  case THUNK:
  case BLACKHOLE: {
    LOG(priority, "%s = <%s>", p->ident, objTypeNames[type]);
    break;
  }

  case CON:
    LOG(priority, "%s = %s", p->ident, it.conFields.conName );
    int arity = it.conFields.arity;
    if (arity > 0) {
      if (arity > 1) LOG(priority, "(");
      else LOG(priority, " ");
      showStgValPretty(priority, p->payload[0]);
      for (int i = 1; i < arity; i++) {
	    LOG(priority, ", ");
	    showStgValPretty(priority, p->payload[i]);
      }
      if (arity > 1) fprintf(stderr, ")");
    }
    break;

  case INDIRECT:
    LOG(priority, "%s --> ", p->ident );
    showStgObjRecPretty(priority, p->payload[0].op);
    break;

  default:
    LOG(LOG_ERROR,"********* default in showStgObj!\n");
    // exit(0);
  }
  depth--;
}

void showStgValPretty(LogLevel priority, PtrOrLiteral v) {
#if USE_ARGTYPE
  switch (v.argType) {
  case INT:
    LOG(priority, "%" PRId64, v.i);
    break;
  case DOUBLE:
    LOG(priority, "%f", v.d);
    break;
    //  case FLOAT:
    //    fprintf(stderr,"%f", v.f);
    //    break;
  case HEAPOBJ:
    showStgObjRecPretty(priority, v.op);
    break;
  default:
    LOG(LOG_FATAL, "undefined PtrOrLiteral.tag! tag=%d\n", v.argType);
    exit(1);
  }
#endif
}


void showStgObjRecDebug(LogLevel priority, Obj *p) {

  // depth check first
  if (depth+1 >= showDepthLimit) {
    LOG(LOG_ERROR, "******showStgObjRec depth exceeded\n");
    return;
  }
  for (int i=0; i != depth; i++) {
    if (p == stack[i]) {
      LOG(LOG_ERROR, "   ***cycle\n");
      return;
    }
  }
  stack[depth++] = p;



  InfoTab it = *(getInfoPtr(p));
  ObjType type = getObjType(p);
  LOG(priority, "%s %s %s ", objTypeNames[type],
	  objTypeNames[it.objType], it.name);
  switch (type) {
  case FUN:
    LOG(priority, "\n");
    break;

  case PAP:
    LOG(priority, "\n");
    break;

  case CON:
    LOG(priority, "tag %d arity %d\n", it.conFields.tag, it.conFields.arity );
    for (int i = 0; i != it.conFields.arity; i++)
      showStgValDebug(priority, p->payload[i]);
    break;

  case THUNK:
    LOG(priority, "\n");
    break;

  case BLACKHOLE:
    LOG(priority, "\n");
    break;

  case INDIRECT:
    LOG(priority, "INDIRECT to\n");
    showStgObjRecDebug(priority, p->payload[0].op);
    break;

  default:
    LOG(LOG_FATAL, "default in showStgObj!\n");
    exit(1);
  }
  depth--;
}

void showStgValDebug(LogLevel priority, PtrOrLiteral v) {
#if USE_ARGTYPE
  switch (v.argType) {
  case INT:
#ifdef  __clang__
    LOG(priority, "INT %lld\n", v.i);
#else
    LOG(priority, "INT %ld\n", v.i);
#endif
    break;
  case DOUBLE:
    LOG(priority, "DOUBLE %f\n", v.d);
    break;
  case HEAPOBJ:
    LOG(priority, "HEAPOBJ %p ", v.op);
    showStgObjRecDebug(priority, v.op);
    break;
  default:
    LOG(LOG_ERROR, "undefined PtrOrLiteral.tag!\n");
    exit(0);
  }
#endif
}

void showObjSpaceInfo();

void showObjSpaceInfo(LogLevel priority) {
  LOG(priority, "SHO range is %p to %p\n",
	  &stgStatObj[0],
	  &stgStatObj[stgStatObjCount-1]);
  LOG(priority, "heap range is %p to %p\n", stgHeap, stgHP);
  LOG(priority, "heap toPtr is %p\n", toPtr);
}

bool isSHO(Obj *p) {
  return (p >= stgStatObj[0] && p <= stgStatObj[stgStatObjCount-1]);
}

bool isHeap(Obj *p) {
  return (isTo(p) || isFrom(p));
}

bool isFrom(void *p) {
  return (p >= fromPtr && (char *) p < (char *) fromPtr + stgHeapSize / 2);
}

bool isTo(void *p) {
  return (p >= toPtr && (char *) p < (char *) toPtr + stgHeapSize / 2);
}

void showStgStack(LogLevel priority) {
  LOG(priority, "\nSTG Stack:\n\n");
  for (char *p = (char*)stgSP;
       p < (char*)stgStack + stgStackSize;
       p += getContSize((Cont *)p)) {
     showStgCont(priority, (Cont *)p);
   }
}

void showStgHeap(LogLevel priority) {
  //  return;
  LOG(priority, "\nSTG static objects: \n\n");
  for (int i = 0; i != stgStatObjCount; i++) {
    showStgObj(priority, stgStatObj[i]);
    LOG(priority, "\n");
  }

  LOG(priority, "\nSTG heap:\n\n");
  char *p = (char*)stgHeap;
  while (p < (char*)stgHP) {
    showStgObj(priority, (Obj *)p);
    p += getObjSize((Obj *)p);
    while (p < (char*)stgHP && *((uintptr_t *)p) == 0) {
      p += sizeof(uintptr_t);
    }
  }
  showStgStack(priority);
}
