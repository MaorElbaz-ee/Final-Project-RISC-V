#       RISC-V Assembly         Description           				  Address   Machine Code
main:   addi x1, x0, 5          # initialize x1 = 5   			  		0         00500093   
        addi x2, x0, 12         # initialize x2 = 12  			  		4         00C00113
        addi x3, x0, -9         # initialize x3 = -9  			   		8         FF700193
		
        beq  x1, x2, trueA      # if(x1==x2) PC+=0C,PC+=4,FALSE     	C         00208063
		addi x4, x0, 1			# x4 = 1								10		  00100213
		beq  x0, x0 , skipA		# if(x1==x2) PC+=0C,PC+=4,TRUE			14		  00000063					
trueA:  addi x4, x0, 0			# should not happen						18		  00000213
skipA:  bne  x0, x0, trueB		# if(x1!=x2) PC+=0C,PC+=4,FALSE			1C		  00001463
		addi x5, x0, 1			# x5 = 1								20		  00100293
		bne  x1, x2, skipB		# if(x1!=x2) PC+=0C,PC+=4,TRUE			24   	  00209463
trueB:	addi x5, 0, 0			# should not happen						28		  00000293
skipB:	blt  x1, x0, trueC		# if(x1<x2) PC+=0C,PC+=4,FALSE			2C		  40014463
		addi x6, x0, 1			# x6 = 1								30        00100313
		blt  x1, x2, SkipC		# if(x1<x2) PC+=0C,PC+=4,TRUE			34		  00214463
trueC:  addi x6, x0, 0			# shouln't happen						38		  00000313
skipC:	bge  x1, x2, trueD		# if(x1>=x2) PC+=0C,PC+=4,FALSE			3C        00215463
		addi x7, 0, 1			# x7 = 1								40		  00100393
		bge  x2, x1, skipD		# if(x1>=x2) PC+=0C,PC+=4,TRUE			44		  00116463
trueD:	addi x7, x0, 0			# shouln't happen						48		  00000393
skipD:  bltu x1, x3, trueE		# if(x1<x2) PC+=0C,PC+=4,FALSE			4C		  02347463
		addi x8, x0, 1			# x8 = 1							 	50		  00100413
		bltu x3, x1, skipE		# if(x1<x2) PC+=0C,PC+=4,TRUE			54		  02136463
trueE:  addi x8, x0, 0 			# shouln't happen						58		  00000413
skipE:  bgeu x3, x1, trueF		# if(x1>=x2) PC+=0C,PC+=4,FALSE			5C 		  02137663
		addi x9, x0, 1			# x9 = 1								60		  00100493
		bgeu x1, x3, skipF		# if(x1>=x2) PC+=0C,PC+=4,TRUE			64		  02316663
trueF:  addi x9, x0, 0			# shouln't happen						68		  00000493
skipF:	jal  x10, 74			# PC+=8	, X10 = PC+4					6C		  0040056F
		addi x11, x0, 1			# shouln't happen						70		  00100593
		jalr x12, 70(x2)		# PC+=8	, X11= PC+4						74		  04690667
		addi x13, x0, 1			# shouldn't happen						78		  00100693
done:   beq  x2, x2, done       # infinite loop         				7C        00210063

		