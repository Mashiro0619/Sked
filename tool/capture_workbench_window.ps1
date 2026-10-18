param(
  [Parameter(Mandatory=$true)][int]$ProcessId,
  [ValidateSet('resize','capture','maximize','restore','snap','minimize','close-request','drag','range-drag','wheel','inspect')][string]$Action = 'capture',
  [double]$WidthDp = 1440,
  [double]$HeightDp = 900,
  [double]$PointXDp = 0,
  [double]$PointYDp = 0,
  [double]$EndPointXDp = 0,
  [double]$EndPointYDp = 0,
  [int]$WheelDelta = -120,
  [Parameter(Mandatory=$true)][double]$CaptionHeightDp,
  [Parameter(Mandatory=$true)][double]$CaptionButtonWidthDp,
  [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SkedWindowCapture {
  [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct Message {
    public IntPtr Window; public uint Id; public UIntPtr WParam; public IntPtr LParam;
    public uint Time; public Point Point; public uint Private;
  }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x,int y,int w,int z,uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int mode);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint processId);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll", SetLastError=true)] public static extern bool AttachThreadInput(uint from, uint to, bool attach);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool PeekMessage(out Message message, IntPtr window, uint first, uint last, uint remove);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);

  public static string ActivateForeground(IntPtr target, bool allowThreadAttach) {
    if (GetForegroundWindow() == target) return "already-foreground";
    bool accepted = SetForegroundWindow(target);
    System.Threading.Thread.Sleep(50);
    if (GetForegroundWindow() == target) return "direct";
    string result = accepted ? "direct-accepted-but-not-foreground" : "direct-rejected";
    // Minimize/inspect must retain their own behavior. A hidden or minimized
    // target is diagnosed here, never restored by an activation retry.
    if (!allowThreadAttach) return result + "; retry-disabled";
    if (!IsWindowVisible(target)) return result + "; target-not-visible";
    if (IsIconic(target)) return result + "; target-minimized";
    uint currentThread = GetCurrentThreadId();
    uint foregroundProcess;
    uint foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), out foregroundProcess);
    if (foregroundThread == 0 || foregroundThread == currentThread) {
      return result + "; no-distinct-foreground-thread";
    }
    Message message;
    PeekMessage(out message, IntPtr.Zero, 0, 0, 0); // Create this thread's queue without consuming input.
    bool attached = false;
    bool detachFailed = false;
    int detachError = 0;
    try {
      attached = AttachThreadInput(currentThread, foregroundThread, true);
      if (attached) {
        result = SetForegroundWindow(target)
          ? "scoped-thread-retry-accepted" : "scoped-thread-retry-rejected";
      } else {
        result += "; attach-failed:" + Marshal.GetLastWin32Error();
      }
    } finally {
      if (attached && !AttachThreadInput(currentThread, foregroundThread, false)) {
        detachFailed = true;
        detachError = Marshal.GetLastWin32Error();
      }
    }
    if (detachFailed) {
      throw new InvalidOperationException("Temporary input attachment could not be removed: " + detachError);
    }
    return result;
  }
}
'@
[void][SkedWindowCapture]::SetThreadDpiAwarenessContext([IntPtr](-4))
$process = Get-Process -Id $ProcessId
$handle = $process.MainWindowHandle
if ($handle -eq [IntPtr]::Zero) { throw 'The test process has no native main window.' }
[uint32]$windowOwner = 0
$windowThread = [SkedWindowCapture]::GetWindowThreadProcessId($handle,[ref]$windowOwner)
if ($windowThread -eq 0 -or $windowOwner -ne $ProcessId) { throw 'The native main window no longer belongs to the target test process.' }
$dpi = [SkedWindowCapture]::GetDpiForWindow($handle)
$scale = $dpi / 96.0
$screen = [System.Windows.Forms.Screen]::FromHandle($handle)
if ($Action -eq 'resize') {
  [void][SkedWindowCapture]::ShowWindow($handle,9)
  $w = [Math]::Min([int]($WidthDp*$scale),$screen.WorkingArea.Width-16)
  $h = [Math]::Min([int]($HeightDp*$scale),$screen.WorkingArea.Height-16)
  [void][SkedWindowCapture]::SetWindowPos($handle,[IntPtr]::Zero,$screen.WorkingArea.Left+8,$screen.WorkingArea.Top+8,$w,$h,0x0040)
} elseif ($Action -eq 'maximize') { [void][SkedWindowCapture]::ShowWindow($handle,3) }
elseif ($Action -eq 'restore') { [void][SkedWindowCapture]::ShowWindow($handle,9) }
elseif ($Action -eq 'minimize') { [void][SkedWindowCapture]::ShowWindow($handle,6) }
$activationResult = 'not-requested'
if ($Action -ne 'inspect') {
  $activationResult = [SkedWindowCapture]::ActivateForeground($handle,($Action -ne 'minimize'))
}
if ($Action -eq 'close-request') { [void][SkedWindowCapture]::PostMessage($handle,0x10,[IntPtr]::Zero,[IntPtr]::Zero) }
Start-Sleep -Milliseconds 250
$activationSucceeded = [SkedWindowCapture]::GetForegroundWindow() -eq $handle
$activationDetails = "activation=$activationResult; foregroundAfterRequest=$activationSucceeded; targetVisible=$([SkedWindowCapture]::IsWindowVisible($handle))"
$r = New-Object SkedWindowCapture+Rect
$c = New-Object SkedWindowCapture+Rect
$p = New-Object SkedWindowCapture+Point
[void][SkedWindowCapture]::GetWindowRect($handle,[ref]$r)
[void][SkedWindowCapture]::GetClientRect($handle,[ref]$c)
[void][SkedWindowCapture]::ClientToScreen($handle,[ref]$p)
$movedX = 0; $movedY = 0
if ($Action -in @('drag', 'range-drag', 'wheel')) {
  if (([SkedWindowCapture]::GetAsyncKeyState(1) -band 0x8000) -ne 0) { throw 'The primary mouse button is already down; refusing to interfere with another gesture.' }
  if ([SkedWindowCapture]::GetForegroundWindow() -ne $handle) { throw "Native pointer validation requires the test window to own foreground focus. $activationDetails" }
  if ($PointXDp -le 0 -or $PointYDp -le 0) { throw 'Pointer validation requires a verified point inside the test window.' }
  $from = New-Object SkedWindowCapture+Point
  $from.X = $p.X + [int]($PointXDp*$scale); $from.Y = $p.Y + [int]($PointYDp*$scale)
  if ([SkedWindowCapture]::GetAncestor([SkedWindowCapture]::WindowFromPoint($from),2) -ne $handle) { throw 'Pointer point is outside the test window.' }
  $to = New-Object SkedWindowCapture+Point
  $to.X = $from.X + 80; $to.Y = $from.Y + 40
  if ($Action -eq 'range-drag') {
    if ($EndPointXDp -le 0 -or $EndPointYDp -le 0) { throw 'Range drag requires an end point.' }
    $to.X = $p.X + [int]($EndPointXDp*$scale); $to.Y = $p.Y + [int]($EndPointYDp*$scale)
    if ([SkedWindowCapture]::GetAncestor([SkedWindowCapture]::WindowFromPoint($to),2) -ne $handle) { throw 'Range end point is outside the test window.' }
  }
  $savedCursor = New-Object SkedWindowCapture+Point
  [void][SkedWindowCapture]::GetCursorPos([ref]$savedCursor)
  try {
    [void][SkedWindowCapture]::SetCursorPos($from.X,$from.Y)
    if ($Action -eq 'wheel') {
      $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$WheelDelta),0)
      [SkedWindowCapture]::mouse_event(0x0800,0,0,$bits,[UIntPtr]::Zero)
      Start-Sleep -Milliseconds 400
    } else {
      [SkedWindowCapture]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
      try {
        Start-Sleep -Milliseconds 100
        for ($step=1; $step -le 8; $step++) {
          [void][SkedWindowCapture]::SetCursorPos([int]($from.X+($to.X-$from.X)*$step/8),[int]($from.Y+($to.Y-$from.Y)*$step/8))
          Start-Sleep -Milliseconds 70
        }
      } finally { [SkedWindowCapture]::mouse_event(4,0,0,0,[UIntPtr]::Zero) }
    }
  } finally { [void][SkedWindowCapture]::SetCursorPos($savedCursor.X,$savedCursor.Y) }
  Start-Sleep -Milliseconds 250
  $moved = New-Object SkedWindowCapture+Rect
  [void][SkedWindowCapture]::GetWindowRect($handle,[ref]$moved)
  $movedX = $moved.Left - $r.Left; $movedY = $moved.Top - $r.Top
}
$mx = $p.X + ($c.Right-$c.Left) - [int](1.5*$CaptionButtonWidthDp*$scale)
$my = $p.Y + [int]($CaptionHeightDp*$scale/2)
$lparam = [IntPtr](($my -shl 16) -bor ($mx -band 0xffff))
$hit = [SkedWindowCapture]::SendMessage($handle,0x84,[IntPtr]::Zero,$lparam).ToInt32()
$hover = New-Object SkedWindowCapture+Point
$hover.X = $mx; $hover.Y = $my
$pointWindow = [SkedWindowCapture]::WindowFromPoint($hover)
$pointRoot = [SkedWindowCapture]::GetAncestor($pointWindow,2)
if ($Action -eq 'snap') {
  if ($pointRoot -ne $handle) { throw 'The maximize region is occluded by another window; refusing unrelated pointer input.' }
  [void][SkedWindowCapture]::SetCursorPos($p.X+20,$p.Y+150)
  Start-Sleep -Milliseconds 150
  [void][SkedWindowCapture]::SetCursorPos($mx,$my)
  Start-Sleep -Milliseconds 1400
}
if ($Action -eq 'capture' -or $Action -eq 'snap') {
  # Never record an unrelated window if the user changes focus during the run.
  foreach ($offset in @(@(16,16),@(($r.Right-$r.Left-17),16),@(16,($r.Bottom-$r.Top-17)),@(($r.Right-$r.Left-17),($r.Bottom-$r.Top-17)),@([int](($r.Right-$r.Left)/2),[int](($r.Bottom-$r.Top)/2)))) {
    $sample = New-Object SkedWindowCapture+Point
    $sample.X = $r.Left + $offset[0]; $sample.Y = $r.Top + $offset[1]
    $rootWindow = [SkedWindowCapture]::GetAncestor([SkedWindowCapture]::WindowFromPoint($sample),2)
    if ($rootWindow -ne $handle) { throw "The test window is occluded; refusing to capture unrelated desktop content. $activationDetails" }
  }
  if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'Capture requires OutputPath.' }
  $absolute = [System.IO.Path]::GetFullPath($OutputPath)
  [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($absolute))
  $bitmap = New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($r.Left,$r.Top,0,0,$bitmap.Size)
    $bitmap.Save($absolute,[System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
  if ($Action -eq 'snap') { [void][SkedWindowCapture]::SetCursorPos($p.X+20,$p.Y+150); Start-Sleep -Milliseconds 350 }
}
$finalForeground = [SkedWindowCapture]::GetForegroundWindow()
[uint32]$foregroundOwner = 0
[void][SkedWindowCapture]::GetWindowThreadProcessId($finalForeground,[ref]$foregroundOwner)
@{dpi=$dpi;clientWidthDp=($c.Right-$c.Left)/$scale;clientHeightDp=($c.Bottom-$c.Top)/$scale;clientTopInsetPx=$p.Y-$r.Top;maximizeHit=$hit;foregroundIsApp=($finalForeground -eq $handle);foregroundIsTargetProcess=($foregroundOwner -eq $ProcessId);targetVisible=[SkedWindowCapture]::IsWindowVisible($handle);activationResult=$activationResult;activationSucceeded=$activationSucceeded;hoverRootIsApp=($pointRoot -eq $handle);minimized=[SkedWindowCapture]::IsIconic($handle);maximized=[SkedWindowCapture]::IsZoomed($handle);movedX=$movedX;movedY=$movedY;action=$Action;file=$OutputPath} | ConvertTo-Json -Compress
