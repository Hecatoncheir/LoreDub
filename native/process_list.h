// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <string>

// Every process whose image this user may read, as a JSON array of
// {pid, name, path, startedAt} -- the list the game is picked from.
std::string ListProcesses();
