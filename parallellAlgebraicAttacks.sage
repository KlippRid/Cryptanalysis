from sage.sat.solvers import CryptoMiniSat
import time
import pickle
T = 7 # number of rounds
m = 4 # number of key words
z = 4506230155203752166 # sliding constant


#---------------------------HELP FUNCTIONS---------------------------------------

# Rotate left: 0b1001 --> 0b0011
rol = lambda val, r_bits, max_bits: \
    (val << r_bits%max_bits) & (2**max_bits-1) | \
    ((val & (2**max_bits-1)) >> (max_bits-(r_bits%max_bits)))
 
# Rotate right: 0b1001 --> 0b1100
ror = lambda val, r_bits, max_bits: \
    ((val & (2**max_bits-1)) >> r_bits%max_bits) | \
    (val << (max_bits-(r_bits%max_bits)) & (2**max_bits-1))

# Round function
f = lambda x: \
    (rol(x, 1, 16)&rol(x, 8, 16)^^rol(x, 2, 16))


#---------------------------HELP FUNCTIONS---------------------------------------

def leftshift(var,step,shift):	#shifts the variable (var)
	
	result = (var-1+step)%16 + shift #shift is startposition of val index
	return result

def rightshift(var,step,shift):	#shifts the variable (var)

	result = (var-1-step)%16 + shift
	return result

#---------------------------KEY EXPANSION----------------------------------------

def keyExp(T, m, z, mainKey):
	for i in range(m, T):
		tmp = ror(mainKey[i-1], 3, 16)
		if (m == 4):
			tmp = tmp^^mainKey[i-3]
		tmp = tmp^^(ror(tmp, 1, 16))
		zz = z>>(61-(i-m))&1
		x = mainKey[i-m]^^tmp^^zz^^(0xfffc)
		mainKey.append(x)
	return mainKey;

#---------------------------ENCRYPTION-------------------------------------------

def encryption(keyInput, textleft, textright):
	for i in range(T):
		tmp = textleft[i]
		textleft.append(textright[i]^^f(tmp)^^keyInput[i])
		textright.append(textleft[i])
	return [(textleft[T]), (textright[T])]; #Take out the resulting cryptotext

#---------------------------SAT-SOLVER-------------------------------------------

@parallel
# input variables is 3 plaintexts (text{1,2,3}), 3 ciphertexts (crypto{1,2,3}), number of rounds (T) and SAT-solver (cms)
def SATsolver(text1, crypto1, text2, crypto2, text3, crypto3, T, cms): 

# First equation (c1=Ex(P1)), refered to as system 1
	c0 = crypto1[0] #crypto0[T-1]
	c1 = crypto1[1] #crypto1[T-1]
	p0 = text1[0]#0x6565
	p1 = text1[1]#0x6877
	D1 = f(p0)^^p1
	D2 = p0
	D3 = 0
	D3i = 0^^1
	D4 = c1
	D5 = c0^^f(c1)

# Second equation (c2=Ex(P2)), refered to as system 2
	c20 = crypto2[0]
	c21 = crypto2[1]
	p20 = text2[0]#0x7545
	p21 = text2[1]#0x5210
	N1 = f(p20)^^p21
	N2 = p20
	N3 = 0
	N3i = 0^^1
	N4 = c21
	N5 = c20^^f(c21)

