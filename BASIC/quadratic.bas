10 PRINT "*** Quadratic equation ***"
20 PRINT "AX^2 + BX + C = 0"
30 INPUT "A, B, C: ";A,B,C
40 D=B^2-4*A*C
45 PRINT "D = ";D
50 IF D < 0 THEN PRINT "Negative discriminant => No solution!" : GOTO 100
60 X1=(-B+SQRT(D))/(2*A)
70 X2=(-B-SQRT(D))/(2*A)
80 PRINT "X1 = ";X1
90 PRINT "X2 = ";X2
100 PRINT "End program"

