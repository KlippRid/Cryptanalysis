#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <time.h>
#include <math.h>


uint64_t z[5] = {0b11111010001001010110000111001101111101000100101011000011100110,
                0b10001110111110010011000010110101000111011111001001100001011010,
                0b10101111011100000011010010011000101000010001111110010110110011,
                0b11011011101011000110010111100000010010001010011100110100001111,
                0b11010001111001101011011000100000010111000011001010010011101111};


//------------HELP FUNCTIONS----------------------------------------------------------

#define rotleft16(num, shift) ((( (num) <<  shift) | ( (num) >> ( 16 - shift))) & 0xFFFF)
#define rotright16(num, shift) ((( (num) >>  shift) | ( (num) << ( 16 -  shift))) & 0xFFFF)
#define feistel(num) ((rotleft16(num, 1)&rotleft16(num, 8))^rotleft16(num, 2))


// Function to prevent sliding effects used in key expansion:
// Input parameters:
// i = index to update which bit in vector z should be used.
// j = index for vector z (sliding constant), for SIMON32/64 choose first vector (j[0], i = 0).
// m = number of words in main key.
uint64_t scramble(int i, int j, int m) {

    uint64_t x = (z[j]>>((62-(i-m+1))%62))&1;
    return x;
}

// Expandes main key which is m words long into T words/ sub keys, i.e. same amount as number of rounds.
// Input parameters:
// mainKey = main key, m words (16-bit long per word (64 bits in total).
// T = number of rounds.
// m = word size for main key.
// j = sliding constant, 64 bit long.
void keyExpansion(uint16_t *mainKey, const int T, const int m, const int j) {
    // Set random value to the m 16-bit words in the mainKey.
    srand((unsigned)time(0));
    int i;
    for (i=0; i< m; i++) {
        mainKey[i] = rand();
        printf("%04x\n", mainKey[i]);
    }
    // Expand the key to T subkeys in total.
    uint16_t tmp;
    for (i = m; i < T; i++) {
        tmp = rotright16(mainKey[i-1], 3);
        if (m == 4) {
            tmp = tmp^mainKey[i-3];
        }
        tmp = tmp ^ (rotright16(tmp,1));
        uint64_t x = scramble(i, j, m);
        mainKey[i] = ~mainKey[i-m]^tmp^x^3;
        printf("%04x\n", mainKey[i]);
    }

}

//-------------------------------------------Encryption----------------------------------------------
// Creates a roundreduced version of SIMON32.
// Input parameters:
// nrounds = number of rounds.
// keyInput = expanded key.
// ptext = plaintext.
// ctext = ciphertext.
void encryption(const int nrounds, const uint16_t * keyInput, const uint16_t * ptext, uint16_t * ctext ) {
    uint16_t tmp, r1, r8, r2;
    ctext[0] = ptext[0];
    ctext[1] = ptext[1];
    int i;
    for (i = 0; i < nrounds; i++) {
        tmp = ctext[0];
        r1 = rotleft16(ctext[0], 1);
        r8 = rotleft16(ctext[0], 8);
        r2 = rotleft16(ctext[0], 2);
        ctext[0] = ctext[1]^(r1&r8)^r2^keyInput[i];
        ctext[1] = tmp;
    }
}

// Example of key recovery attack for differential (0100||0000 ---> 0100||0100) after r rounds.
// OBS! This attack will recover bits if the key NOT the whole key.


//          p[0], p'[0] = p[0](x)aL                     p[1], p'[1] = p[1](x)aR
//
//       aL = input diff_left                   aR = input diff_right
//                 |                                      |
//                 ------[Round function f()]----DELTA-----
//                 |                                      |
//                 .                                      .
//                 .                                      .    int tmp = 0;

//                 .                                      .
//
// bL = output diff_left(r-rounds) = 0100        bR = output diff_right(r-rounds) = 0100
//                 |                                      |
//                 |                                      |
//                 ------[Round function f()]----DELTA-----  DELTA = 0000 01*0 0000 000*
//                 |                                      |
//                  \.................SWAP.............../    int tmp = 0;

//                 |                                      |
//                 |                                      |
//                 ------[Round function f()]------------(X)<---K
//                 |                                      |
//                  \.................SWAP.............../
//                 |                                      |
//               cL, c'L                               cR, c'R      (r+2 rounds)
//
//
// The key with highest count is the most likely candidate for true key value.
// 1. Test all plaintextt pairs with difference e.g. aL = 0100 and aR = 0000.

    // 2. If output difference f(cR)(x)f(c'R)(x)cL(x)c'L = bL and  cR(x)c'R = 0000 01*1 0000 000* (bR(x)DELTA = deltaXbR):

        // 3. Try all possible key values that are active for the specific differential to test if they give back bR.
        //    NOTE: The active key bits are dictaded by DELTA.
        //    bR = DELTA (x) cR (x) c'R     (1)
        //    DELTA = f(cL (x) K (x) f(cR)) (x) f(c'L (x) K (x) f(c'R))     (2)
        //    Equation (1) and (2) gives
        //    bR =   f(cL (x) K (x) f(cR)) (x) f(c'L (x) K (x) f(c'R)) (x) cR (x) c'R       (3)
        //    It only the key bits that result in the unknown DELTA bits (* = {0, 9}) that are intresting.
        //    In this case K1 and K15. (Derived from Equation (3) for DELTA-bit 0 and DELTA-bit 9.

