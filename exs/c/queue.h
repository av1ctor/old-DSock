#ifndef __queue_h__
#define __queue_h__

typedef struct _NODE {
#ifdef __DEBUG__
	unsigned int	id;
#endif
	struct _NODE 	far *prev;
	struct _NODE 	far *next;
} NODE;

typedef struct _QUEUE {
#ifdef __DEBUG__
	unsigned int	id;
#endif
	NODE			far	*q;
	NODE 			far *fhead;
	NODE 			far *ftail;
	NODE 			far *ahead;
	NODE 			far *atail;
	unsigned int	nodesize;
	int				items;
} QUEUE;


#ifdef __cplusplus
extern "C" {
#endif

int 				queue_create		( QUEUE 		*queue,
					  			  		  int 			nodes,
					  			  		  unsigned int 	nodeSize );

int 				queue_destroy 		( QUEUE 		*queue );

void far *			queue_new 			( QUEUE 		*queue );

int					queue_get 			( void 			far *dst,
								  		  QUEUE 		*queue );

void far *			queue_peek 			( QUEUE 		*queue );

void far *			queue_head 			( QUEUE 		*queue );

void far *			queue_tail 			( QUEUE 		*queue );

int 				queue_del 			( QUEUE 		*queue );

int 				queue_del_node		( QUEUE 		*queue,
								  		  void 			far *node );

int 				queue_del_nodes		( QUEUE 		*queue );

#ifdef __cplusplus
}
#endif

#endif /* __queue_h__ */
