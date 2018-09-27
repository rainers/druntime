# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib
CC=cl

test:
	$(CC) -c /Fostring_cpp.obj test\stdcpp\src\string.cpp
	$(DMD) -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest test\stdcpp\src\string.d string_cpp.obj
	string.exe
	del test.exe test.obj string_cpp.obj

