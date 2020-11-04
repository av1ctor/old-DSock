unit
    DSOCK;

(***************************************************************************)
interface
{$G+ $X+}
{$I ..\inc\dsock.inc}

(***************************************************************************)
implementation
{$L dsock.obj}

function accept;            external;
function bind;              external;
function closesocket;       external;
function connect;           external;
function ioctlsocket;       external;
function getpeername;       external;
function getsockname;       external;
function getsockopt;        external;
function htonl;             external;
function htons;             external;
function inet_addr;         external;
function inet_ntoa;         external;
function listen;            external;
function ntohl;             external;
function ntohs;             external;
function recv;              external;
function recvfrom;          external;
function select;            external;
function send;              external;
function sendto;            external;
function setsockopt;        external;
function shutdown;          external;
function socket;           	external;

function gethostbyaddr;     external;
function gethostbyname;     external;
function getprotobyname;    external;
function getprotobynumber;  external;
function getservbyname;     external;
function getservbyport;     external;

function WSAAsyncSelect;    external;
function WSAGetLastError;   external;
procedure WSASetLastError;  external;
function WSAStartup;        external;
function WSACleanup;        external;

function WSAGetSelectEvent;
begin
	WSAGetSelectEvent := word( lParam and $FFFF );
end;

function WSAGetSelectError;
begin
	WSAGetSelectError := word( lParam shr 16 );
end;

function MAKEWORD;
begin
	MAKEWORD := word( b ) shl 8 + word( a );
end;

(***************************************************************************)
function TP_GetMem(bytes: word): pointer; far;
var
	farptr: pointer;
begin
    GetMem( farptr, bytes );
    TP_GetMem := farptr;
end;

procedure TP_FreeMem(farptr: pointer; bytes: word); far;
begin
    FreeMem( farptr, bytes );
end;

end.
