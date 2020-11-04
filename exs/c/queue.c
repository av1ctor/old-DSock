//
// queue.c -- helper routines for working with FIFO queues
//
// obs: when compiling this module using BC, don't choose the -O2 option
//      or many parts will fail due buggy code generated (next time i'll
//      turn off all optimizations before trying for hours to find a bug
//      in my code for then find that the problem wasn't on it, but on
//      the compiler :P)
//

#include <malloc.h>
#include <mem.h>
#include "queue.h"

///
static unsigned long near FP2LIN ( void far *fp )
{
	asm			mov		ax, word ptr fp+2
	asm			mov		dx, ax
	asm			shl		ax, 4
	asm			shr		dx, 16-4
	asm			add		ax, word ptr fp+0
	asm			adc		dx, 0
}

///
static void far *near LIN2FP ( unsigned long lin )
{
	asm			mov		dx, word ptr lin+2
	asm			mov		ax, word ptr lin+0
	asm			mov		cx, ax
	asm			shl		dx, 16-4
	asm			shr		cx, 4
	asm			or		dx, cx
	asm			and		ax, 15
}

#include <stdio.h>
unsigned int farfwrite( char far *buf, unsigned int bytes, FILE *f );

///////////////////////////////////////////////////////////////////////////
int queue_create ( QUEUE *queue, int nodes, unsigned int nodeSize )
{
	NODE 			far *n, far *prev;
	unsigned long   lin;
	int 			i;
#ifdef __DEBUG__
	static unsigned char fchar = 32;
#endif

	queue->nodesize = nodeSize;

	nodeSize += sizeof( NODE );

	queue->q = (NODE far *)farmalloc( (long)nodes * nodeSize + 4L );
	if ( queue->q == NULL ) return 0;

    n = (NODE far *)(((char far *)queue->q) + 4);

#ifdef __DEBUG__
	queue->id 	 = 'Qu';
	++fchar;
#endif
    queue->fhead = n;
    queue->ahead = NULL;
    queue->atail = NULL;
    queue->items = 0;

    lin = FP2LIN( n );
    prev = NULL;
    for ( i = 0; i < nodes-1; i++ )
    {
#ifdef __DEBUG__
 		n->id	= 'Fn';
		_fmemset( ((char far *)n) + sizeof( NODE ), fchar, queue->nodesize );
#endif
 		n->prev = prev;
 		prev 	= n;
 		lin 	+= nodeSize;
 		n->next = LIN2FP( lin );
 		n 		= n->next;
    }
#ifdef __DEBUG__
 	n->id	= 'Fn';
 	_fmemset( ((char far *)n) + sizeof( NODE ), fchar, queue->nodesize );
#endif
    n->prev = prev;
    n->next = NULL;

    queue->ftail = n;

#ifdef __DEBUG__
	/*
    for ( n = queue->fhead; n != NULL; n = n->next )
     	farfwrite( n, queue->nodesize + sizeof( NODE ), stdout );
    */
#endif

    return 1;
}

///////////////////////////////////////////////////////////////////////////
int queue_destroy ( QUEUE *queue )
{
#ifdef __DEBUG__
    NODE far *n;
#endif

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return 0;
#endif

#ifdef __DEBUG__
    /*
    for ( n = queue->fhead; n != NULL; n = n->next )
     	farfwrite( n, queue->nodesize + sizeof( NODE ), stdout );
    for ( n = queue->ahead; n != NULL; n = n->next )
     	farfwrite( n, queue->nodesize + sizeof( NODE ), stdout );
	*/
#endif

    if ( queue->q != NULL )
    	farfree( queue->q );

    queue->q 	 = NULL;
    queue->fhead = NULL;
    queue->ftail = NULL;
    queue->ahead = NULL;
    queue->atail = NULL;
    queue->items = 0;

    return 1;
}

///////////////////////////////////////////////////////////////////////////
void far *queue_new ( QUEUE *queue )
{
    NODE 	far *n;

    if ( (queue->q == NULL) || (queue->fhead == NULL) ) return NULL;

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return NULL;
#endif

	__asm	cli							// enter

	n = queue->fhead;

#ifdef __DEBUG__
	if ( n->id != 'Fn' )
	{
		__asm	sti
		return NULL;
	}
#endif

	// del from beginning of free list
	queue->fhead = queue->fhead->next;
	if ( queue->fhead != NULL )
		queue->fhead->prev = NULL;
	else
		queue->ftail = NULL;

	// add to end of allocated list
	n->prev = queue->atail;
	n->next = NULL;
	if ( queue->atail != NULL )
		queue->atail->next = n;
	else
		queue->ahead = n;

	queue->atail = n;

	++queue->items;

#ifdef __DEBUG__
 		n->id	= 'An';
#endif

	__asm	sti							// leave

	return (void far *)(((char far *)n) + sizeof( NODE ));
}

