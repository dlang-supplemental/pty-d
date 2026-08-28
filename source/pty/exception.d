/++
	Exception type for PTY / ConPTY failures.
+/
module pty.exception;

/// Thrown when a PTY host operation fails.
class PtyException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
	{
		super(msg, file, line, next);
	}
}