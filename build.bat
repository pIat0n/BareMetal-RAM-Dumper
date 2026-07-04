@echo off
echo Building stage1...
nasm -f bin stage1.asm -o stage1.bin
if %errorlevel% neq 0 exit /b %errorlevel%

echo Building stage2...
nasm -f bin stage2.asm -o stage2.bin
if %errorlevel% neq 0 exit /b %errorlevel%

echo Creating boot image (boot.bin)...
copy /b stage1.bin + stage2.bin boot.bin > nul
echo Build complete! boot.bin is ready.
