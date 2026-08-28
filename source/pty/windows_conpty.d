/++
	Raw Windows ConPTY FFI — resolved at runtime from kernel32.dll
	(Windows 10 1809+ / Server 2019+).

	Signatures match Microsoft Docs:
	https://learn.microsoft.com/windows/console/createpseudoconsole
+/
module pty.windows_conpty;

version (Windows):

import core.sys.windows.windows;
import core.sys.windows.winbase : GetProcAddress, GetModuleHandleW;

/// Opaque ConPTY handle (HPCON).
alias HPCON = HANDLE;

/// Inherit the cursor from the parent console when creating a ConPTY.
enum DWORD PSEUDOCONSOLE_INHERIT_CURSOR = 0x1;

/// PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE value used with
/// UpdateProcThreadAttribute when spawning a child into the ConPTY.
enum DWORD_PTR PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE =
	cast(DWORD_PTR)(0x00020016);

alias CreatePseudoConsoleFn = extern (Windows) HRESULT function(
	COORD size,
	HANDLE hInput,
	HANDLE hOutput,
	DWORD dwFlags,
	HPCON* phPC) nothrow @nogc;

alias ResizePseudoConsoleFn = extern (Windows) HRESULT function(
	HPCON hPC,
	COORD size) nothrow @nogc;

alias ClosePseudoConsoleFn = extern (Windows) void function(HPCON hPC) nothrow @nogc;

private __gshared CreatePseudoConsoleFn pCreatePseudoConsole;
private __gshared ResizePseudoConsoleFn pResizePseudoConsole;
private __gshared ClosePseudoConsoleFn pClosePseudoConsole;
private __gshared bool resolved;
private __gshared bool resolveOk;

private void resolve() nothrow @nogc
{
	if (resolved)
		return;
	resolved = true;
	auto k32 = GetModuleHandleW("kernel32.dll");
	if (k32 is null)
		return;
	pCreatePseudoConsole = cast(CreatePseudoConsoleFn) GetProcAddress(k32, "CreatePseudoConsole");
	pResizePseudoConsole = cast(ResizePseudoConsoleFn) GetProcAddress(k32, "ResizePseudoConsole");
	pClosePseudoConsole = cast(ClosePseudoConsoleFn) GetProcAddress(k32, "ClosePseudoConsole");
	resolveOk = pCreatePseudoConsole !is null
		&& pResizePseudoConsole !is null
		&& pClosePseudoConsole !is null;
}

/// True when ConPTY entry points were found in kernel32.
bool conptyAvailable() nothrow @nogc
{
	resolve();
	return resolveOk;
}

/// Create a ConPTY attached to the given pipe ends.
HRESULT CreatePseudoConsole(
	COORD size,
	HANDLE hInput,
	HANDLE hOutput,
	DWORD dwFlags,
	HPCON* phPC) nothrow @nogc
{
	resolve();
	if (!resolveOk)
		return cast(HRESULT) 0x80004001; // E_NOTIMPL
	return pCreatePseudoConsole(size, hInput, hOutput, dwFlags, phPC);
}

/// Change the ConPTY buffer size in character cells.
HRESULT ResizePseudoConsole(HPCON hPC, COORD size) nothrow @nogc
{
	resolve();
	if (!resolveOk)
		return cast(HRESULT) 0x80004001;
	return pResizePseudoConsole(hPC, size);
}

/// Close a ConPTY and free its resources.
void ClosePseudoConsole(HPCON hPC) nothrow @nogc
{
	resolve();
	if (resolveOk && pClosePseudoConsole !is null)
		pClosePseudoConsole(hPC);
}