///////////////////////////////////////////////////////////////////////////
void far *queue_peek ( QUEUE *queue )
{
	NODE 	far *n;

    if ( (queue->q == NULL) || (queue->ahead == NULL) ) return NULL;

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return NULL;
#endif

	n = queue->ahead;

#ifdef __DEBUG__
	if ( n->id != 'An' ) return NULL;
#endif

	return (void far *)(((char far *)n) + sizeof( NODE ));
}

/////////////////////////////////
static void near _queue_add_alist ( QUEUE *queue, NODE far *n )
{
	__asm	cli							// enter

#ifdef __DEBUG__
	n->id	= 'An';
#endif

	// add to end of allocated list
	n->prev = queue->atail;
	n->next = NULL;
	if ( queue->atail != NULL )
		queue->atail->next = n;
	else
		queue->ahead = n;
	queue->atail = n;

	++queue->items;

	__asm	sti							// leave
}

/////////////////////////////////
static NODE far *near _queue_del_alist ( QUEUE *queue )
{
	NODE	far *n;

	__asm	cli							// enter

	n = queue->ahead;

#ifdef __DEBUG__
	n->id	= 0;
#endif

	// del from allocated list
	if ( n->next != NULL )
		n->next->prev = NULL;
	else
		queue->atail = NULL;
	queue->ahead = n->next;

	--queue->items;

	__asm	sti							// leave

	return n;
}

/////////////////////////////////
static void near _queue_add_flist ( QUEUE *queue, NODE far *n )
{
	__asm	cli							// enter

#ifdef __DEBUG__
	n->id	= 'Fn';
#endif

	// add to end of free list
	n->prev = queue->ftail;
	n->next = NULL;
	if ( queue->ftail != NULL )
		queue->ftail->next = n;
	else
		queue->fhead = n;
	queue->ftail = n;

	__asm	sti							// leave
}

/////////////////////////////////
static NODE far *near _queue_del_flist ( QUEUE *queue )
{
	NODE	far *n;

	__asm	cli							// enter

	n = queue->fhead;

#ifdef __DEBUG__
	n->id	= 0;
#endif

	// del from free list
	if ( n->next != NULL )
		n->next->prev = NULL;
	else
		queue->ftail = NULL;
	queue->fhead = n->next;

	__asm	sti							// leave

	return n;
}

///////////////////////////////////////////////////////////////////////////
int queue_get ( void far *dst, QUEUE *queue )
{
	NODE 	far *n;

    if ( (queue->q == NULL) || (queue->ahead == NULL) ) return 0;

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return 0;
#endif

	n = _queue_del_alist( queue );

	_fmemcpy( dst, ((char far *)n) + sizeof( NODE ), queue->nodesize );

	_queue_add_flist( queue, n );

	return 1;
}

///////////////////////////////////////////////////////////////////////////
int queue_put ( QUEUE *queue, void far *src )
{
	NODE 	far *n;

    if ( (queue->q == NULL) || (queue->fhead == NULL) ) return 0;

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return 0;
#endif

	n = _queue_del_flist( queue );

	_fmemcpy( ((char far *)n) + sizeof( NODE ), src, queue->nodesize );

	_queue_add_alist( queue, n );

	return 1;
}

///////////////////////////////////////////////////////////////////////////
int queue_del_node ( QUEUE *queue, void far *node )
{
    NODE 	far *n;

    if ( (queue->q == NULL) || (node == NULL) ) return 0;

#ifdef __DEBUG__
	if ( queue->id != 'Qu' ) return 0;
#endif

	n = (NODE far *)(((char far *)node) - sizeof( NODE ));

#ifdef __DEBUG__
	if ( n->id != 'An' ) return 0;
#endif

	__asm	cli							// enter

	// del from allocated list
	if ( n->prev != NULL )
		n->prev->next = n->next;
	else
		queue->ahead = n->next;

	if ( n->next != NULL )
		n->next->prev = n->prev;
	else
		queue->atail = n->prev;

#ifdef __DEBUG__
	n->id 	= 'Fn';
#endif

	// add to end of free list
	n->prev = queue->ftail;
	n->next = NULL;
	if ( queue->ftail != NULL )
		queue->ftail->next = n;
	else
		queue->fhead = n;
	queue->ftail = n;

	--queue->items;

	__asm	sti							// leave

	return 1;
}

///////////////////////////////////////////////////////////////////////////
int queue_del ( QUEUE *queue )
{
    void 	far *n;

    if ( (queue->q == NULL) || (queue->ahead == NULL) ) return 0;

    n = (void far *)(((char far *)queue->ahead) + sizeof( NODE ));

	return queue_del_node( queue, n );
}

