# Differential and Algebraic Cryptanalysis
 This repository consists of three parts:
 1. parallellAlgebraicAttacks.sage contains the complete algebraic attack on SIMON32.
 2. branchAndBound.c contains two parts; part one creates a DDT and part two is a branch and bound search that uses the DDT to     find a differential.
 3. keyRecoveryAttack.c contains the differential attack by using a differential that can be derived with the branchAndBound       file.

for more details on lightweight crypto SIMON32 and how these attacks were derived [Master Thesis](http://uu.diva-portal.org/smash/record.jsf?pid=diva2%3A892307&dswid=1934)
