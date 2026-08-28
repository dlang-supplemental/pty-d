# Agent notes — pty-d

Project facts for agents. Workstation/env facts live only in `$CODE_ROOT/MEMORIES.md`.

- DUB package name is `pty-d`; GitHub repo is `dlang-supplemental/pty-d`
- Module import root: `pty` (`ConPty` / `PosixPty`, both aliased as `Pty`)
- Thin OS bindings only — **no** VT parser / emulator surface
- Windows ConPTY symbols are **GetProcAddress** from `kernel32` (not static import-lib)
- Categories on DUB: `library.binding`, `library.development`
- Version source of truth: `VERSION` + `dub.sdl` `version` + git tag `vX.Y.Z`
- Related inventory: openshellorg/shell-architecture shell-host notes; VT still missing