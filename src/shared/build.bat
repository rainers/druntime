rem set dmd=..\..\..\windows\bin\dmd
set dmd=..\..\..\dmd\src\vcbuild\win32\debug\dmd_msc
set cv2pdb="c:\Program Files (x86)\VisualD\cv2pdb\cv2pdb.exe" -n

set objs=..\..\src\rt\minit.obj ..\..\snn\tlsseg.obj
set libs=..\..\lib\druntime_shared.lib snd.lib

%cv2pdb% ..\..\lib\druntime_shared.dll druntime_shared.dll

%dmd% -g -exportall=dll_exp.symbols -ofdll.dll -map dll.d %libs% -defaultlib=phobos -L/IMPLIB
if errorlevel 1 goto :EOF
%cv2pdb% dll.dll

genexp dll_exp.symbols > dll_exp.d
if errorlevel 1 goto :EOF

%dmd% -g exe.d dll_exp.d -ofexe.exe -map %objs% %libs% -defaultlib=phobos dll.lib
if errorlevel 1 goto :EOF
%cv2pdb% exe.exe
