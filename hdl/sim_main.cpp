//
//  Copyright 2023 Antmicro
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Modifications Copyright 2026 Ignytion IO, under the same License.
//
// Verilator main loop for the DPI co-simulation, after cpp/sim_main_dpi.cpp in
// antmicro/renode-dpi-examples.
//
// The one addition: Renode's SimulationFilePathLinux starts this executable
// with three positional arguments, "<receiver port> <sender port> <address>",
// while the IntegrationLibrary reads +RENODE_RECEIVER_PORT, +RENODE_SENDER_PORT
// and +RENODE_ADDRESS. Those are rewritten here so Renode can launch and stop
// the model itself. Plusargs given directly are passed through unchanged.

#include <string>
#include <vector>

#include <verilated.h>
#include "Vsim.h"

int main(int argc, char **argv)
{
    std::vector<std::string> args(argv, argv + argc);
    if (argc == 4 && args[1][0] != '+') {
        args = {args[0], "+RENODE_RECEIVER_PORT=" + args[1],
                "+RENODE_SENDER_PORT=" + args[2], "+RENODE_ADDRESS=" + args[3]};
    }
    std::vector<const char *> cargs;
    for (const auto &a : args) cargs.push_back(a.c_str());

    VerilatedContext *contextp = new VerilatedContext;
    contextp->commandArgs(static_cast<int>(cargs.size()), cargs.data());
    Vsim *top = new Vsim{contextp};

    while (!contextp->gotFinish()) {
        top->eval();
        if (!top->eventsPending()) break;
        contextp->time(top->nextTimeSlot());
    }

    top->final();
    delete top;
    delete contextp;
    return 0;
}
