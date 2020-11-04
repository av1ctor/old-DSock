  DSock v0.5
  copyleft 2002 by v1ctor (av1ctor@yahoo.com.br)
  

  [what]
  	DSock is a Windows Socket (Winsock) DOS interface that can be used
    by M$ BASIC compilers/interpreters (QuickBASIC 4.x, PDS and VBDOS),
    Borland TurboPascal and real-mode C compilers (for medium memory-model).
    
    	Almost all Winsock 1.x functions are supported (including
    asynchronous sockets) and it can be used in Windows 9x/Me/NT/2000/XP (for
    Windows 95, Winsock must be updated to version 2:
    www.microsoft.com/windows95/downloads).
    
        DSock "talks" directly to Winsock, so the latency will not be a real
    problem if taking into account the mode switches needed for every call
    (v86 to protected back to v86 mode) and using it wisely (ie, if not 
    calling select() to do polling, too much times per second).
  
  
  [how]
  	As DSock tries to be a 1:1 map of Winsock, if you used this API
    before, you can start coding right now (and for C programmers, porting
    will not be difficult either, if considering real-mode's limitations). 
    
    	Link to a DSOCK???.LIB static lib (depending on the compiler been
    used), copy the DSOCK.VXD and DSOCK.DLL files to the same dir where the
    executable you built is (or to `system' dir on Win9x and `system32' on NT)
    and all low-level ugly things will be done automagically.
    
    	If you have no preview experience with the Winsock API, there are
    many dedicated sites out there with tutorials and examples. Also, try
    looking at the `doc' dir, the specification plus the help file for
    Winsock version 1.x are included.
  
  
  [misc]
  	Some XP users reported the OS complaining about the wrong version
    when the VDD (DSOCK.DLL) is loaded. Trying that for 2 or 3 times and
    Windows XP stopped to show those error messages.
    
    	As the Windows 9x/Me interface is based only in hacking/debugging
    done by many persistent coders (including me), with an outdated C header
    file written for WSOCK.386 (back to WfW days!) and using a buggy WSOCK2
    VxD on its DOS API (don't worry, the VxD is patched on-the-fly when
    loaded), there's no guaranties that all will work. If you found a bug
    or if you fixed any, let me know about that.
    
    	The C lib (DSOCK.LIB) do calls to farmalloc() and farfree() routines
    for allocating memory on far heap (because malloc() in medium memory 
    model will allocate only from dgroup); these functions are present in
    Borland/Turbo C/C++ rtmlibs, but for other C compilers, you will have
    to create wrappers and add them to the static lib (DSOCK.LIB), ie, for
    Watcom C it would be:
    	#include <malloc.h>
    	void far * far farmalloc( unsigned long bytes ) { return _fmalloc( bytes ); }
    	void 	   far farfree  ( void far *p )         { _ffree( p ); }
    
    
        Adding 16-bit protected-mode support wouldn't be too difficult to do, 
    32-bit though, only if swapping loads of data and if not using the async 
    services. If you plan do to any, the sources for the static lib have many
    warnings when building for pmode, but i probably forgot details here and 
    there; if you are trying that (maybe for using in TP|DPMI or DJGPP?) and 
    are having problems or if you got all working fine, e-mail me.

  
  [greetings]
  	As DSock is written 100% in ASM, without people like Iczelion and
    his Win32 assembly page and tutorials, and hutch's tools and win32 API 
    include files, this project wouldn't ever be possible.
  	
  	DSock only works in Win95/98/Me because the hacking abilities of
    Berczi Gabor, that found fixes to WSock2 VxD DOS API bugs. Many thanks
    to him.
    
    	To authors of other open-source Winsock interfaces, without them i
    wouldn't realize if i was following the right paths or not.
    	
    	Dossock page and its author, for providing those other interfaces
    and for documenting wsock.vxd DOS API.
    	
    	To people that tested it...  
    	
    	
  [disclaimer]
	I know, it isn't necessary but, here it goes anyway... 

  	This documentation and its associated software are distributed
  	without warranties, either expressed or implied, regarding their
  	merchantability or fitness for any particular application or purpose.
  	In no event shall v1ctor be liable for any loss of profit or
  	any other commercial damage, including but not limited to special,
  	incidental, consequential, or other damages resulting from the use
  	of or the inability to use this product, even if v1ctor has been
  	notified of the possibility of such damages.

  	All brand and product names mentioned in this documentation are
  	trademarks or registered trademarks of their respective holders.
