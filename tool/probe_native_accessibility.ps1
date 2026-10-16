param(
  [Parameter(Mandatory = $true)]
  [int]$TargetProcessId,
  [string]$ExpectedText = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ($TargetProcessId -le 0) { throw 'A concrete test runner process is required.' }
Add-Type -AssemblyName Accessibility

# Flutter's default Windows embedder exposes OBJID_CLIENT/MSAA. Its direct UIA
# provider is compile-time gated; a UIA Pane is not evidence of app controls.
$source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using Accessibility;

namespace Sked.NativeAcceptance {
  public sealed class MsaaRoot {
    public string hwnd;
    public string className;
    public string hresult;
    public bool providerAvailable;
    public int accessibleNodes;
    public int nativeButtons;
    public int matchedExpectedText;
    public int matchedEditableValues;
    public int unavailableElements;
    public int unavailableProperties;
    public int duplicateReferences;
    public readonly List<Dictionary<string, object>> matches =
        new List<Dictionary<string, object>>();
  }

  public sealed class MsaaResult {
    public string nativeApi = "MSAA";
    public string rootScope = "target-PID FlutterView children";
    public int processId;
    public string windowName;
    public string mainWindowHandle;
    public string expectedText;
    public int descendants;
    public int accessibleNodes;
    public int nativeButtons;
    public int matchedExpectedText;
    public int matchedEditableValues;
    public int unavailableElements;
    public int unavailableProperties;
    public readonly List<MsaaRoot> roots = new List<MsaaRoot>();
  }

  public static class MsaaProbe {
    private const uint ObjIdClient = unchecked((uint)-4);
    private const int MaxNodes = 20000;
    private const int MaxDepth = 128;
    private delegate bool EnumWindowProc(IntPtr hwnd, IntPtr parameter);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumChildWindows(
        IntPtr parent, EnumWindowProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
        IntPtr hwnd, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(
        IntPtr hwnd, StringBuilder name, int maximum);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleObjectFromWindow(
        IntPtr hwnd, uint objectId, ref Guid interfaceId,
        [MarshalAs(UnmanagedType.Interface)] out IAccessible accessible);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleChildren(
        [In, MarshalAs(UnmanagedType.Interface)] IAccessible container,
        int firstChild, int requested,
        [Out, MarshalAs(UnmanagedType.LPArray,
          ArraySubType = UnmanagedType.Struct, SizeParamIndex = 2)] object[] children,
        out int obtained);

    private static bool BelongsTo(IntPtr hwnd, int processId) {
      uint actual;
      GetWindowThreadProcessId(hwnd, out actual);
      return actual == (uint)processId;
    }

    private static string WindowClass(IntPtr hwnd) {
      var name = new StringBuilder(256);
      GetClassName(hwnd, name, name.Capacity);
      return name.ToString();
    }

    private static string HandleName(IntPtr hwnd) {
      return "0x" + hwnd.ToInt64().ToString("X", CultureInfo.InvariantCulture);
    }

    private static string Identity(IAccessible accessible, int childId) {
      IntPtr unknown = Marshal.GetIUnknownForObject(accessible);
      try {
        return unknown.ToInt64().ToString(CultureInfo.InvariantCulture) +
            ":" + childId.ToString(CultureInfo.InvariantCulture);
      } finally {
        Marshal.Release(unknown);
      }
    }

    private static string ReadString(Func<string> getter, MsaaRoot result) {
      try { return getter() ?? String.Empty; }
      catch (Exception error) {
        if (!(error is COMException) && !(error is NotImplementedException) &&
            !(error is ArgumentException) && !(error is InvalidCastException)) {
          throw;
        }
        result.unavailableProperties++;
        return String.Empty;
      }
    }

    private static bool Contains(string value, string expected) {
      return expected.Length > 0 &&
          value.IndexOf(expected, StringComparison.Ordinal) >= 0;
    }

    private static void Visit(
        IAccessible accessible, int childId, string expected,
        MsaaRoot result, HashSet<string> visited, int depth) {
      if (depth > MaxDepth || result.accessibleNodes >= MaxNodes) {
        throw new InvalidOperationException("Native MSAA traversal exceeded its bound.");
      }
      if (!visited.Add(Identity(accessible, childId))) {
        result.duplicateReferences++;
        return;
      }
      object roleValue;
      try { roleValue = accessible.get_accRole(childId); }
      catch (COMException) {
        result.unavailableElements++;
        return;
      }
      int role;
      try { role = Convert.ToInt32(roleValue, CultureInfo.InvariantCulture); }
      catch (FormatException) { role = -1; }
      catch (InvalidCastException) { role = -1; }

      string name = ReadString(() => accessible.get_accName(childId), result);
      string value = ReadString(() => accessible.get_accValue(childId), result);
      result.accessibleNodes++;
      // ROLE_SYSTEM_PUSHBUTTON and the standard dropdown/menu/split variants.
      if (role == 43 || role == 56 || role == 57 || role == 58 || role == 62) {
        result.nativeButtons++;
      }
      bool nameMatch = Contains(name, expected);
      bool valueMatch = Contains(value, expected);
      if (nameMatch || valueMatch) {
        result.matchedExpectedText++;
        // Require the exact ROLE_SYSTEM_TEXT value, not a matching title label.
        if (role == 42 && String.Equals(value, expected, StringComparison.Ordinal)) {
          result.matchedEditableValues++;
        }
        if (result.matches.Count < 8) {
          result.matches.Add(new Dictionary<string, object> {
            { "role", role },
            { "nameMatched", nameMatch },
            { "valueMatched", valueMatch },
            { "name", name.Length > 160 ? name.Substring(0, 160) : name },
            { "value", value.Length > 160 ? value.Substring(0, 160) : value }
          });
        }
      }
      // Integer child IDs represent simple leaves owned by this IAccessible.
      if (childId != 0) return;
      int count;
      try { count = accessible.accChildCount; }
      catch (COMException) {
        result.unavailableElements++;
        return;
      }
      if (count < 0 || count > MaxNodes) {
        throw new InvalidOperationException("Invalid native MSAA child count.");
      }
      for (int start = 0; start < count;) {
        int requested = Math.Min(256, count - start);
        var children = new object[requested];
        int obtained;
        int status = AccessibleChildren(
            accessible, start, requested, children, out obtained);
        if (status < 0) Marshal.ThrowExceptionForHR(status);
        if (obtained <= 0) break;
        for (int index = 0; index < obtained; index++) {
          var nested = children[index] as IAccessible;
          if (nested != null) {
            Visit(nested, 0, expected, result, visited, depth + 1);
          } else if (children[index] is int) {
            int nestedId = (int)children[index];
            object fullChild = null;
            try { fullChild = accessible.get_accChild(nestedId); }
            catch (COMException) { }
            catch (ArgumentException) { }
            catch (NotImplementedException) { }
            nested = fullChild as IAccessible;
            if (nested != null) {
              Visit(nested, 0, expected, result, visited, depth + 1);
            } else {
              Visit(accessible, nestedId, expected, result, visited, depth + 1);
            }
          } else if (children[index] != null) {
            result.unavailableElements++;
          }
        }
        start += obtained;
      }
    }

    public static MsaaResult Read(int processId, string expected) {
      expected = expected ?? String.Empty;
      var process = Process.GetProcessById(processId);
      process.Refresh();
      IntPtr main = process.MainWindowHandle;
      if (main == IntPtr.Zero || !BelongsTo(main, processId)) {
        throw new InvalidOperationException("The target PID has no matching main window.");
      }
      var handles = new List<IntPtr>();
      EnumWindowProc callback = delegate(IntPtr hwnd, IntPtr parameter) {
        if (BelongsTo(hwnd, processId) &&
            String.Equals(WindowClass(hwnd), "FLUTTERVIEW", StringComparison.Ordinal)) {
          handles.Add(hwnd);
        }
        return true;
      };
      EnumChildWindows(main, callback, IntPtr.Zero);
      GC.KeepAlive(callback);
      if (handles.Count == 0) {
        throw new InvalidOperationException("The target main window has no same-PID FlutterView child.");
      }
      var result = new MsaaResult {
        processId = processId,
        windowName = process.MainWindowTitle,
        mainWindowHandle = HandleName(main),
        expectedText = expected
      };
      foreach (IntPtr hwnd in handles) {
        // Revalidate ownership immediately before requesting a COM provider.
        if (!BelongsTo(hwnd, processId)) {
          throw new InvalidOperationException("A FlutterView changed process owner.");
        }
        var root = new MsaaRoot {
          hwnd = HandleName(hwnd),
          className = WindowClass(hwnd)
        };
        Guid interfaceId = new Guid("618736E0-3C3D-11CF-810C-00AA00389B71");
        IAccessible accessible;
        int status = AccessibleObjectFromWindow(
            hwnd, ObjIdClient, ref interfaceId, out accessible);
        root.hresult = "0x" + status.ToString("X8", CultureInfo.InvariantCulture);
        root.providerAvailable = status >= 0 && accessible != null;
        // The initial empty-tree request activates native semantics. A provider
        // may not be ready yet; the later populated controls gate requires it.
        if (root.providerAvailable) {
          Visit(accessible, 0, expected, root, new HashSet<string>(), 0);
        }
        result.roots.Add(root);
        result.accessibleNodes += root.accessibleNodes;
        result.descendants += Math.Max(0, root.accessibleNodes - 1);
        result.nativeButtons += root.nativeButtons;
        result.matchedExpectedText += root.matchedExpectedText;
        result.matchedEditableValues += root.matchedEditableValues;
        result.unavailableElements += root.unavailableElements;
        result.unavailableProperties += root.unavailableProperties;
      }
      process.Dispose();
      return result;
    }
  }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies @(
  [Accessibility.IAccessible].Assembly.Location,
  [System.Diagnostics.Process].Assembly.Location,
  [System.Linq.Enumerable].Assembly.Location
)

# No desktop enumeration, UI actions, or arbitrary native-tree dump.
[Sked.NativeAcceptance.MsaaProbe]::Read($TargetProcessId, $ExpectedText) |
  ConvertTo-Json -Depth 8 -Compress
