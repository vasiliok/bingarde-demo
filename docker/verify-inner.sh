#!/bin/sh
# Inspect one Windows variant's PDB with llvm tools (inside llvm-mingw).
win=out/alpha/main/140/windows-release-x86_64
echo "--- PDB summary"
llvm-pdbutil dump -summary "$win/DemoApp.pdb" | grep -E 'Age|Guid|Has Debug Info'
echo "--- PDB functions (sample)"
llvm-pdbutil dump -symbols "$win/DemoApp.pdb" 2>/dev/null | grep -o '`[a-z_]*`' | tr -d '`' | grep -E '^(world_|engine_|entity_)' | sort -u | tr '\n' ' '; echo
echo "--- EXE points to its PDB"
llvm-readobj --coff-debug-directory "$win/DemoApp.exe" | grep -E 'PDBFileName|PDBGUID' | head -2
