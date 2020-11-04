
#define SCP_DEFPORT		1234

#define SCP_MAXUSERS  	16                     	// can't be > 64 !!
#define SCP_NICKLEN		8

#define SCP_MAXLEN		160
#define SCP_MAXMSGS		50

// commands
#define SCP_JOIN		0x00
#define SCP_QUIT		0x01
#define SCP_LIST		0x02
#define SCP_TEXT		0x03
#define SCP_PRIV		0x04
#define SCP_NICK		0x05
#define SCP_MODE		0x06
#define SCP_REFUSED		0x07
#define SCP_PING		0x08
#define SCP_PONG		0x09

#define SCP_HDRLEN		(1+4+2+2+2+1)

#define SCP_INIMARK		'\1'
#define SCP_ENDMARK		'\2'

#define SCP_IDPOS		1
#define SCP_STARTPOS	5
#define SCP_LENPOS		7
#define SCP_CMDPOS		9
#define SCP_MSGPOS		11

// stream components:
// <inimark>
// <id:hexa-word>
// <start:hexa-byte>
// <len:hexa-byte>
// <command:hexa-byte>
// [<params:byte>] (max len=SCP_MAXLEN, min char=32, max char=255)
// <endmark>

typedef struct _SCP_STREAM {
	unsigned char	imark;
	unsigned long	id;
	unsigned short	start;
	unsigned short	length;
	unsigned short	cmd;
	char			msg[SCP_MAXLEN+1];
} SCP_STREAM;
