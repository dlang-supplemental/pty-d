/++
	Windows ConPTY host wrapper — pipe setup + RAII around HPCON.

	Does not spawn a child process. Callers attach the ConPTY via
	PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE (see attributePseudoConsole) when
	creating the process.
+/
module pty.windows;

version (Windows):

import core.sys.windows.windows;
import std.format : format;
import std.exception : enforce;

import pty.exception;
import pty.types;
import pty.windows_conpty;

/// Host-side ConPTY with duplex anonymous pipes.
final class ConPty
{
	private HPCON _hpc;
	private HANDLE _inputWrite; /// Host writes -> ConPTY input
	private HANDLE _outputRead; /// Host reads <- ConPTY output
	private bool _closed;

	private this(HPCON hpc, HANDLE inputWrite, HANDLE outputRead) @safe pure nothrow @nogc
	{
		_hpc = hpc;
		_inputWrite = inputWrite;
		_outputRead = outputRead;
	}

	/// Open a ConPTY of the given size.
	static ConPty open(PtyOpenOptions opts = PtyOpenOptions.init)
	{
		enforce!PtyException(opts.size.valid, "PtySize must have non-zero cols and rows");
		enforce!PtyException(conptyAvailable(), "ConPTY APIs not found in kernel32 (need Windows 10 1809+)");

		HANDLE pipePTYIn, pipeIn;
		HANDLE pipeOut, pipePTYOut;

		SECURITY_ATTRIBUTES sa;
		sa.nLength = SECURITY_ATTRIBUTES.sizeof;
		sa.bInheritHandle = TRUE;

		if (!CreatePipe(&pipePTYIn, &pipeIn, &sa, 0))
			throw new PtyException(format("CreatePipe (input) failed: %s", GetLastError()));
		if (!CreatePipe(&pipeOut, &pipePTYOut, &sa, 0))
		{
			CloseHandle(pipePTYIn);
			CloseHandle(pipeIn);
			throw new PtyException(format("CreatePipe (output) failed: %s", GetLastError()));
		}

		if (!SetHandleInformation(pipeIn, HANDLE_FLAG_INHERIT, 0))
		{
			closePair(pipePTYIn, pipeIn);
			closePair(pipeOut, pipePTYOut);
			throw new PtyException(format("SetHandleInformation (input) failed: %s", GetLastError()));
		}
		if (!SetHandleInformation(pipeOut, HANDLE_FLAG_INHERIT, 0))
		{
			closePair(pipePTYIn, pipeIn);
			closePair(pipeOut, pipePTYOut);
			throw new PtyException(format("SetHandleInformation (output) failed: %s", GetLastError()));
		}

		COORD size;
		size.X = cast(short) opts.size.cols;
		size.Y = cast(short) opts.size.rows;

		HPCON hpc;
		const hr = CreatePseudoConsole(size, pipePTYIn, pipePTYOut, opts.flags, &hpc);

		CloseHandle(pipePTYIn);
		CloseHandle(pipePTYOut);

		if (FAILED(hr))
		{
			CloseHandle(pipeIn);
			CloseHandle(pipeOut);
			throw new PtyException(format("CreatePseudoConsole failed: HRESULT 0x%08X", hr));
		}

		return new ConPty(hpc, pipeIn, pipeOut);
	}

	/// Convenience overload.
	static ConPty open(ushort cols, ushort rows)
	{
		PtyOpenOptions opts;
		opts.size = PtySize(cols, rows);
		return open(opts);
	}

	~this()
	{
		close();
	}

	/// Underlying HPCON for UpdateProcThreadAttribute.
	HPCON handle() @safe pure nothrow @nogc
	{
		return _hpc;
	}

	/// Host write end (bytes go to the child as console input).
	HANDLE inputWriteHandle() @safe pure nothrow @nogc
	{
		return _inputWrite;
	}

	/// Host read end (bytes from the child console output / VT stream).
	HANDLE outputReadHandle() @safe pure nothrow @nogc
	{
		return _outputRead;
	}

	/// Attribute value for UpdateProcThreadAttribute (pointer-sized).
	void* attributePseudoConsole() @safe pure nothrow @nogc
	{
		return cast(void*) _hpc;
	}

	/// Resize the ConPTY buffer.
	void resize(PtySize size)
	{
		enforce!PtyException(!_closed && _hpc !is null, "ConPty is closed");
		enforce!PtyException(size.valid, "PtySize must have non-zero cols and rows");
		COORD c;
		c.X = cast(short) size.cols;
		c.Y = cast(short) size.rows;
		const hr = ResizePseudoConsole(_hpc, c);
		if (FAILED(hr))
			throw new PtyException(format("ResizePseudoConsole failed: HRESULT 0x%08X", hr));
	}

	/// Resize overload.
	void resize(ushort cols, ushort rows)
	{
		resize(PtySize(cols, rows));
	}

	/// Close the ConPTY and host pipe ends. Idempotent.
	void close() nothrow
	{
		if (_closed)
			return;
		_closed = true;
		if (_hpc !is null)
		{
			ClosePseudoConsole(_hpc);
			_hpc = null;
		}
		if (_inputWrite !is null && _inputWrite != INVALID_HANDLE_VALUE)
		{
			CloseHandle(_inputWrite);
			_inputWrite = null;
		}
		if (_outputRead !is null && _outputRead != INVALID_HANDLE_VALUE)
		{
			CloseHandle(_outputRead);
			_outputRead = null;
		}
	}

	private static void closePair(HANDLE a, HANDLE b) nothrow
	{
		if (a !is null && a != INVALID_HANDLE_VALUE)
			CloseHandle(a);
		if (b !is null && b != INVALID_HANDLE_VALUE)
			CloseHandle(b);
	}
}

/// Alias matching the portable name used in docs / POSIX side.
alias Pty = ConPty;

unittest
{
	auto pty = ConPty.open(80, 24);
	scope (exit)
		pty.close();
	assert(pty.handle !is null);
	assert(pty.inputWriteHandle !is null);
	assert(pty.outputReadHandle !is null);
	pty.resize(100, 30);
}