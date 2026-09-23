cmake_minimum_required(VERSION 3.20)

project(oj_problem_companion LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(oj_companion_database STATIC
  src/browser_import.cpp
  src/problem_database.cpp
  src/sqlite_api.cpp
)
target_include_directories(oj_companion_database PUBLIC src)
target_compile_definitions(oj_companion_database PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)

add_executable(oj_problem_companion WIN32
  resources/app.rc
  src/main.cpp
)
target_include_directories(oj_problem_companion PRIVATE resources)
target_compile_definitions(oj_problem_companion PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(oj_problem_companion PRIVATE
  oj_companion_database
  comctl32
  ole32
  shell32
  ws2_32
)

add_executable(oj_companion_tests
  tests/problem_database_test.cpp
)
target_compile_definitions(oj_companion_tests PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(oj_companion_tests PRIVATE
  oj_companion_database
  ole32
  ws2_32
)

if(MSVC)
  target_compile_options(oj_companion_database PRIVATE /W4 /permissive- /utf-8)
  target_compile_options(oj_problem_companion PRIVATE /W4 /permissive- /utf-8)
  target_compile_options(oj_companion_tests PRIVATE /W4 /permissive- /utf-8)
else()
  target_compile_options(oj_companion_database PRIVATE -Wall -Wextra -Wpedantic)
  target_compile_options(oj_problem_companion PRIVATE -Wall -Wextra -Wpedantic)
  target_compile_options(oj_companion_tests PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(DEFINED OJ_SQLITE_DLL AND EXISTS "${OJ_SQLITE_DLL}")
  foreach(target oj_problem_companion oj_companion_tests)
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${OJ_SQLITE_DLL}"
        "$<TARGET_FILE_DIR:${target}>/sqlite3.dll"
    )
  endforeach()
endif()

enable_testing()
add_test(NAME oj_companion_database COMMAND oj_companion_tests)
