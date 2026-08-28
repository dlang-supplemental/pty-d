/++
	POSIX PTY host via posix_openpt / grantpt / unlockpt / ptsname.

	Does not fork/exec. Callers open the slave path in the child after fork,
	or pass the slave fd after open.
+/
module pty.posix;

version (Posix):

import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.stdlib : grantpt, posix_openpt, ptsname, unlockpt;
import core.sys.posix.sys.ioctl;
import std.exception : enforce;
import std.format : format;
import std.string : fromStringz;

import pty.exception;
import pty.types;

struct winsize
{
	ushort ws_row;
	ushort ws_col;
	ushort ws_xpixel;
	ushort ws_ypixel;
}

version (linux)
{
	enum int TIOCSWINSZ = 0x5414;
}
else version (OSX)
{
	enum int TIOCSWINSZ = 0x80087467;
}
else version (FreeBSD)
{
	enum int TIOCSWINSZ = 0x80087467;
}
else
{
	enum int TIOCSWINSZ = 0x5414;
}

/// Host-side POSIX PTY (master fd + slave path).
final class PosixPty
{
	private int _master = -1;
	private string _slaveName;
	private bool _closed;

	private this(int master, string slaveName) @safe pure nothrow
	{
		_master = master;
		_slaveName = slaveName;
	}

	/// Open a new PTY pair and apply the initial window size.
	static PosixPty open(PtyOpenOptions opts = PtyOpenOptions.init)
	{
		enforce!PtyException(opts.size.valid, "PtySize must have non-zero cols and rows");

		immutable int master = posix_openpt(O_RDWR | O_NOCTTY);
		if (master < 0)
			throw new PtyException(format("posix_openpt failed: %s", errnoString()));

		if (grantpt(master) != 0)
		{
			closeFd(master);
			throw new PtyException(format("grantpt failed: %s", errnoString()));
		}
		if (unlockpt(master) != 0)
		{
			closeFd(master);
			throw new PtyException(format("unlockpt failed: %s", errnoString()));
		}

		auto namePtr = ptsname(master);
		if (namePtr is null)
		{
			closeFd(master);
			throw new PtyException(format("ptsname failed: %s", errnoString()));
		}
		const slaveName = namePtr.fromStringz.idup;

		auto pty = new PosixPty(master, slaveName);
		pty.resize(opts.size);
		return pty;
	}

	/// Convenience overload.
	static PosixPty open(ushort cols, ushort rows)
	{
		PtyOpenOptions opts;
		opts.size = PtySize(cols, rows);
		return open(opts);
	}

	~this()
	{
		close();
	}

	/// Master file descriptor (host I/O).
	int masterFd() @safe pure nothrow @nogc
	{
		return _master;
	}

	/// Slave device path (e.g. /dev/pts/3) for the child to open.
	string slaveName() @safe pure nothrow @nogc
	{
		return _slaveName;
	}

	/// Open the slave side; caller owns the returned fd.
	int openSlave()
	{
		enforce!PtyException(!_closed && _master >= 0, "PosixPty is closed");
		immutable int fd = .open(_slaveName.toStringz, O_RDWR | O_NOCTTY);
		if (fd < 0)
			throw new PtyException(format("open(%s) failed: %s", _slaveName, errnoString()));
		return fd;
	}

	/// Resize via TIOCSWINSZ on the master.
	void resize(PtySize size)
	{
		enforce!PtyException(!_closed && _master >= 0, "PosixPty is closed");
		enforce!PtyException(size.valid, "PtySize must have non-zero cols and rows");
		winsize ws;
		ws.ws_col = size.cols;
		ws.ws_row = size.rows;
		if (ioctl(_master, TIOCSWINSZ, &ws) != 0)
			throw new PtyException(format("ioctl(TIOCSWINSZ) failed: %s", errnoString()));
	}

	/// Resize overload.
	void resize(ushort cols, ushort rows)
	{
		resize(PtySize(cols, rows));
	}

	/// Close the master fd. Idempotent.
	void close() nothrow
	{
		if (_closed)
			return;
		_closed = true;
		closeFd(_master);
		_master = -1;
	}

	private static void closeFd(int fd) nothrow
	{
		if (fd >= 0)
			.close(fd);
	}

	private static string errnoString() nothrow
	{
		import core.stdc.string : strerror;
		import core.stdc.errno : errno;
		try
			return strerror(errno).fromStringz.idup;
		catch (Exception)
			return "unknown error";
	}
}

/// Alias matching the portable name used in docs / Windows side.
alias Pty = PosixPty;

private const(char)* toStringz(string s) @trusted
{
	import std.string : toStringz;
	return s.toStringz;
}

unittest
{
	auto pty = PosixPty.open(80, 24);
	scope (exit)
		pty.close();
	assert(pty.masterFd >= 0);
	assert(pty.slaveName.length > 0);
	pty.resize(120, 40);
	immutable int slave = pty.openSlave();
	scope (exit)
		close(slave);
	assert(slave >= 0);
}