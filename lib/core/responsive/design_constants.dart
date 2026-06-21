/// Design reference resolution and scaling constraints.
///
/// All layout dimensions in this app are authored against a 1280×720 canvas
/// (the default window size in `windows/runner/main.cpp`).  At runtime every
/// pixel value is multiplied by the current [scaleFactor] so the UI
/// proportionally grows/shrinks when the window is resized or goes fullscreen.
library;

/// Reference width used to derive the horizontal scale factor.
const double refWidth = 1280.0;

/// Reference height used to derive the vertical scale factor.
const double refHeight = 720.0;

/// Smallest allowed scale factor (prevents UI from becoming too tiny on very
/// small viewports).
const double minScale = 0.5;

/// Largest allowed scale factor (prevents UI from becoming absurdly large on
/// multi-monitor fullscreen).
const double maxScale = 3.0;