// 4. If key bits match and give back bR increase count for those key bits.


//------------------------------------------------------------------------------------
//int criterion(uint16_t cR, uint16_t cRprim) {
//    int tmp = 0;
//    //0*01 *001 *000 0*00; delta to compare against
//    int i;
//    uint16_t deltacR = cR^cRprim;
//    if (((deltacR >> 8)&1 )== 1 && ((deltacR>>12)&1)== 1){
//        for ( i = 0; i<16; i++){
//
//        if (i != 2 && i!= 7 && i!=8 && i!= 11 && i!=12 && i!= 14){
//            if (((deltacR >> i) &1) == 0) {
//                tmp +=1;
//            }
//        }
//
//        }
//
//
//    }
//
//
//
//return tmp;
//}


int main()
{
//Variables
int i, j, k; // iteration indexes.
uint16_t cL, cLprim, pL, pLprim, cR, cRprim, pR, pRprim, u, uprim; //plaintext and ciphertext pairs.
uint16_t cR2, cR7, cR11, cR14, u9, u13, u7, u11, b1, b5, b8, b12;
uint16_t p[2], pprim[2], c[2], cprim[2];
int m = 4;
int T = 10; // number of rounds with two additional rounds at bottom (i.e. r + 2)
uint16_t key[10]; // round keys (9 in total)
uint16_t aL = 0x0001;
uint16_t aR = 0x0000;
uint16_t bL = 0x0011;
uint16_t Delta = 0b0000000000010001;
uint16_t mask = 0b1110111011011101;
//uint16_t bR = 0x0000;
//int test;

int count[16]; // Counts the different key bit combinations ({0,0},{0,1},{1,0},{1,1}).
for (i=0; i<=0xf; i++){
    count[i] = 0;
}
int totCount = 0;
int totCountBL = 0;
keyExpansion(key,T,m,0); // populate the round keys (uses srand() for the m first keys)
for (i = 0; i <= 0xffff; i++) {
    // Initialize plaintext
    pL = (uint16_t) i & 0xffff;
    p[0] = pL;
    pLprim = pL^aL;
    pprim[0] = pLprim;
    if (pL & aL) { // Don't count twise
        for (j = 0; j<= 0xffff; j++) {
            // Initialize plaintext
            pR = (uint16_t) j & 0xffff;
            p[1] = pR;
            pRprim = pR^aR;
            pprim[1] = pRprim;
            encryption(T, key, p, c);
            encryption(T, key, pprim, cprim);
            cL = c[0];
            cR = c[1];
            cLprim = cprim[0];
            cRprim = cprim[1];
            u = feistel(cR)^cL;
            uprim = feistel(cRprim)^cLprim;
            //printf("Delta = %04x\n", Delta);

            //printf("mask = %04x\n", ((cR^cRprim)&mask));

            if ((u^uprim) == bL) { // Check first condition (see description 2.)
                totCountBL += 1;

                if (((cR^cRprim)&mask) == Delta) { // Check second condition (see description 2.)
                    totCount += 1;
                    //printf("h");
                    cR2 = (((cR^cRprim)>>1)&1);
                    cR7 = (((cR^cRprim)>>5)&1);
                    cR11 = (((cR^cRprim)>>8)&1);
                    cR14 = (((cR^cRprim)>>12)&1);
                    u9 = ((u)>>9)&1;
                    u13 = ((u)>>13)&1;
                    u7 = ((u)>>7)&1;
                    u11 = ((u)>>11)&1;

                    for ( k=0; k<=0xf; k++) { // 16 different key bit combinations
                        b1 = cR2 ^ u9 ^ (k&1); // Test active key bit 1
                        b5 = cR7 ^ u13 ^ ((k>>1)&1); // Test active key bit 0
                        b8 = cR11 ^ u7 ^ ((k>>2)&1); // Test active key bit 3
                        b12 = cR14 ^ u11 ^ ((k>>3)&1); // Test active key bit 13
                        if ( b1 == 0 &&  b5 == 0 && b8 == 0 && b12 == 0){ // Check if equation 3 is fulfilled for unknown bits in DELTA.
                            count[k] += 1; // Increase count on the specific combination of key bits 1 and 15.
                        }

                    }

                }
            }

        }
    }

}

printf("Results from key recovery attack\n");
uint16_t correct;
correct = ((key[T-1]>>9)&1) ^ (((key[T-1]>>13)&1)<<1) ^ (((key[T-1]>>7)&1)<<2) ^ (((key[T-1]>>11)&1)<<3);
printf("key %04x gives right key bits are k9 = %d, k13 = %d, k7 = %d and k11 = %d\n", key[T-1], (int) (key[T-1]>>9)&1, (int) (key[T-1]>>13)&1, (int) (key[T-1]>>7)&1, (int) (key[T-1]>>11)&1);
for (i=0; i<=0xf;i++){
        printf("For key bit combination %04x, the count is %d\n", (uint8_t) i ,count[i]);

}
printf("The total count for passing first test is %d\n", totCountBL);
printf("The total count for passing second test is %d\n", totCount);
printf("Correct key %04x has %d count", correct, count[((int)correct)]);

    return 0;
}
