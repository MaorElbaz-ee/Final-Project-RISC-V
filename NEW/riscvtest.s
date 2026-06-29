# riscvtest.s
# Sarah.Harris@unlv.edu
# David_Harris@hmc.edu
# 27 May 2020
#
# Test the RISC-V processor.  
#  add, sub, and, or, slt, addi, lw, sw, beq, jal
# If successful, it should write the value 25 to address 84

#       RISC-V Assembly         Description             Address   Machine Code
main:   addi x2, x0, 5          # initialize x2 = 5     		0         00500113   
        addi x3, x0, 12         # initialize x3 = 12    		4         00C00193
        addi x7, x3, -9         # initialize x7 = 3     		8         FF718393
        add  x5, X2, x3         # x5 = 5 + 12 = 17       		C         004282B3
		sub  x6, x3, x2         # x6 = 12 - 5 = 7       		10        402383B3
		xor  x5, x3, x2	     	# x5 = (12 XOR 5) = 9			14	 	  0021A2B3
        or   x4, x7, x2         # x4 = (3 OR 5) = 7     		18        0023E233
		and  x5, x3, x4         # x5 = (12 AND 7) = 4   		1C        0041F2B3
       	sll  x5, x2, x7			# x5 = 40                       20		  007112B3
	    slt  x4, x3, x4         # x4 = (12 < 7) = 0    			1C        0041A233
		sltu x15, x5, x2		# x15 = (40 < 5) = 0			20 		  0027B3B3
		
        beq  x5, x7, end        # shouldn't be taken    		24        02728863
	    addi x6, x0, 0          # x6 = 0 / reset x6      		28        00000313
		xori x5, x0, 5			# x5 = 0 xor 5 = 5	    		2C	 	  00504293
		ori  x5, x2, 3			# x5 = 5 OR 3 = 7 				30		  00316293
		andi x4, x3, 7			# x4 = 12 and 7 = 4				34		  0071F213
		slli x4, x2, 1			# X4 = 5 << 1 = 10				38		  00111213
		srli x4, x3, 3			# x4 = 12 >> 3 = 1				3C		  0031D213 
		addi x6, x0, -1 		# x6 = -1						40		  FFF00313
		srai x5, x6, 1			# x5 = -1 >> 1 = -1 			44		  40135293
		slti x4, x3, 5			# x4 = (12 < 5) = 0				48		  0051A213
		sltiu x4, x2, -5		# x4 = (12 < -5) = 1 |unsigned  4C		  FEB12213
		
		
        beq  x4, x0, around     # should be taken      		 	50        00020463

around: add  x7, x4, x5         # x7 = 1 + -1 = 0	      		54        005203B3
        sw   x2, 84(x3)         # [96] = 5              		58        0471AA23
        lw   x2, 96(x0)         # x2 = [96] = 7         		5C        06002103
		bne  x0, x2, 8			# if x0 != x2 => PC = PC + 8	60		  00201463	
		addi  x4, x7, 1			# happen after the next order.  64		  00120313
		blt  x7, x4, -4			# if x7<x4 => pc=pc-4			68		  0043C463
		bge  x0, x7, 12			# if x0 >= x7 => PC = PC + 12   6C        00705663
		addi x8, x0, -2			# x8 = -2						70		  FFE00413
		bltu x8, x2, 40			# shouldn't be taken			74		  02246463
		bgeu x11, x0, 8			# shouldn't be taken			78	      0005F463	  
		addi x16, x0, 8 		# x16 = 8						7C        00800813
		add  x9, x2, x5         # x9 = 7 + 11 = 18    		    80        005104B3
        jal  x3, end            # jump to end, x3=0x44 		    84        008001EF
		addi x2, x0, 1          # shouldn't happen     		    88        00100113
end:    add  x2, x2, x9         # x2 = 7 + 18 = 25      		8C        00910133
        sw   x2, 0x20(x3)       # write mem[100] = 25   		90        0221A023
		auipc x13, 0			# x13 = PC						94		  00000697
		jalr x12, 8(x13)		# PC = PC +8, x12 = pc +4		98		  00868667	
		addi x6, x0, 1			# shouldn't happen				9C  	  00100313
		lui x14, 7				# x14 = 0x7000 = 12 >> 7		100		  00007737
done:   beq  x2, x2, done       # infinite loop         		104       00210063
		
		