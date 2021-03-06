#ifndef stg_h
#define stg_h
#include <stdint.h>
#include <stddef.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include "options.h"
#include "cmm.h"
#include "args.h"
#include "log.h"

void startCheck();
void showPerfCounters(LogLevel priority);

struct _Obj;
typedef struct _Obj Obj;
struct _InfoTab;
typedef struct _InfoTab InfoTab;
struct _CInfoTab;
typedef struct _CInfoTab CInfoTab;

// bitmap for specifying boxed/unboxed values
// assume 64 bits, high six bits for length,
// low bit is index 0,
// 0 => unboxed, 1 => boxed


typedef struct Bitmap64proto {
  uintptr_t mask : 58;
  unsigned int size : 6;
} Bitmap64proto;

typedef union Bitmap64 {
  uintptr_t bits;
  Bitmap64proto bitmap;
} Bitmap64;

#define HIST_SIZE 64
typedef struct PrefCounters {
  long heapBytesAllocated;
  long heapBytesCopied;
  long heapMaxSize;
  long heapCollections;
  long heapAllocations;
  long stackBytesAllocated;
  long stackAllocations;
  long stackMaxSize;
  double totalTime;
  double gcTime;
  int heapHistogram[HIST_SIZE];
  int stackHistogram[HIST_SIZE];
} PrefCounters;

#define BMSIZE(bm) (bm.bitmap.size)
#define BMMAP(bm) (bm.bitmap.mask)

//------ stack and heap objects

#if USE_ARGTYPE
typedef enum {          // superfluous, for sanity checking
  INT,
  LONG,
  ULONG,
  FLOAT,
  DOUBLE,
  BITMAP,
  STRING,
  HEAPOBJ
} ArgType;
#endif

// PtrOrLiteral -- literal value or pointer to heap object
typedef struct {
#if USE_ARGTYPE
  ArgType argType;        // superfluous, for sanity checking
#endif
  union {
    int64_t i;
    int64_t l;
    uint64_t u;
    float f;
    double d;
    Bitmap64 b;
    char* s;    // String literals
    Obj *op;
  };
} PtrOrLiteral;

// we can't be certain a value is boxed or unboxed without enabling USE_ARGTYPE
// but we can do some sanity checking.  mayBeBoxed(v) means that v is not
// definitely unboxed
bool mayBeBoxed(PtrOrLiteral v);
bool mayBeUnboxed(PtrOrLiteral v);

// STG registers
// %rbx, %rbp, %r10, %r13, %r14, %r15 callee saved
// TODO:  make heap, stack pointers registers, test performance
// TODO:  distinguish stgCurVal as stgCurPtr and stgCurUbx
#if !defined(__clang__) && !USE_ARGTYPE
register PtrOrLiteral stgCurVal asm("%r14");  // current/return value
register PtrOrLiteral stgCurValU asm("%r13");  // current/return value
#else
extern PtrOrLiteral stgCurVal;  // current/return value
extern PtrOrLiteral stgCurValU;  // current/return value
#endif

extern void *stgHeap, *stgHP;
extern void *toPtr, *fromPtr;
extern const size_t stgHeapSize;
extern const size_t stgStackSize;

extern void *stgStack, *stgSP;
extern PrefCounters perfCounter;

// these are defined in the generated code
extern const int stgStatObjCount;
extern Obj *const stgStatObj[];
extern const int stgInfoTabCount;
extern InfoTab *const stgInfoTab[];
extern const int stgCInfoTabCount;
extern CInfoTab *const stgCInfoTab[];

void initStg();
//void showStgObj(LogLevel priority, Obj *);
//void showStgCont(LogLevel priority, Cont *c);
void showStgHeap(LogLevel priority);
void showStgStack(LogLevel priority);

void showStgVal(LogLevel priority,PtrOrLiteral);
void showStgObjPretty(LogLevel priority, Obj *p);
void showStgObjDebug(LogLevel priority, Obj *p);
void showStgValDebug(LogLevel priority, PtrOrLiteral v);
void showStgValPretty(LogLevel priority, PtrOrLiteral v);

void checkStgHeap();
void showIT(InfoTab *);

// Codegen.hs currently uses STGJUMP(), STGJUMP0(f), and STGRETURN0() to
// exit functions

// ---------------------------------------------------
// Control flow, see also cmm.h

#define STGCALL0(f)				\
  CALL0_0(f)

// change context
// note that the popping of a POPMECONT is just an optimization
// RETURN0() is to let compiler know we really mean it
#define STGJUMP0(f)				\
  do {						\
    stgPopContIfPopMe();			\
    JUMP0(f);					\
    RETURN0();					\
  } while(0)

// bye bye!
#define STGJUMP()						     \
  do {								     \
  derefStgCurVal();						     \
  if (getObjType(stgCurVal.op) == BLACKHOLE) {			     \
    LOG(LOG_ERROR, "STGJUMP terminating on BLACKHOLE\n");	     \
    showStgVal(LOG_ERROR, stgCurVal);				     \
    exit(0);							     \
  }								     \
  STGJUMP0(getInfoPtr(stgCurVal.op)->entryCode);		     \
} while (0)

// return through continuation stack
// note that the popping of a POPMECONT is just an optimization
// RETURN0() is to let compiler know we really mean it
#define STGRETURN0()					\
  do {							\
    stgPopContIfPopMe();				\
    STGJUMP0(((Cont *)stgSP)->entryCode);		\
    RETURN0();						\
  } while(0)

// evaluate Object (not actual function) IN PLACE,
// this should probably only happen in stgApply
/* deprecated
define STGEVAL(e)					     \
  do {							     \
  stgCurVal = e;					     \
  Cont *callCont = stgAllocCallOrStackCont(&it_stgCallCont, 0);     \
  callCont->layout.bits = 0x0UL;			     \
  STGCALL0(getInfoPtr(stgCurVal.op)->entryCode);	     \
  if (getObjType(stgCurVal.op) == BLACKHOLE) {		     \
    LOG(LOG_ERROR, "STGEVAL terminating on BLACKHOLE\n");   \
    showStgVal(LOG_ERROR, stgCurVal);			     \
    exit(0);						     \
  }							     \
  if (getObjType(stgCurVal.op) == THUNK) {		     \
    LOG(LOG_ERROR, "THUNK at end of STGEVAL!\n");	     \
    showStgVal(LOG_ERROR, stgCurVal);			     \
    assert(false);					     \
  }							     \
} while (0)
*/

#endif  //ifdef stg_h