# Third equation (c3=Ex(P3)), refered to as system 3
	c30 = crypto3[0]
	c31 = crypto3[1]
	p30 = text3[0]#0x8572
	p31 = text3[1]#0x1426
	M1 = f(p30)^^p31
	M2 = p30
	M3 = 0
	M3i = 0^^1
	M4 = c31
	M5 = c30^^f(c31)


	for n in range(T-3):
	
		if n == 0:
	#--------------------------------------------------------------------------------
	#The two first equations

	# CNF equations  (same for system 2)        
	# 1. k1 XOR x0 = f(p0) XOR p1
	# 2. k2 XOR x1 XOR f(x0) = p0
	# 3. k2 XOR x1 XOR v1 XOR S2(x0) = p0
	# CNF equation v1 = S1(x0)&S8(x0):
	# 4. v1 OR not S1(x0) OR not S8(x0)
	# 5. not v1 OR S1(x0)
	# 6. not v1 OR S8(x0)
	#--------------------------------------------------------------------------------

			startk1 = 1
			startk2 = 1+1*16
			# System 1
			startx1 = 1+T*16		#T = number of keys
			startx2 = 1+(T+1)*16 		#T = number of keys and 1 = number of x variables before x2
			startv = 1+(T+(T-2))*16 	#T = number of keys and (T-2) = number of x-variables
			# System 2
			starty1 = 1+(T+2*(T-2))*16	#T = number of keys
			starty2 = 1+(T+2*(T-2)+1)*16 	#T = number of keys and 1 = number of y variables before y2
			startvy = 1+(T+3*(T-2))*16 	#T = number of keys and (T-2) = number of y-variables
			# System 3
			startz1 = 1+(T+4*(T-2))*16	#T = number of keys
			startz2 = 1+(T+4*(T-2)+1)*16 	#T = number of keys and 1 = number of y variables before y2
			startvz = 1+(T+5*(T-2))*16 	#T = number of keys and (T-2) = number of y-variables
			
			for i in range(16):
				k1 = i+startk1
				k2 = i+startk2
				# System 1
				x1 = i+startx1
				x2 = i+startx2
				v = i+startv
	    			D1i = (D1>>(15-i))&1^^1
	    			D2i = (D2>>(15-i))&1^^1
				s1x1 = leftshift(x1,1,startx1)
				s2x1 = leftshift(x1,2,startx1)
				s8x1 = leftshift(x1,8,startx1)
				# System 2
				y1 = i+starty1
				y2 = i+starty2
				vy = i+startvy
	    			N1i = (N1>>(15-i))&1^^1
	    			N2i = (N2>>(15-i))&1^^1
				s1y1 = leftshift(y1,1,starty1)
				s2y1 = leftshift(y1,2,starty1)
				s8y1 = leftshift(y1,8,starty1)
				# System 3
				z1 = i+startz1
				z2 = i+startz2
				vz = i+startvz
	    			M1i = (M1>>(15-i))&1^^1
	    			M2i = (M2>>(15-i))&1^^1
				s1z1 = leftshift(z1,1,startz1)
				s2z1 = leftshift(z1,2,startz1)
				s8z1 = leftshift(z1,8,startz1)
			# Add clauses for system 1
	    			cms.add_xor_clause((k1,x1), D1i)

	    			cms.add_xor_clause((k2,x2,v,s2x1),D2i)
	    			cms.add_clause((v,-1*s1x1,-1*s8x1))
	    			cms.add_clause((-1*v, s1x1))
	    			cms.add_clause((-1*v, s8x1))
			# Add clauses for system 2
	    			cms.add_xor_clause((k1,y1), N1i)

	    			cms.add_xor_clause((k2,y2,vy,s2y1),N2i)
	    			cms.add_clause((vy,-1*s1y1,-1*s8y1))
	    			cms.add_clause((-1*vy, s1y1))
	    			cms.add_clause((-1*vy, s8y1))
			# Add clauses for system 3
	    			cms.add_xor_clause((k1,z1), M1i)

	    			cms.add_xor_clause((k2,z2,vz,s2z1),M2i)
	    			cms.add_clause((vz,-1*s1z1,-1*s8z1))
	    			cms.add_clause((-1*vz, s1z1))
	    			cms.add_clause((-1*vz, s8z1))


		elif 0 < n < (T-3-1):
	#--------------------------------------------------------------------------------
	#Equations inbetween

	# 7. k3 XOR x2 XOR x0 XOR f(x1) = 0
	# 8. k3 XOR x2 XOR x0 XOR v2 XOR S2(x1) = 0
	# CNF equation v2 = S1(x1)&S8(x1):
	# 9. v2 OR not S1(x1) OR not S8(x1)
	# 10. not v2 OR S1(x1)
	# If key number is larger than the 4 predefined keys
	# 18. k5 XOR k1 XOR k2 XOR S-3(k4) XOR S-1(k2) XOR S-4(k4) = konstant
	#(konstant = 3 XOR zj)
	#--------------------------------------------------------------------------------

			startk = 1 + (n+1)*16
			if n>2:
				startk1 = 1 + (n+1-4)*16 #key value two iterations ago
				startk2 = 1 + (n+1-3)*16 #key value three iterations ago
				startk4 = 1 + (n+1-1)*16 #key value in previouse iteration
				zz = z>>(61-(n-4))&1
				roundConstant = zz^^3
			# System 1
			startx1 = 1 + ((n-1)+T)*16	#x value two iterations ago
			startx2 = 1 + (n+T)*16		#x value in previouse iteration
			startx3 = 1 + ((n+1)+T)*16	#current x value
			startv = 1+(T+n+(T-2))*16 	#n = number of v variables before v, T = number of keys and (T-2) = number of x-variables
		
			# System 2
			starty1 = 1 + ((n-1)+T+2*(T-2))*16	#y value two iterations ago
			starty2 = 1 + (n+T+2*(T-2))*16		#y value in previouse iteration
			starty3 = 1 + ((n+1)+T+2*(T-2))*16	#current y value
			startvy = 1 + (n+T+3*(T-2))*16 		#n = number of v variables before v, T = number of keys and (T-2) = number of y-variables

			# System 3
			startz1 = 1 + ((n-1)+T+4*(T-2))*16	#z value two iterations ago
			startz2 = 1 + (n+T+4*(T-2))*16		#z value in previouse iteration
			startz3 = 1 + ((n+1)+T+4*(T-2))*16	#current z value
			startvz = 1 + (n+T+5*(T-2))*16 		#n = number of v variables before v, T = number of keys and (T-2) = number of z-variables

			#print n
			for i in range(16):
				k = i+startk
			# Add clauses for system 1
				x1 = i+startx1
				x2 = i+startx2
				x3 = i+startx3
				s1x2 = leftshift(x2,1,startx2)
				s2x2 = leftshift(x2,2,startx2)
				s8x2 = leftshift(x2,8,startx2)
				v = i+startv
	    			cms.add_xor_clause((k,x3,x1,v,s2x2),D3i)
	    			cms.add_clause((v,-1*s1x2,-1*s8x2))
	    			cms.add_clause((-1*v, s1x2))
	   			cms.add_clause((-1*v, s8x2))
			# Add clauses for system 2
				y1 = i+starty1
				y2 = i+starty2
				y3 = i+starty3
				s1y2 = leftshift(y2,1,starty2)
				s2y2 = leftshift(y2,2,starty2)
				s8y2 = leftshift(y2,8,starty2)
				vy = i+startvy
	    			cms.add_xor_clause((k,y3,y1,vy,s2y2),N3i)
	    			cms.add_clause((vy,-1*s1y2,-1*s8y2))
	    			cms.add_clause((-1*vy, s1y2))
	   			cms.add_clause((-1*vy, s8y2))
			# Add clauses for system 3
				z1 = i+startz1
				z2 = i+startz2
				z3 = i+startz3
				s1z2 = leftshift(z2,1,startz2)
				s2z2 = leftshift(z2,2,startz2)
				s8z2 = leftshift(z2,8,startz2)
				vz = i+startvz
	    			cms.add_xor_clause((k,z3,z1,vz,s2z2),M3i)
	    			cms.add_clause((vz,-1*s1z2,-1*s8z2))
	    			cms.add_clause((-1*vz, s1z2))
	   			cms.add_clause((-1*vz, s8z2))
				if n>2:
					k1 = i+startk1
					k2 = i+startk2
					k4 = i+startk4
	    				r3k4 = rightshift(k4,3,startk4)
	    				r4k4 = rightshift(k4,4,startk4)
	    				r1k2 = rightshift(k2,1,startk2)				
					D6i = (roundConstant>>(15-i)&1)
					N6i = (roundConstant>>(15-i)&1)
					M6i = (roundConstant>>(15-i)&1)
			# Add clauses for system 1
					cms.add_xor_clause((k,k1,k2,r3k4,r1k2,r4k4),D6i)
			# Add clauses for system 2
					cms.add_xor_clause((k,k1,k2,r3k4,r1k2,r4k4),N6i)
			# Add clauses for system 3
					cms.add_xor_clause((k,k1,k2,r3k4,r1k2,r4k4),M6i)

		else:
	#--------------------------------------------------------------------------------
	#Three last equations

	# 7. k3 XOR x2 XOR x0 XOR f(x1) = 0
	# 8. k3 XOR x2 XOR x0 XOR v2 XOR S2(x1) = 0
	# CNF equation v2 = S1(x1)&S8(x1):
	# 9. v2 OR not S1(x1) OR not S8(x1)
	# 10. not v2 OR S1(x1)
	# 12. k4 XOR x1 XOR f(x2) = c1
	# 13. k4 XOR x1 XOR v3 XOR S2(x2) = c1
	# CNF equation v3 = S1(x2)&S8(x2):
	# 14. v3 OR not S1(x2) OR not S8(x2)
	# 15. not v3 OR S1(x2)
	# 16. not v3 OR S8(x2)
	# 17. x2 XOR k5 = c0 XOR f(c1)
	# If key number is larger than the 4 predefined keys
	# 18. k5 XOR k1 XOR k2 XOR S-3(k4) XOR S-1(k2) XOR S-4(k4) = konstant
	#(konstant = 3 XOR zj)

	#--------------------------------------------------------------------------------
			if n>2:
				startk1 = 1 + (n+1-4)*16 #key value four iterations ago
				startk2 = 1 + (n+1-3)*16 #key value three iterations ago
				startk4 = 1 + (n+1-1)*16 #key value in previouse iteration
				zz = z>>(61-(n-3))&1
				roundConstant1 = zz^^3
			if n>1:
				startk1n2 = 1 + (n+2-4)*16 #key value four iterations ago
				startk2n2 = 1 + (n+2-3)*16 #key value three iterations ago
				startk4n2 = 1 + (n+2-1)*16 #key value in previouse iteration
				zz = z>>(61-(n-3+1))&1
				roundConstant2 = zz^^3
			if n>0:
				startk1n3 = 1 + (n+3-4)*16 #key value four iterations ago
				startk2n3 = 1 + (n+3-3)*16 #key value three iterations ago
				startk4n3 = 1 + (n+3-1)*16 #key value in previouse iteration
				zz = z>>(61-(n-3+2))&1
				roundConstant3 = zz^^3
			startkn = 1 + (n+1)*16
			startkn2 = 1 + (n+2)*16
			startkn3 = 1 + (n+3)*16

			# System 1
			startx1 = 1 + ((n-1)+T)*16	#x value two iterations ago
			startx2 = 1 + (n+T)*16		#x value in previouse iteration
			startx3 = 1 + ((n+1)+T)*16	#current x value
				
			startv1 = 1+(T+n+(T-2))*16 	#n = number of v variables before v1 ,T = number of keys and (T-2) = number of x-variables
			startv2 = 1+(T+(n+1)+(T-2))*16 	#n+1 = number of v variables before v2 ,T = number of keys and (T-2) = number of x-variables	

			# System 2
			starty1 = 1 + ((n-1)+T+2*(T-2))*16	#y value two iterations ago
			starty2 = 1 + (n+T+2*(T-2))*16		#y value in previouse iteration
			starty3 = 1 + ((n+1)+T+2*(T-2))*16	#current y value
				
			startvy1 = 1 + (n+T+3*(T-2))*16 	#n = number of v variables before v1 ,T = number of keys and (T-2) = number of y- and x-variables
			startvy2 = 1 + ((n+1)+T+3*(T-2))*16 	#n+1 = number of v variables before v2 ,T = number of keys and (T-2) = number of y- and x-variables

			# System 3
			startz1 = 1 + ((n-1)+T+4*(T-2))*16	#z value two iterations ago
			startz2 = 1 + (n+T+4*(T-2))*16		#z value in previouse iteration
			startz3 = 1 + ((n+1)+T+4*(T-2))*16	#current z value
				
			startvz1 = 1 + (n+T+5*(T-2))*16 	#n = number of v variables before v1 ,T = number of keys and (T-2) = number of z-, y- and x-variables
			startvz2 = 1 + ((n+1)+T+5*(T-2))*16 	#n+1 = number of v variables before v2 ,T = number of keys and (T-2) = number of z-, y- and x-variables


			for i in range(16):
				kn = i+startkn
				kn2 = i+startkn2
				kn3 = i+startkn3
				# System 1
				x1 = i+startx1
				x2 = i+startx2
				x3 = i+startx3
				s1x2 = leftshift(x2,1,startx2)
				s2x2 = leftshift(x2,2,startx2)
				s8x2 = leftshift(x2,8,startx2)
				s1x3 = leftshift(x3,1,startx3)
				s2x3 = leftshift(x3,2,startx3)
				s8x3 = leftshift(x3,8,startx3)
				v1 = i+startv1
				v2 = i+startv2
	    			D4i = (D4>>(15-i))&1^^1
	    			D5i = (D5>>(15-i))&1^^1
				# System 2
				y1 = i+starty1
				y2 = i+starty2
				y3 = i+starty3
				s1y2 = leftshift(y2,1,starty2)
				s2y2 = leftshift(y2,2,starty2)
				s8y2 = leftshift(y2,8,starty2)
				s1y3 = leftshift(y3,1,starty3)
				s2y3 = leftshift(y3,2,starty3)
				s8y3 = leftshift(y3,8,starty3)
				vy1 = i+startvy1
				vy2 = i+startvy2
	    			N4i = (N4>>(15-i))&1^^1
	    			N5i = (N5>>(15-i))&1^^1
				# System 3
				z1 = i+startz1
				z2 = i+startz2
				z3 = i+startz3
				s1z2 = leftshift(z2,1,startz2)
				s2z2 = leftshift(z2,2,startz2)
				s8z2 = leftshift(z2,8,startz2)
				s1z3 = leftshift(z3,1,startz3)
				s2z3 = leftshift(z3,2,startz3)
				s8z3 = leftshift(z3,8,startz3)
				vz1 = i+startvz1
				vz2 = i+startvz2
	    			M4i = (M4>>(15-i))&1^^1
	    			M5i = (M5>>(15-i))&1^^1

			# Add clauses for system 1
	    			cms.add_xor_clause((kn,x3,x1,v1,s2x2),D3i)
	    			cms.add_clause((v1,-1*s1x2,-1*s8x2))
	    			cms.add_clause((-1*v1, s1x2))
	   			cms.add_clause((-1*v1, s8x2))

	    			cms.add_xor_clause((kn2, x2, v2, s2x3), D4i)
	    			cms.add_clause((v2,-1*s1x3,-1*s8x3))
	    			cms.add_clause((-1*v2, s1x3))
	    			cms.add_clause((-1*v2, s8x3))

	    			cms.add_xor_clause((x3,kn3), D5i)


			# Add clauses for system 2
	    			cms.add_xor_clause((kn,y3,y1,vy1,s2y2),N3i)
	    			cms.add_clause((vy1,-1*s1y2,-1*s8y2))
	    			cms.add_clause((-1*vy1, s1y2))
	   			cms.add_clause((-1*vy1, s8y2))

	    			cms.add_xor_clause((kn2, y2, vy2, s2y3), N4i)
	    			cms.add_clause((vy2,-1*s1y3,-1*s8y3))
	    			cms.add_clause((-1*vy2, s1y3))
	    			cms.add_clause((-1*vy2, s8y3))

	    			cms.add_xor_clause((y3,kn3), N5i)

			# Add clauses for system 3
	    			cms.add_xor_clause((kn,z3,z1,vz1,s2z2),M3i)
	    			cms.add_clause((vz1,-1*s1z2,-1*s8z2))
	    			cms.add_clause((-1*vz1, s1z2))
	   			cms.add_clause((-1*vz1, s8z2))

	    			cms.add_xor_clause((kn2, z2, vz2, s2z3), M4i)
	    			cms.add_clause((vz2,-1*s1z3,-1*s8z3))
	    			cms.add_clause((-1*vz2, s1z3))
	    			cms.add_clause((-1*vz2, s8z3))

	    			cms.add_xor_clause((z3,kn3), M5i)

				if n>2:
					k1 = i+startk1
					k2 = i+startk2
					k4 = i+startk4
	    				r3k4 = rightshift(k4,3,startk4)
	    				r4k4 = rightshift(k4,4,startk4)
	    				r1k2 = rightshift(k2,1,startk2)				
					D6i = (roundConstant1>>(15-i)&1)
					N6i = (roundConstant1>>(15-i)&1)
					M6i = (roundConstant1>>(15-i)&1)
			# Add clauses for system 1			
					cms.add_xor_clause((kn,k1,k2,r3k4,r1k2,r4k4),D6i)
			# Add clauses for system 2
					cms.add_xor_clause((kn,k1,k2,r3k4,r1k2,r4k4),N6i)
			# Add clauses for system 3
					cms.add_xor_clause((kn,k1,k2,r3k4,r1k2,r4k4),M6i)
					
				if n>1:
					k1n2 = i+startk1n2
					k2n2 = i+startk2n2
					k4n2 = i+startk4n2
	    				r3k4n2 = rightshift(k4n2,3,startk4n2)
	    				r4k4n2 = rightshift(k4n2,4,startk4n2)
	    				r1k2n2 = rightshift(k2n2,1,startk2n2)				
					D6in2 = (roundConstant2>>(15-i)&1)
					N6in2 = (roundConstant2>>(15-i)&1)
					M6in2 = (roundConstant2>>(15-i)&1)
			# Add clauses for system 1			
					cms.add_xor_clause((kn2,k1n2,k2n2,r3k4n2,r1k2n2,r4k4n2),D6in2)
			# Add clauses for system 2
					cms.add_xor_clause((kn2,k1n2,k2n2,r3k4n2,r1k2n2,r4k4n2),N6in2)
			# Add clauses for system 3
					cms.add_xor_clause((kn2,k1n2,k2n2,r3k4n2,r1k2n2,r4k4n2),M6in2)
					

				if n>0:
					k1n3 = i+startk1n3
					k2n3 = i+startk2n3
					k4n3 = i+startk4n3
	    				r3k4n3 = rightshift(k4n3,3,startk4n3)
	    				r4k4n3 = rightshift(k4n3,4,startk4n3)
	    				r1k2n3 = rightshift(k2n3,1,startk2n3)			
					D6in3 = (roundConstant3>>(15-i)&1)
					N6in3 = (roundConstant3>>(15-i)&1)
					M6in3 = (roundConstant3>>(15-i)&1)
			# Add clauses for system 1
					cms.add_xor_clause((kn3,k1n3,k2n3,r3k4n3,r1k2n3,r4k4n3),D6in3)
			# Add clauses for system 2
					cms.add_xor_clause((kn3,k1n3,k2n3,r3k4n3,r1k2n3,r4k4n3),N6in3)
			# Add clauses for system 3
					cms.add_xor_clause((kn3,k1n3,k2n3,r3k4n3,r1k2n3,r4k4n3),M6in3)
	start = time.time()	
	solution = cms()
	end = time.time()
	etime = end-start
	return etime;
