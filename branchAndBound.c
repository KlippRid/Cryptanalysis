#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <time.h>
#include <math.h>

//------------HELP FUNCTIONS----------------------------------------------------------

#define rotleft16(num, shift) ((( (num) <<  shift) | ( (num) >> ( 16 - shift))) & 0xFFFF)
#define rotright16(num, shift) ((( (num) >>  shift) | ( (num) << ( 16 -  shift))) & 0xFFFF)
#define equation(x, alfa) ((x[0]&x[1])^((x[0])^alfa)&((x[1])^(rotleft16(alfa, 7))))




int main()
{


//------------------------DDT-----------------------------------------

 uint16_t a, b, alfa, gamma, gamma1, gamma2, gamma3, gamma4;
    uint16_t node1[2] = {0, 0}; // First xi,xn-r node {0,0}
    uint16_t node2[2] = {0, 0xffff}; // Second xi,xn-r node {0,1}
    uint16_t node3[2] = {0xffff, 0}; // Third xi,xn-r node {1,0}
    uint16_t node4[2] = {0xffff, 0xffff}; // Forth xi,xn-r node {1,1}
    int i, j, k, h, t;
    uint8_t z;
    uint8_t lookup[65536+1] = {0}; // Lookup table for counts, each stored value is a unsigned exponant to the base 2.
    lookup[0] = 100; // if 0 count set exponent to 100.
    lookup[1] = 16; // 1 count equals 1/2^16.
    j = 1;
    for (i = 1; i < 17; i++) {
        j = 2*j;
        lookup[j] = (16-i);
    }
    uint8_t *Table1; // Table that stores the p_D for each input a and output b difference combination.
    Table1 = (uint8_t *)malloc(0xffffffff* sizeof(uint8_t)); // Stored value is the exponent that represents the count for a||b (see variable lookup).
    if(Table1 == 0) {
        printf("ERROR: Out of memory\n");
        return 1;

    //printf("done");
    }

    uint32_t c; // c = a||b, concatinated value of a and b.

    for (i=0; i<=0xffff; i++){
        a = (uint16_t) i&0xffff; // Input difference.

        alfa = rotleft16(a, 1)&0xffff; // Input difference rotated 1 bit to the left.

       for(j=0; j<=0xffff; j++){
            b = (uint16_t)j&0xffff; // Output difference.
            c = ((uint32_t)a << 16) | b;
            int totCount = 0;
            for (t= 0; t<4; t++){ // Only activate one initial node at a time to count the paths and later sum them up to give the total count totCount.
                gamma = b^(rotleft16(a,2))&0xffff; // Value that each node in the path should be equal to.
                gamma1 = equation(node1, alfa)&0xffff; // Value for node 1 to bitwise compare against gamma (above).
                gamma2 = equation(node2, alfa)&0xffff; // Value for node 2 to bitwise compare against gamma (above).
                gamma3 = equation(node3, alfa)&0xffff; // Value for node 3 to bitwise compare against gamma (above).
                gamma4 = equation(node4, alfa)&0xffff; // Value for node 4 to bitwise compare against gamma (above).
                int active[4] = {0,0,0,0}; // Indicates the nodes activated in the prevouse iteration.
                int count[4] = {0,0,0,0}; // Keeps track on the number of counts for the current iteration.
                int temp[4] = {0,0,0,0}; // Temporary variable used to refreah "active" and "count" values after each node step.
                if (t==0) {
                    if ((gamma&1) == (gamma1&1)) {
                    active[0] = 1;
                    count[0] = 1;
                    }

                }
                if (t==1) {
                    if ((gamma&1) == (gamma2&1)) {
                        active[1] = 1;
                        count[1] = 1;
                    }

                }
                if (t==2) {
                    if ((gamma&1) == (gamma3&1)) {
                        active[2] = 1;
                        count[2] = 1;
                    }

                }
                if (t==3) {
                    if ((gamma&1) == (gamma4&1)) {
                        active[3] = 1;
                        count[3] = 1;
                    }

                }

                if(active[t]==1){
                    for (k = 0; k<15; k++) {
                        // Shift variables to the right bit which is dictated by the path.
                        gamma = rotright16(gamma, 7);
                        gamma1= rotright16(gamma1, 7);
                        gamma2= rotright16(gamma2, 7);
                        gamma3= rotright16(gamma3, 7);
                        gamma4= rotright16(gamma4, 7);

                        if (active[0] > 0 && active[1] > 0) { // Both node 1 and node 2 are active
                            if ((gamma&1) == (gamma1&1)) {
                                temp[0] = count[0]+count[1]; // Sum the counts from each node from the previouse iteratiom to node 1 in this iteration.

                            }
                            else {
                                temp[0] = 0; // If the element values of gamma and gamma1 is NOT the same set node 1 to 0.
                            }
                            if ((gamma&1) == (gamma3&1)){ // Same as above but for node 3.
                                temp[2] = count[0]+count[1];
                            }
                            else {
                                temp[2] = 0;
                            }
                        }
                        else if (active[0] > 0){ // Only node 1 is active.
                            if ((gamma&1) == (gamma1&1)) {
                                temp[0] = count[0]; // First node activated in prevouse iteration so only its value is summed to node 1.

                            }
                            else {
                                temp[0] = 0; // If the element values of gamma and gamma1 is NOT the same set node 1 to 0.
                            }
                            if ((gamma&1) == (gamma3&1)) { // Same as above but for node 3.
                                temp[2] = count[0];

                            }
                            else {
                                temp[2] = 0;
                            }
                        }
                        else if (active[1] > 0){ // Only node 2 is active.
                            if ((gamma&1) == (gamma1&1)) {
                                temp[0] = count[1];

                            }
                            else {
                                temp[0] = 0;
                            }
                            if ((gamma&1) == (gamma3&1)) {
                                temp[2] = count[1];

                            }
                            else {
                                temp[2] = 0;
                            }

                        }
                        else {
                            temp[0] = 0; //Both node 1 and 2 in the previouse iteration are inactive so node 1 and node 3 in this iteration is set to 0.
                            temp[2] = 0;
                        }

                        if (active[2] > 0 && active[3] > 0) { //Same test for node 3 and 4 in the previouse iteration as for node 1 and 2 above.
                            if ((gamma&1) == (gamma2&1)) {
                                temp[1] = count[2] + count[3];
                            }
                            else {
                                temp[1] = 0;
                            }
                            if ((gamma&1) == (gamma4&1)) {
                                temp[3] = count[2] + count[3];

                            }
                            else {
                                temp[3] = 0;
                            }

                        }
                        else if (active[2] > 0){
                            if ((gamma&1) == (gamma2&1)) {
                                temp[1] = count[2];

                            }
                            else {
                                temp[1] = 0;
                            }

                            if ((gamma&1) == (gamma4&1))  {
                                temp[3] = count[2];

                            }
                            else {
                                temp[3] = 0;
                            }
                        }
                        else if (active[3] > 0){
                            if ((gamma&1) == (gamma2&1)) {
                                temp[1] = count[3];

                            }
                            else {
                                temp[1] = 0;
                            }
                            if ((gamma&1) == (gamma4&1)) {
                                temp[3] = count[3];

                            }
                            else {
                                temp[3] = 0;
                            }

                        }
                        else {
                            temp[1] = 0;
                            temp[3] = 0;
                        }

                        for (h = 0; h<4; h++) {
                            active[h] = temp[h]; // Set active to the values of temp.
                            count[h] = temp[h]; // Set count to the values of temp.
                        }


                    }
                    // After going trough the whole path (16 bits = steps) for node t check if the end node equals the starting node (circular path).
                    // If it does, then add the count value for that node to the total count.
                    for (h = 0; h<4; h++) {

                        if (t==0 || t == 2){
                            if (h == 0 || h == 1) {
                                totCount = totCount + count[h];

                            }

                        }
                        if (t==1 || t == 3){
                            if (h == 2 || h == 3) {
                                totCount = totCount + count[h];

                            }

                        }

                    }


                }

            }


        z = lookup[totCount]; // Convert counted paths to exponent with lookup table.
        if (a==(0xa008&0xffff) && b==(0xc0a3&0xffff)){
            printf("For a = %04x and b =  %04x , the total count is: %d and z = %d\n", a, b, totCount, z);

        }

        Table1[c] = z; // Store value in DDT for each input/output difference.


        }

    }
    printf("DDT is finished");











//---------------------Branch & Bound---------------------------------------------------------------

FILE *f = fopen("BB1.txt", "w");
if (f == NULL)
{
    printf("Error opening file!\n");
    exit(1);
}










    //Initialize variables

    uint8_t testLimits[12] = {3, 3, 5, 3, 7, 5, 7, 3, 5, 3, 3, 1}; //Limits from paper but with limit = limit +1.
    uint8_t limits[33]; // Holds the accumulated threshold value for each depth of the tree.
    limits[0] = 1; //Limits set to first limit from paper +1.
    for (i = 1; i < 33; i++) {
        if (i<13) {
            limits[i] = limits[i-1]+testLimits[i-1];
        }
        else {
            limits[i] = 0; // Ensures that the tree is stopped at depth 15
        }

    }
    uint32_t pos[33] = {0}; // Indicates the position in the tree, i.e. pos = b.

    //Store differential probability for each level:
    double DP[32][33];// First element is a||b in the form of hamming weight position, the second element is the depth.
    //Initialize DP values to 0.
    for (i =0; i<33; i++){
        for (j = 0; j < 32; j++){
            DP[j][i] = 0;
        }
    }

    uint32_t left, right, output; // Output difference (left and right).
    uint8_t prob[33] = {0}; // Holds the accumulated probability (in the form of an exponent) of the current position (on every level of the tree).
    prob[0] = 1; // Set the dummy variables (alpha[0]) probability to 1.
    uint8_t best[33] = {0}; // Holds the best differential probabilities for every depth.
    int depth = 1; // Current depth in tree.
    double power[51]; // Store the probability (1/2^i) as a lookup table where i is the exponent value stored in prob.
    power[0] = 1;
    for (i = 1; i<51; i++) {
            power[i] = (0.5)*power[i-1];
    }
    int constant[33] = {0}; // Scaling constant for bounding probability.

    // Test all possible characteristics for input differential a||0.
    uint32_t alpha[33] = {0}; //input difference for each depth of the tree.
    alpha[0] = 0x0000; // output variable, i.e. b[0] /deltaR.
    alpha[1] = 0x0040; // input difference, i.e. a[0] /deltaL
    while (pos[0] == 0) { // Loop until you backtracked up to the starting position in the tree.


        // If all subbtrees are tested, move one step up in the tree.
        if (pos[depth] == 0x10000) {
            for (i = depth; i < 33; i++) {
                pos[i] = 0;
            }
            depth -= 1;
            pos[depth] +=1; // add c xor a...
        }
        // Compute the probability of the current node in the tree.
        else {

            prob[depth] = prob[depth-1] + Table1[((uint32_t)alpha[depth] << 16) | pos[depth]];



            // Save the differential probability if the Hammingweight is 1.
            left = (pos[depth]^alpha[depth-1]); // Output difference left hand side after rounds = depth.
            right = alpha[depth]; // Output difference right hand side after rounds = depth.
            // Look for output difference that have a total hammingweight = 1.
            if (left == 0 || right == 0) {
                output = ( left << 16) | right;
                if (output!=0){
                    //printf("Difference %08x\n", output);
                    k=0;  // The position for the bit = 1.
                    while((output&1 ) == 0 && k < 31) {
                        output = output>>1;
                        k = k+1;
                        //printf("%d", k);

                    }
                    //If hammingweight = 1 store probability of the output difference in a differential probability table DP[k][depth].
                    // DP stores the summed probability for all characteristics with the same k (i.e. same ouput difference) for each round (i.e. each depth).
                    if ((output>>1) == 0) {

                        if (prob[depth]<51){ //probabilitys less than (1/2^51) are approximated to 0 and are not stored.
                            DP[k][depth] = DP[k][depth] + power[prob[depth]];
                            fprintf(f, "DP: %.20f, Depth: %d, k: %d\n", DP[k][depth], depth, k);
                        }
                        if (DP[k][depth]>limits[depth]) {
                            printf("DP = %.20f\n", DP[k][depth]);
                            printf("depth = %d\n", depth);
                            printf("Difference %d\n", k);
                            printf("left %08x\n", left);
                            printf("right %08x\n", right);

                        }

                    }
                }
            }

            // Cut off tree if probability is too low.
            if (prob[depth] > limits[depth]){
                //printf("P = %d, limit = %d\n", prob[depth], limits[depth]);
                pos[depth] += 1; //add c xor a...
                //printf("beta %d, depth %d\n", pos[depth], depth);
            }
            // If not too low do:
            else {
            // Check if the current probability is the best so far. In that case update the record of best found
            // differentials and the threshold value for the current depth.

                if (prob[depth] <= best[depth]){
                    best[depth] = prob[depth];
                    limits[depth] = constant[depth] + best[depth]; //kommentera bort när du kör test!!!!!
                }

                // Move down the tree
                alpha[depth+1] = alpha[depth-1]^pos[depth]; // Assign new input difference for next level a[i] = a[i-2] XOR b[i-1].

                depth += 1;
            }
        }


    }
    free(Table1);

    for (i =0; i<33; i++){
        for (j = 0; j < 32; j++){
            if (DP[j][i] != 0) {
                printf("DP for diff %d at depth %d = %f\n", j, i, DP[j][i]);
            }

        }

    }
    fclose(f);
    return 0;
}


