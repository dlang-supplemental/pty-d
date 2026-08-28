import std.stdio;
import pty;

void main()
{
	auto session = Pty.open(80, 24);
	scope (exit)
		session.close();

	version (Windows)
	{
		writefln("ConPTY HPCON=%s input=%s output=%s",
			session.handle, session.inputWriteHandle, session.outputReadHandle);
	}
	else version (Posix)
	{
		writefln("POSIX master=%s slave=%s", session.masterFd, session.slaveName);
	}

	session.resize(100, 30);
	writeln("resized to 100x30");
}