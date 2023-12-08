include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cmakeTestRepo_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(cmakeTestRepo_setup_options)
  option(cmakeTestRepo_ENABLE_HARDENING "Enable hardening" ON)
  option(cmakeTestRepo_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cmakeTestRepo_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cmakeTestRepo_ENABLE_HARDENING
    OFF)

  cmakeTestRepo_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cmakeTestRepo_PACKAGING_MAINTAINER_MODE)
    option(cmakeTestRepo_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cmakeTestRepo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cmakeTestRepo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmakeTestRepo_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cmakeTestRepo_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cmakeTestRepo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmakeTestRepo_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cmakeTestRepo_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cmakeTestRepo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cmakeTestRepo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cmakeTestRepo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cmakeTestRepo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmakeTestRepo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmakeTestRepo_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cmakeTestRepo_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cmakeTestRepo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmakeTestRepo_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cmakeTestRepo_ENABLE_IPO
      cmakeTestRepo_WARNINGS_AS_ERRORS
      cmakeTestRepo_ENABLE_USER_LINKER
      cmakeTestRepo_ENABLE_SANITIZER_ADDRESS
      cmakeTestRepo_ENABLE_SANITIZER_LEAK
      cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED
      cmakeTestRepo_ENABLE_SANITIZER_THREAD
      cmakeTestRepo_ENABLE_SANITIZER_MEMORY
      cmakeTestRepo_ENABLE_UNITY_BUILD
      cmakeTestRepo_ENABLE_CLANG_TIDY
      cmakeTestRepo_ENABLE_CPPCHECK
      cmakeTestRepo_ENABLE_COVERAGE
      cmakeTestRepo_ENABLE_PCH
      cmakeTestRepo_ENABLE_CACHE)
  endif()

  cmakeTestRepo_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cmakeTestRepo_ENABLE_SANITIZER_ADDRESS OR cmakeTestRepo_ENABLE_SANITIZER_THREAD OR cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cmakeTestRepo_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cmakeTestRepo_global_options)
  if(cmakeTestRepo_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cmakeTestRepo_enable_ipo()
  endif()

  cmakeTestRepo_supports_sanitizers()

  if(cmakeTestRepo_ENABLE_HARDENING AND cmakeTestRepo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED
       OR cmakeTestRepo_ENABLE_SANITIZER_ADDRESS
       OR cmakeTestRepo_ENABLE_SANITIZER_THREAD
       OR cmakeTestRepo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cmakeTestRepo_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED}")
    cmakeTestRepo_enable_hardening(cmakeTestRepo_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cmakeTestRepo_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cmakeTestRepo_warnings INTERFACE)
  add_library(cmakeTestRepo_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cmakeTestRepo_set_project_warnings(
    cmakeTestRepo_warnings
    ${cmakeTestRepo_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cmakeTestRepo_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(cmakeTestRepo_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cmakeTestRepo_enable_sanitizers(
    cmakeTestRepo_options
    ${cmakeTestRepo_ENABLE_SANITIZER_ADDRESS}
    ${cmakeTestRepo_ENABLE_SANITIZER_LEAK}
    ${cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED}
    ${cmakeTestRepo_ENABLE_SANITIZER_THREAD}
    ${cmakeTestRepo_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cmakeTestRepo_options PROPERTIES UNITY_BUILD ${cmakeTestRepo_ENABLE_UNITY_BUILD})

  if(cmakeTestRepo_ENABLE_PCH)
    target_precompile_headers(
      cmakeTestRepo_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cmakeTestRepo_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cmakeTestRepo_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cmakeTestRepo_ENABLE_CLANG_TIDY)
    cmakeTestRepo_enable_clang_tidy(cmakeTestRepo_options ${cmakeTestRepo_WARNINGS_AS_ERRORS})
  endif()

  if(cmakeTestRepo_ENABLE_CPPCHECK)
    cmakeTestRepo_enable_cppcheck(${cmakeTestRepo_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cmakeTestRepo_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cmakeTestRepo_enable_coverage(cmakeTestRepo_options)
  endif()

  if(cmakeTestRepo_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cmakeTestRepo_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cmakeTestRepo_ENABLE_HARDENING AND NOT cmakeTestRepo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmakeTestRepo_ENABLE_SANITIZER_UNDEFINED
       OR cmakeTestRepo_ENABLE_SANITIZER_ADDRESS
       OR cmakeTestRepo_ENABLE_SANITIZER_THREAD
       OR cmakeTestRepo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cmakeTestRepo_enable_hardening(cmakeTestRepo_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
