/++
	Shared PTY size and flag types.
+/
module pty.types;

/// Terminal grid size in character cells.
struct PtySize
{
	/// Column count (width).
	ushort cols = 80;
	/// Row count (height).
	ushort rows = 24;

	/// True when both dimensions are non-zero.
	bool valid() const @safe pure nothrow @nogc
	{
		return cols > 0 && rows > 0;
	}
}

/// Options for opening a PTY.
struct PtyOpenOptions
{
	/// Initial size.
	PtySize size = PtySize(80, 24);

	version (Windows)
	{
		/// Passed to CreatePseudoConsole (PSEUDOCONSOLE_INHERIT_CURSOR = 1).
		uint flags = 0;
	}
}