input = []
list1 = []
for n in range(100):
	input = []
	cms = CryptoMiniSat()
		# First equation (c1=Ex(P1)), refered to as system 1
	text1 = [(randint(0, 2**16)),(randint(0, 2**16))]

		# Second equation (c2=Ex(P2)), refered to as system 2
	text2 = [(randint(0, 2**16)), (randint(0, 2**16))]

		# Third equation (c3=Ex(P3)), refered to as system 3
	text3 = [(randint(0, 2**16)), (randint(0, 2**16))]

	valKey = [(randint(0, 2**16)), (randint(0, 2**16)), (randint(0, 2**16)), (randint(0, 2**16))]
		
	roundKeys = keyExp(T, m, z, valKey)
	cipher1 = encryption(roundKeys, [text1[0]], [text1[1]])
	cipher2 = encryption(roundKeys, [text2[0]], [text2[1]])
	cipher3 = encryption(roundKeys, [text3[0]], [text3[1]])
	input.append(text1)
	input.append(cipher1)
	input.append(text2)
	input.append(cipher2)
	input.append(text3)
	input.append(cipher3)
	input.append(T)
	input.append(cms)
	list1.append(tuple(input))

with open('parallelstat7Rounds', 'w') as reader:
	for X, Y in sorted(list(SATsolver(list1))):
		#print X, Y	
		pickle.dump(Y, reader)
reader.closed




	
	




	
	
