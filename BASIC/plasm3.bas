5 v=0
10 for y=0 to 24-1
20 for x=0 to 60-1
30 val=0.5*sin(v+1.24*sin(x*0.3+y*0.1)+sin(x*0.02+y*0.37)+3*sin(x*0.15+y*0.08)+1.8*sin(x*0.139+y*0.265))+0.5
100 if val >= 0.0 then if val < 0.25 then print " ";
110 if val >= 0.25 then if val < 0.5 then print ".";
120 if val >= 0.5 then if val < 0.75 then print "*";
130 if val >= 0.75 then if val <= 1 then print "#";
200 next x
210 print
220 next y
230 v=v+0.3
240 sleep 300
250 goto 10