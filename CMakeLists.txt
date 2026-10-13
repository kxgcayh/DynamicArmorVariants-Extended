cmake_minimum_required(VERSION 3.24)

project(
    DynamicArmorVariants
    VERSION 1.3.0
    LANGUAGES CXX
)

set(DAVE_BUILD_VERSION "1.3.0")
set(DAVE_VERSION_MAJOR 1)
set(DAVE_VERSION_MINOR 3)
set(DAVE_VERSION_PATCH 0)
set(DAVE_VERSION_STRING "1.3.0")

# User's CommonLibSSE-NG path
set(COMMONLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../CommonLibSSE-NG" CACHE PATH "Path to user CommonLibSSE-NG")

set(BUILD_TESTS OFF CACHE BOOL "Disable CommonLibSSE-NG tests" FORCE)
set(BUILD_SKYRIM_SE ON CACHE BOOL "Enable Skyrim SE" FORCE)
set(BUILD_SKYRIM_AE ON CACHE BOOL "Enable Skyrim AE" FORCE)
set(BUILD_SKYRIM_VR ON CACHE BOOL "Enable Skyrim VR" FORCE)
set(SKSE_SUPPORT_XBYAK ON CACHE BOOL "Enable Xbyak support in CommonLibSSE-NG" FORCE)

add_subdirectory("${COMMONLIB_DIR}" CommonLibSSE EXCLUDE_FROM_ALL)

# Collect all project source files
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
)

add_library(${PROJECT_NAME} SHARED ${PROJECT_SOURCES})

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    DAVE_VERSION_MAJOR=${DAVE_VERSION_MAJOR}
    DAVE_VERSION_MINOR=${DAVE_VERSION_MINOR}
    DAVE_VERSION_PATCH=${DAVE_VERSION_PATCH}
    DAVE_VERSION_STRING="${DAVE_VERSION_STRING}"
    SKSE_SUPPORT_XBYAK=1
)

target_include_directories(${PROJECT_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/main"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/PCH"
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${COMMONLIB_DIR}/extern/openvr/headers"
    "/Volumes/S512/Projects/ETC/vcpkg/installed/x64-windows-cross/include"
)

target_precompile_headers(${PROJECT_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src/PCH/PCH.h"
)

target_link_directories(${PROJECT_NAME} PRIVATE
    "/Volumes/S512/Projects/ETC/vcpkg/installed/x64-windows-cross/lib"
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    CommonLibSSE::CommonLibSSE
    jsoncpp
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    OUTPUT_NAME "DynamicArmorVariants"
    SUFFIX ".dll"
)
