
main:
addi x1, x0, 5           # x1 = 5   						# 00        00500093
addi x2, x0, 12          # x2 = 12  						# 04        00C00113
addi x3, x0, -3          # x3 = -3  						# 08        FFD00193
mul  x10, x1, x2         # 60       						# 0C        02208533
mulh x11, x3, x2         # high((-3)*12) = 0xFFFF_FFFF  	# 10        022195B3
mulhsu x12, x3, x2       # high_su((-3)*12) = 0xFFFF_FFFF   # 14        0221A633
mulhu x13, x1, x2        # high_u(60) = 0 					# 18        0220B6B3
addi x4, x0, 7           # x4 = 7   						# 1C        00700213
addi x5, x0, 3           # x5 = 3   						# 20        00300293
div  x14, x4, x5         # 7/3 = 2  						# 24        02524733
rem  x15, x4, x5         # 7%3 = 1  						# 28        025267B3
div  x16, x3, x5         # -3/3 = -1 						# 2C        0251C833
rem  x17, x3, x5         # -3%3 = 0 						# 30        0251E8B3
divu x18, x2, x4         # 12/7 = 1 (u)						# 34        02415933
remu x19, x2, x4         # 12%7 = 5 (u) 					# 38        024179B3
div  x20, x1, x0         # /0 -> -1 						# 3C        0200CA33
rem  x21, x1, x0         # %0 -> dividend 					# 40        0200EAB3
addi x22, x0, -1         # x22 = -1 						# 44        FFF00B13
slli x22, x22, 31        # x22 = 0x80000000 				# 48        01FB1B13
addi x23, x0, -1         # x23 = -1 						# 4C        FFF00B93
div  x24, x22, x23       # 0x8000_0000						# 50        037B4C33
rem  x25, x22, x23       # 0        						# 54        037B6CB3
addi x2, x0, 25          # x2 = 25  						# 58        01900113
slli x2, x2, 1           # x2 = 50  						# 5C        00111113
sw   x2, 100(x0)         # [100] = 50 						# 60        06202223
beq  x0, x0, 0           # loop     						# 64        00000063
