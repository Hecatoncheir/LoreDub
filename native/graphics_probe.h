// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <string>

// The machine's real graphics adapters and whether the CUDA driver and the
// Vulkan loader are installed, as the JSON `ComputeAvailability` is read
// from.
std::string ProbeGraphics();

// Every monitor where the virtual screen puts it, as a JSON array of
// {left, top, right, bottom, primary} in physical pixels.
std::string ListMonitors();
