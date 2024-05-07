#include <stdio.h>
#include "util.h"
#include "../maple/api/dcp_maple.h"
#include "../maple/tests/data/matmul_data.h"

#define NUM_WORDS 16
static uint64_t A,D;
static uint32_t Dp[2] = {0x000000FF,0x000000AA};
static uint32_t Ap[NUM_WORDS] = {0x33221100,
                                                 0x77665544,
                                                 0xBBAA9988,
                                                 0xFFEEDDCC,
                                                 0x11111111,
                                                 0x22222222,
                                                 0x33333333,
                                                 0x44444444,
                                                 0x55555555,
                                                 0x66666666,
                                                 0x77777777,
                                                 0x88888888,
                                                 0x99999999,
                                                 0xAAAAAAAA,
                                                 0xBBBBBBBB,
                                                 0xCCCCCCCC};


#ifndef NUM_A
    #define NUM_A 1
#endif

void _kernel_(uint32_t id, uint32_t core_num){
    // Setup and send data to the accelerator
    custom_acc_write(0,10,10); 
    //custom_acc_read(0,5);
    //print64("Init Confirm",custom_acc_read(0,15));
    for (uint32_t i = 0; i < 8; i++) {
        for (uint32_t j = 0; j < 8; j++) {
            custom_acc_write(0,11, A_data[i][j]); 
            //custom_acc_read(0,5);
            // print64("Fill A",custom_acc_read(0,15));
            custom_acc_write(0,12, B_data[i][j]); 
            //custom_acc_read(0,15);
            // print64("Fill B",custom_acc_read(0,15));
        }
    }

    // Perform Multiplication
    custom_acc_write(0,25,0); 
    // custom_acc_read(0,5);
    //print64("Multiply Confirm",custom_acc_read(0,5));
    
    // Read Result
      for (uint32_t i = 0; i < 8; i++) {
        for (uint32_t j = 0; j < 8; j++) {
            custom_acc_write(0,13,0); 
            //custom_acc_read(0,13);
            print64("Result:",custom_acc_read(0,15));
        }
    }
}

int main(int argc, char ** argv) {
    volatile static uint32_t amo_cnt = 0;
    uint32_t id, core_num;
    id = argv[0][0];
    core_num = argv[0][1];
    printf("ID: %d-%d\n", id,core_num);
    if (id == 0) init_tile(NUM_A);
    ATOMIC_OP(amo_cnt, 1, add, w);
    while(core_num != amo_cnt);
    _kernel_(id,core_num);
    return 0;
}
