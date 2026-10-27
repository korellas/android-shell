cmake_minimum_required(VERSION 3.22.1)

project(ConnectBot)

find_library(log-lib log)

add_library(com_google_ase_Exec SHARED "src/main/cpp/com_google_ase_Exec.cpp")
target_link_options(com_google_ase_Exec PRIVATE "-Wl,-z,max-page-size=16384")
target_link_libraries(com_google_ase_Exec ${log-lib})
