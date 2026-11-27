#pragma once

// Renderer -> browser process: whether a frame is playing sound, for the
// speaker on its tab. Shared with the helper executable, so no Qt in here.
namespace PageMediaProtocol
{
// argument 0: bool, the frame now has audible media
inline constexpr char kMessage[] = "illuminate.media";
}
