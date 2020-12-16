# Sets the minimum version of CMake required to build the native
# library. You should either keep the default value or only pass a
# value of 3.4.0 or lower.
# by huzongyao

cmake_minimum_required(VERSION 3.0)

option (BUILD_SHARED_LIB "compatible format" ON )

include("../cmake/source_group_by_dir.cmake")


# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds it for you.
# Gradle automatically packages shared libraries with your APK.
file(GLOB_RECURSE NSLUA_SRCS 
    ${CMAKE_CURRENT_SOURCE_DIR}/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/*.m
    ${CMAKE_CURRENT_SOURCE_DIR}/*.a
)
# message(stats "${NSLUA_SRCS}")

message("CMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}")

include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/
    ${CMAKE_CURRENT_SOURCE_DIR}/../lua
)

link_directories(
    ${CMAKE_BINARY_DIR}/bin
    ${CMAKE_BINARY_DIR}/lib
)

# if (BUILD_SHARED_LIB)
    add_library(nslua SHARED ${NSLUA_SRCS})
    # find_library(xlua lua)
    # find_library(IOKit IOKit)
    target_link_libraries(nslua liblua)

    SET_TARGET_PROPERTIES(nslua PROPERTIES 
        LINK_FLAGS "-undefined dynamic_lookup" #
        # SUFFIX ".so"
        # OUTPUT_NAME "nslua"
    )
	find_library(ObjC  ObjC)
	find_library(IOKit IOKit)
    find_library(CoreFoundation CoreFoundation)
    target_link_libraries(nslua 
        # ${CoreFoundation} 
        # ${IOKit} 
        ${ObjC}
    )
    
# else()
#     add_library(nslua STATIC ${NSLUA_SRCS})
# endif(BUILD_SHARED_LIB)
source_group_by_dir(${CMAKE_CURRENT_SOURCE_DIR} NSLUA_SRCS)
install_library(nslua)