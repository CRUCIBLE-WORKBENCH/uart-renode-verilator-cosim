# Verilate hdl/sim.sv, the upstream Apb3UartCtrl.v and Renode's DPI
# IntegrationLibrary into one executable, output/apb3uart/verilated.
#   cmake -S hdl -B output/apb3uart -DUSER_RENODE_DIR=<renode dir> -DUART_RTL=<Apb3UartCtrl.v>
# Verilator is found through VERILATOR_ROOT (scripts/build.sh sets it).
#
# The IntegrationLibrary modules are listed as sources. Upstream's recipe finds
# them through Verilator's -y search instead, and Verilator 5.047 and 5.052 then
# drop the file-scope `import renode_pkg::...` lines of the auto-loaded files.
cmake_minimum_required(VERSION 3.19)  # floor of Verilator's own verilator-config.cmake
project(apb3uart_cosim CXX)
if(POLICY CMP0144)
  cmake_policy(SET CMP0144 NEW)  # let find_package use VERILATOR_ROOT
endif()

set(COLIB ${USER_RENODE_DIR}/plugins/IntegrationLibrary)
foreach(required ${COLIB}/hdl/renode_pkg.sv ${COLIB}/src/renode_dpi.cpp ${UART_RTL})
  if(NOT EXISTS ${required})
    message(FATAL_ERROR "missing ${required}")
  endif()
endforeach()

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

file(GLOB COLIB_IMPORTS ${COLIB}/hdl/imports/*.sv)
file(GLOB COLIB_MODULES ${COLIB}/hdl/modules/*.sv ${COLIB}/hdl/modules/apb3/*.sv)
file(GLOB_RECURSE COLIB_SOCKET ${COLIB}/libs/socket-cpp/*.cpp)

add_executable(verilated
  ${CMAKE_CURRENT_SOURCE_DIR}/sim_main.cpp
  ${COLIB_SOCKET}
  ${COLIB}/src/communication/socket_channel.cpp
  ${COLIB}/src/renode_dpi.cpp)
target_include_directories(verilated PRIVATE ${COLIB})
# Renode starts the model with its own LD_LIBRARY_PATH, which puts Renode's
# bundled libstdc++ ahead of the host's. A model linked against a newer host
# libstdc++ then fails to start (GLIBCXX_3.4.32 not found). Upstream's recipe
# links the C++ runtime statically for the same reason.
target_link_options(verilated PRIVATE -static-libstdc++ -static-libgcc)

verilate(verilated
  TRACE
  TOP_MODULE sim
  PREFIX Vsim
  SOURCES ${COLIB}/hdl/renode_pkg.sv ${COLIB_IMPORTS} ${COLIB_MODULES}
          ${UART_RTL} ${CMAKE_CURRENT_SOURCE_DIR}/sim.sv
  INCLUDE_DIRS ${COLIB}/hdl/includes
  VERILATOR_ARGS --timing --assert)
