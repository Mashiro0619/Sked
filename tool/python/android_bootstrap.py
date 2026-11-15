"""Run one approved task in the dedicated Chaquopy service process."""

import atexit
import ctypes
import io
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
import threading
import time
import traceback


def _standard_stream(fd, errors):
    return io.TextIOWrapper(
        io.FileIO(fd, "w", closefd=False),
        encoding="utf-8",
        errors=errors,
        write_through=True,
    )


def _system_exit_code(value, stderr, output_failures):
    if value is None:
        return 0
    if isinstance(value, int):
        # CPython converts through C long; Android exposes the low eight bits.
        if value < -sys.maxsize - 1 or value > sys.maxsize:
            return 255
        return value & 255
    try:
        print(value, file=stderr)
    except BaseException as error:
        output_failures.append(f"stderr: {error}")
    return 1


def _report_exception(error, stderr, output_failures):
    try:
        traceback.print_exception(error, file=stderr)
    except BaseException as write_error:
        output_failures.append(f"stderr: {write_error}")


def _flush_outputs(stdout, stderr):
    failures = []
    seen = set()
    for name, stream in (
        ("stdout", sys.stdout),
        ("stderr", sys.stderr),
        ("stdout", stdout),
        ("stderr", stderr),
    ):
        if stream is None or id(stream) in seen:
            continue
        seen.add(id(stream))
        try:
            if not getattr(stream, "closed", False):
                stream.flush()
        except BaseException as error:
            failures.append(f"{name}: {error}")

    # Native extensions may still have data in libc's FILE buffers.
    libc = ctypes.CDLL(None, use_errno=True)
    fflush = libc.fflush
    fflush.argtypes = [ctypes.c_void_p]
    fflush.restype = ctypes.c_int
    if fflush(None) != 0:
        failures.append(f"native output: {os.strerror(ctypes.get_errno())}")
    for fd, name in ((1, "stdout"), (2, "stderr")):
        try:
            os.fsync(fd)
        except OSError as error:
            failures.append(f"{name}: {error}")
    return "\n".join(failures) if failures else None


def _write_terminal(run_directory, terminal):
    temporary = run_directory / "terminal.json.tmp"
    with temporary.open("x", encoding="utf-8", newline="\n") as target:
        json.dump(terminal, target, ensure_ascii=False, separators=(",", ":"))
        target.write("\n")
        target.flush()
        os.fsync(target.fileno())
    os.replace(temporary, run_directory / "terminal.json")
    directory_fd = os.open(run_directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def run(run_directory, cwd_fd):
    """Finish Python cleanup and persist the result before reporting completion."""
    run_directory = Path(run_directory)
    stdout = _standard_stream(1, "surrogateescape")
    stderr = _standard_stream(2, "backslashreplace")
    sys.stdout = sys.__stdout__ = stdout
    sys.stderr = sys.__stderr__ = stderr
    invocation = json.loads((run_directory / "invocation.json").read_text("utf-8"))
    exit_code = 0
    output_failures = []
    try:
        os.environ.clear()
        os.environ.update(invocation["environment"])
        os.environ["_SKED_EXECUTION_DIR"] = str(run_directory)
        tempfile.tempdir = None
        # Kotlin owns this descriptor throughout the call.
        os.fchdir(cwd_fd)
        import sked_runtime

        source = run_directory / "source.py"
        sys.argv = [str(source), *invocation["argv"]]
        if not invocation.get("controlledReader", False):
            sys.path.insert(0, os.getcwd())
        runpy.run_path(str(source), run_name="__main__")
    except SystemExit as error:
        exit_code = _system_exit_code(error.code, stderr, output_failures)
    except BaseException as error:
        exit_code = 130 if isinstance(error, KeyboardInterrupt) else 1
        _report_exception(error, stderr, output_failures)

    # Match CPython's shutdown order without finalizing the embedded VM.
    for shutdown in (threading._shutdown, atexit._run_exitfuncs):
        try:
            shutdown()
        except BaseException as error:
            _report_exception(error, stderr, output_failures)
    output_error = _flush_outputs(stdout, stderr)
    if output_error is not None:
        exit_code = 120
        output_failures.append(output_error)
    terminal = {
        "identity": invocation["identity"],
        "exitCode": exit_code,
        "finishedAtMs": time.time_ns() // 1_000_000,
    }
    if output_failures:
        terminal["outputError"] = "\n".join(output_failures)
    _write_terminal(run_directory, terminal)
    return exit_code
