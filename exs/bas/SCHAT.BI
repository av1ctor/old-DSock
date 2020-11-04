
const SC.DEFPORT%	= 1234%

const SC.MAXUSERS%  = 16%                       '' can't be > 64 !!

const SC.MAXLEN%	= 160%
const SC.MAXMSGS%	= 50%
const SC.NICKLEN%	= 8%

'' commands
const SCP.JOIN%		= &h00%
const SCP.QUIT%		= &h01%
const SCP.LIST%		= &h02%
const SCP.TEXT%		= &h03%
const SCP.PRIV%		= &h04%
const SCP.NICK%		= &h05%
const SCP.MODE%		= &h06%
const SCP.REFUSED%	= &h07%
const SCP.PING%		= &h08%
const SCP.PONG%		= &h09%


type TLIST
	head			as integer
	tail			as integer
	fhead			as integer
	items			as integer
end type

const SCP.HDRLEN%	= 1%+4%+2%+2%+2%+1%

const SCP.INIMARK%	= 1%
const SCP.ENDMARK%	= 2%

const SCP.IDPOS%	= 1%
const SCP.STARTPOS%	= 5%
const SCP.LENPOS%	= 7%
const SCP.CMDPOS%	= 9%
const SCP.MSGPOS%	= 11%

'' msg components:
'' <inimark>
'' <id:hexa-word>
'' <start:hexa-byte>
'' <len:hexa-byte>
'' <command:hexa-byte>
'' [<params:byte>] (max len=SC.MAXLEN, min char=32, max char=255)
'' <endmark>
