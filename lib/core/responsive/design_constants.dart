/// 设计参考分辨率和缩放约束。
///
/// 应用中的布局尺寸以 1280×720 画布为基准（Windows runner 的默认窗口大小）。
/// 运行时每个像素值都会乘以当前 [scaleFactor]，让 UI 随窗口大小和全屏状态等比例缩放。
library;

/// 用于派生水平缩放因子的参考宽度。
const double refWidth = 1280.0;

/// 用于派生垂直缩放因子的参考高度。
const double refHeight = 720.0;

/// 桌面窗口允许的最窄宽高比（3:2）。
const double minDesktopAspectRatio = 3 / 2;

/// 桌面窗口允许的最宽宽高比（16:9）。
const double maxDesktopAspectRatio = 16 / 9;

/// 最大化工作区因任务栏导致的轻微超宽容差。
///
/// 仅用于画布填满，不改变用户拖动窗口时的 16:9 比例限位。
const double desktopWorkAreaAspectTolerance = 0.08;

/// Windows 应用内标题栏的逻辑高度。
const double desktopTitleBarHeight = 36.0;

/// 最小允许缩放因子，避免 UI 在很小的视口中过度缩小。
const double minScale = 0.5;

/// 最大允许缩放因子，避免多显示器全屏时 UI 过度放大。
const double maxScale = 3.0;
