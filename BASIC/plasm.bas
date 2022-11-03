10 for y=0 to 24-1
20 for x=0 to 60-1
30 val=sin(1.24*sin(x*0.3+y*0.1)+sin(x*0.02+y*0.37)+3*sin(x*0.15+y*0.08)+1.8*sin(x*0.139+y*0.265))
40 if val < 0.25 then print "*"; else print " ";
50 next x
60 print
70 next y