project(runtime)
  cmake_minimum_required(VERSION 2.8.12.2)

  set(rt_hdrs cmm.h
              gc.h
              stg.h
              stgcmm.h
              stgutils.h
    )

  set(rt_srcs cmm.c
              gc.c
              stg.c
              stgcmm.c
              stgutils.c
    )

  # put headers in build/include
  foreach (header ${rt_hdrs})
    configure_file(${header} ${PROJECT_BINARY_DIR}/../include/${header} COPYONLY)
  endforeach()
  configure_file(stgc.h ${PROJECT_BINARY_DIR}/../include/stgc.h COPYONLY)
  configure_file(cruntime.h ${PROJECT_BINARY_DIR}/../include/cruntime.h COPYONLY)

  if(NOT APPLE) 
    set(CMAKE_C_FLAGS "-Wno-unused-but-set-variable")
  else()
    set(CMAKE_C_FLAGS "-Wno-unused-const-variable")
  endif()

  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99")

  include_directories(
    "/usr/include/malloc"
  )

  # put in build/lib
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/../lib)

  add_library(runtime STATIC ${rt_srcs})
  add_dependencies(runtime ${rt_hdrs})