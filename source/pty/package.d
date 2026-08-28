/++
	Portable PTY host bindings for D.

	Windows: ConPTY (CreatePseudoConsole / ResizePseudoConsole /
	ClosePseudoConsole) plus a small RAII wrapper.

	POSIX: posix_openpt / grantpt / unlockpt / ptsname plus
	TIOCSWINSZ resize.

	This package does not implement VT parsing or a terminal emulator —
	FFI and a thin safe API only.
+/
module pty;

public import pty.types;
public import pty.exception;

version (Windows)
{
	public import pty.windows;
	public import pty.windows_conpty;
}

version (Posix)
{
	public import pty.posix;
}

import std.string : strip;

/// Library SemVer from the VERSION file (string import).
enum string ptyVersion = import("VERSION").strip;

unittest
{
	assert(ptyVersion.length > 0);
	assert(ptyVersion[0] >= '0' && ptyVersion[0] <= '9');
}