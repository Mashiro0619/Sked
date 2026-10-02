param(
  [Parameter(Mandatory=$true)][int]$ProcessId,
  [ValidateSet('inspect','move','click','drag','restore')][string]$Action = 'inspect',
  [double]$X = 0, [double]$Y = 0, [double]$EndX = 0, [double]$EndY = 0,
  [int]$SavedX = 0, [int]$SavedY = 0
)
$ErrorActionPreference = 'Stop'
# Test-only actions against verified client points. Move deliberately retains
# the pointer for the next assertion; the caller restores the captured cursor
# in its finally block. No arbitrary shell commands or disabled safety checks.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ReminderPointer {
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
  [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
}
'@
[void][ReminderPointer]::SetThreadDpiAwarenessContext([IntPtr](-4))
$handle = (Get-Process -Id $ProcessId).MainWindowHandle
if ($handle -eq [IntPtr]::Zero) { throw 'Test process has no main window.' }
function Require-Target([double]$x, [double]$y, [bool]$buttonOwned = $false) {
  if ([ReminderPointer]::GetForegroundWindow() -ne $handle) { throw 'Test window must own foreground focus.' }
  if (!$buttonOwned -and (([ReminderPointer]::GetAsyncKeyState(1) -band 0x8000) -ne 0)) { throw 'Primary mouse button is already down.' }
  if ($x -le 0 -or $y -le 0) { throw 'Expected a verified client point.' }
  $origin = New-Object ReminderPointer+Point
  [void][ReminderPointer]::ClientToScreen($handle, [ref]$origin)
  $scale = [ReminderPointer]::GetDpiForWindow($handle) / 96.0
  $point = New-Object ReminderPointer+Point
  $point.X = $origin.X + [int]($x*$scale); $point.Y = $origin.Y + [int]($y*$scale)
  if ([ReminderPointer]::GetAncestor([ReminderPointer]::WindowFromPoint($point),2) -ne $handle) { throw 'Target point is outside or occluded by another window.' }
  return $point
}
try {
  if ($Action -eq 'inspect') {
    $saved = New-Object ReminderPointer+Point
    [void][ReminderPointer]::GetCursorPos([ref]$saved)
    @{status='ok'; action=$Action; savedX=$saved.X; savedY=$saved.Y} | ConvertTo-Json -Compress
    exit 0
  }
  if ($Action -eq 'restore') {
    [void][ReminderPointer]::SetCursorPos($SavedX,$SavedY)
    @{status='ok'; action=$Action} | ConvertTo-Json -Compress
    exit 0
  }
  $from = Require-Target $X $Y
  [void][ReminderPointer]::SetCursorPos($from.X,$from.Y)
  if ($Action -eq 'click') {
    [void](Require-Target $X $Y)
    [ReminderPointer]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    try { Start-Sleep -Milliseconds 60 } finally { [ReminderPointer]::mouse_event(4,0,0,0,[UIntPtr]::Zero) }
  } elseif ($Action -eq 'drag') {
    [void](Require-Target $EndX $EndY)
    [ReminderPointer]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    try {
      for ($step=1; $step -le 10; $step++) {
        $nextX = $X + ($EndX-$X)*$step/10
        $nextY = $Y + ($EndY-$Y)*$step/10
        $next = Require-Target $nextX $nextY $true
        [void][ReminderPointer]::SetCursorPos($next.X,$next.Y)
        Start-Sleep -Milliseconds 60
      }
    } finally { [ReminderPointer]::mouse_event(4,0,0,0,[UIntPtr]::Zero) }
  }
  @{status='ok'; action=$Action; clientX=$X; clientY=$Y; screenX=$from.X; screenY=$from.Y; dpi=[ReminderPointer]::GetDpiForWindow($handle)} | ConvertTo-Json -Compress
} catch {
  @{status='blocked'; reason=$_.Exception.Message; action=$Action} | ConvertTo-Json -Compress
  exit 1
}
