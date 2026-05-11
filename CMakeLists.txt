cmake_minimum_required(VERSION 3.16)
project(pokeblue C CXX)

include(CheckIPOSupported)
include(FetchContent)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-O0 -g)
    else()
        add_compile_options(-O3)
    endif()
endif()

# ---------------------------------------------------------------------------
# gb-recompiled runtime
# When consumed by an umbrella compilation (e.g. GB-Recomp/pgbcomp), the
# parent is expected to provide `gbrt`. We detect that and skip the fetch.
# ---------------------------------------------------------------------------
if(NOT TARGET gbrt)
    set(GBRT_REF "main" CACHE STRING "git ref of GB-Recomp/gb-recompiled to use")
    FetchContent_Declare(gb_recompiled
        GIT_REPOSITORY https://github.com/GB-Recomp/gb-recompiled.git
        GIT_TAG ${GBRT_REF}
        GIT_SHALLOW TRUE
    )
    FetchContent_GetProperties(gb_recompiled)
    if(NOT gb_recompiled_POPULATED)
        FetchContent_Populate(gb_recompiled)
    endif()
    add_subdirectory(${gb_recompiled_SOURCE_DIR}/runtime ${CMAKE_BINARY_DIR}/_gbrt_build)
endif()

# ---------------------------------------------------------------------------
# Cart sources
# ---------------------------------------------------------------------------
set(POKEBLUE_SOURCES
    pokeblue_main.c
    pokeblue.c
    pokeblue_rom.c
    pokeblue_dispatch_chunk_0.c
    pokeblue_dispatch_chunk_1.c
    pokeblue_dispatch_chunk_2.c
    pokeblue_funcs_0.c
    pokeblue_funcs_1.c
    pokeblue_funcs_2.c
    pokeblue_funcs_3.c
    pokeblue_funcs_4.c
    pokeblue_funcs_5.c
    pokeblue_funcs_6.c
    pokeblue_funcs_7.c
    pokeblue_funcs_8.c
    pokeblue_funcs_9.c
    pokeblue_funcs_10.c
    pokeblue_funcs_11.c
    pokeblue_funcs_12.c
    pokeblue_funcs_13.c
    pokeblue_funcs_14.c
    pokeblue_funcs_15.c
    pokeblue_funcs_16.c
    pokeblue_funcs_17.c
    pokeblue_funcs_18.c
    pokeblue_funcs_19.c
    pokeblue_funcs_20.c
    pokeblue_funcs_21.c
    pokeblue_funcs_22.c
    pokeblue_funcs_23.c
    pokeblue_funcs_24.c
    pokeblue_funcs_25.c
)

set(GBRECOMP_GENERATED_OPT_LEVEL "3" CACHE STRING "Optimization level for generated ROM source files")
set_property(CACHE GBRECOMP_GENERATED_OPT_LEVEL PROPERTY STRINGS 0 1 2 3)
set_source_files_properties(${POKEBLUE_SOURCES} PROPERTIES COMPILE_OPTIONS "-O${GBRECOMP_GENERATED_OPT_LEVEL}")

# ---------------------------------------------------------------------------
# pokeblue_cart: static library so umbrella compilations can link us in.
# Exposes `pokeblue_main(argc, argv)` for the launcher's g_games[].
# ---------------------------------------------------------------------------
add_library(pokeblue_cart STATIC ${POKEBLUE_SOURCES})
target_include_directories(pokeblue_cart PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(pokeblue_cart PUBLIC gbrt)

# ---------------------------------------------------------------------------
# Standalone launcher executable. Only built when this is the top-level
# CMake project.
# ---------------------------------------------------------------------------
if(CMAKE_PROJECT_NAME STREQUAL "pokeblue")
    add_executable(pokeblue_launcher launcher_main.cpp)
    target_link_libraries(pokeblue_launcher PRIVATE pokeblue_cart gbrt)
    set_target_properties(pokeblue_launcher PROPERTIES OUTPUT_NAME pokeblue)
endif()
