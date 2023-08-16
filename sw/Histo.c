// ========================================================================================================
// ========================================================================================================
// ************************************************ Histo.c ***********************************************
// ========================================================================================================
// ========================================================================================================

#include "common.h"


// ===========================================================================================================
// ===========================================================================================================
// ===========================================================================================================
// C algorithm of the function carried out in the hardware

void ComputeHisto(int max_vals, int num_vals, short *vals, short LV_bound, short HV_bound, 
   short DIST_range, short precision_scaler, short *software_histo)
   {
   short LV_addr, HV_addr, LV_set, HV_set;
   int PN_num, bin_num, HISTO_ERR;
   short smallest_val;
   short dist_cnt_sum; 
   int dist_mean_sum;
   short temp_val;
   short range;

// Initialize variables.
   HISTO_ERR = 0;
   dist_mean_sum = 0;

// Clear out the counts in the distribution bins. 
   for ( bin_num = 0; bin_num < DIST_range; bin_num++ )
      software_histo[bin_num] = 0;

// Find smallest value. Then obtain the integer portion (low order 4 bits of the shorts are assumed to be part of the
// fractional component by the hardware -- fixed point floats).
   for ( PN_num = 0; PN_num < num_vals; PN_num++ ) 
      if ( PN_num == 0 )
         smallest_val = vals[PN_num];
      else if ( smallest_val > vals[PN_num] )
         smallest_val = vals[PN_num];
   smallest_val /= precision_scaler;

// Construct the histogram and compute the mean
   for ( PN_num = 0; PN_num < num_vals; PN_num++ ) 
      {

// Add current val to sum for mean calc.
      dist_mean_sum += (int)vals[PN_num];

// Adjust integer portion of vals by subtracting smallest value in the distribution. 
      temp_val = vals[PN_num]/precision_scaler - smallest_val;

//printf("%d) temp_val %d\n", PN_num, temp_val);

// Sanity check.
      if ( temp_val >= DIST_range )
         HISTO_ERR = 1;

      software_histo[temp_val]++; 
      }

// Sweep the histogram and record the address where the lower and higher bounds are exceeded.
   LV_addr = 0;
   HV_addr = 0;
   LV_set = 0;
   HV_set = 0;
   dist_cnt_sum = 0;
   for ( bin_num = 0; bin_num < DIST_range; bin_num++ ) 
      { 
      dist_cnt_sum += software_histo[bin_num]; 

// As soon as the is satisfied the first time, stop updating it.
      if ( LV_set == 0 && dist_cnt_sum >= LV_bound )
         {
         LV_addr = bin_num;
         LV_set = 1;
         }

// Keep updating until the bound is exceeded than stop.
      if ( dist_cnt_sum <= HV_bound )
         { 
         HV_addr = bin_num; 
         HV_set = 1;
         }
      }
   range = HV_addr - LV_addr + 1;

// Error check
   if ( LV_set == 0 || HV_set == 0 )
      HISTO_ERR = 1;

   if ( HISTO_ERR == 1 )
      printf("ERROR: ComputeHisto(): Histo error!\n"); 

   printf("Software Computed Stats: Smallest Val %d\tLV_addr %d\tHV_addr %d\tMean %.4f\tRange %d\n", 
      smallest_val, LV_addr, HV_addr, (float)(dist_mean_sum/num_vals)/precision_scaler, (int)range);
   fflush(stdout);

   return; 
   }


// ========================================================================================================
// ========================================================================================================
// Read integer data from a file and store it in an array.

int ReadData(int max_string_len, int max_data_vals, char *infile_name, short *data_arr_in)
   {
   char line[max_string_len], *char_ptr;
   float temp_float;
   FILE *INFILE;
   int val_num;

   if ( (INFILE = fopen(infile_name, "r")) == NULL )
      { printf("ERROR: ReadData(): Could not open %s\n", infile_name); fflush(stdout);  exit(EXIT_FAILURE); }

   val_num = 0;
   while ( fgets(line, max_string_len, INFILE) != NULL )
      {

// Find the newline and eliminate it.
      if ((char_ptr = strrchr(line, '\n')) != NULL)
         *char_ptr = '\0';

// Skip blank lines
      if ( strlen(line) == 0 )
         continue;

// Sanity check
      if ( val_num >= max_data_vals )
         { printf("ERROR: ReadData(): Exceeded maximum number of vals %d!\n", max_data_vals); fflush(stdout); exit(EXIT_FAILURE); }

// Read and convert value into an integer
      if ( sscanf(line, "%f", &temp_float) != 1 )
         { printf("ERROR: ReadData(): Failed to read an float value from file '%s'!\n", line); fflush(stdout); exit(EXIT_FAILURE); }

// Sanity check
      if ( (int)(temp_float*16) > MAX_SHORT_POS || (int)(temp_float*16) < MAX_SHORT_NEG )
         { printf("ERROR: ReadData(): Scaled float (by 16) larger than max or smaller than min value for short %d!\n", data_arr_in[val_num]); fflush(stdout); exit(EXIT_FAILURE); }

      data_arr_in[val_num] = (int)(temp_float*16);

      val_num++;
      }

   fclose(INFILE);

   return val_num;
   }


// ========================================================================================================
// ========================================================================================================
// Load the data from the data arry into the secure BRAM

void LoadUnloadBRAM(int max_string_len, int max_vals, int num_vals, int load_unload, short *IOData, 
   volatile unsigned int *CtrlRegA, volatile unsigned int *DataRegA, int ctrl_mask)
   {
   int val_num, locked_up;

   for ( val_num = 0; val_num < num_vals; val_num++ )
      {

// Sanity check
      if ( val_num >= max_vals )
         { printf("ERROR: LoadUnloadBRAM(): val_num %d greater than max_vals %d\n", val_num, max_vals); exit(EXIT_FAILURE); }

// Four step protocol
// 1) Wait for 'stopped' from hardware to be asserted
//printf("LoadUnloadBRAM(): Waiting 'stopped'\n"); fflush(stdout);
      locked_up = 0;
      while ( ((*DataRegA) & (1 << IN_SM_HANDSHAKE)) == 0 )
         {
         locked_up++;
         if ( locked_up > 10000000 )
            { 
            printf("ERROR: LoadUnloadBRAM(): 'stopped' has not been asserted for the threshold number of cycles -- Locked UP?\n"); 
            fflush(stdout); 
            locked_up = 0;
            }
         }

// 2) Put data into GPIO (load) or get data from GPIO (unload). Assert 'continue' for hardware
// Put the data bytes into the register and assert 'continue' (OUT_CP_HANDSHAKE).
//printf("LoadUnloadBRAM(): Reading/writing data and asserting 'continue'\n"); fflush(stdout);
      if ( load_unload == 0 )
         *CtrlRegA = ctrl_mask | (1 << OUT_CP_HANDSHAKE) | (0x0000FFFF & IOData[val_num]);

// When 'stopped' is asserted, the data is ready on the output register from the PNL BRAM -- get it.
      else
         {
         IOData[val_num] = (0x0000FFFF & *DataRegA);
         *CtrlRegA = ctrl_mask | (1 << OUT_CP_HANDSHAKE); 
         }

//printf("%d\tData value written or read %d\n", val_num, IOData[val_num]); fflush(stdout);

// 3) Wait for hardware to de-assert 'stopped' 
//printf("LoadUnloadBRAM(): Waiting de-assert of 'stopped'\n"); fflush(stdout);
      while ( ((*DataRegA) & (1 << IN_SM_HANDSHAKE)) != 0 );

// 4) De-assert 'continue'. ALSO, assert 'done' (OUT_CP_LM_ULM_DONE) SIMULTANEOUSLY if last word to inform hardware. 
//printf("LoadUnloadBRAM(): De-asserting 'continue' and possibly setting 'done'\n"); fflush(stdout);
      if ( val_num == num_vals - 1 )
         *CtrlRegA = ctrl_mask | (1 << OUT_CP_LM_ULM_DONE);
      else
         *CtrlRegA = ctrl_mask;
      }

// Handle case where 'num_vals' is 0.
   if ( num_vals == 0 )
      *CtrlRegA = ctrl_mask | (1 << OUT_CP_LM_ULM_DONE);

// De-assert 'OUT_CP_LM_ULM_DONE'
   *CtrlRegA = ctrl_mask;

   fflush(stdout);

   return;
   }


// ========================================================================================================
// ========================================================================================================
// ========================================================================================================

int main(int argc, char *argv[])
   {
   volatile unsigned int *CtrlRegA;
   volatile unsigned int *DataRegA;
   unsigned int ctrl_mask;

   char infile_name[MAX_STRING_LEN];
   char outfile_name[MAX_STRING_LEN];

   short *data_arr_in;
   short *histo_arr_out;
   short *software_histo;
   int num_vals;
   int load_unload;

   int precision_scaler = 16;

   struct timeval t0, t1;
   long elapsed; 

// ======================================================================================================================
// COMMAND LINE
   if ( argc != 2 )
      {
      printf("ERROR: LoadUnload.elf(): Datafile name (test_data_10vals.txt)\n");
      return(1);
      }

   sscanf(argv[1], "%s", infile_name);

// Open up the memory mapped device so we can access the GPIO registers.
   int fd = open("/dev/mem", O_RDWR|O_SYNC);

   if (fd < 0) 
      { printf("ERROR: /dev/mem could NOT be opened!\n"); exit(EXIT_FAILURE); }

// Add 2 for the DataReg (for an offset of 8 bytes for 32-bit integer variables)
   DataRegA = mmap(0, getpagesize(), PROT_READ|PROT_WRITE, MAP_SHARED, fd, GPIO_0_BASE_ADDR);
   CtrlRegA = DataRegA + 2;

// Allocate arrays
   if ( (data_arr_in = (short *)calloc(sizeof(short), MAX_DATA_VALS)) == NULL )
      { printf("ERROR: Failed to calloc data 'data_arr_in' array!\n"); exit(EXIT_FAILURE); }
   if ( (histo_arr_out = (short *)calloc(sizeof(short), MAX_HISTO_VALS)) == NULL )
      { printf("ERROR: Failed to calloc data 'histo_arr_out' array!\n"); exit(EXIT_FAILURE); }
   if ( (software_histo = (short *)calloc(sizeof(short), MAX_HISTO_VALS)) == NULL )
      { printf("ERROR: Failed to calloc data 'histo_arr_out' array!\n"); exit(EXIT_FAILURE); }

// Read the data from the input file
   num_vals = ReadData(MAX_STRING_LEN, MAX_DATA_VALS, infile_name, data_arr_in);

// Set the control mask to indicate enrollment. 
   ctrl_mask = 0;
      
// ==================================================================================
// Software computed values. Hardware reports mean WITH 4 bits of precision but range using ONLY the integer portion.
   gettimeofday(&t0, 0);
   ComputeHisto(MAX_DATA_VALS, num_vals, data_arr_in, (short)LV_BOUND, (short)HV_BOUND, (short)DIST_RANGE, precision_scaler,
      software_histo);
   gettimeofday(&t1, 0); elapsed = (t1.tv_sec-t0.tv_sec)*1000000 + t1.tv_usec-t0.tv_usec; 
   printf("\tSoftware Runtime %ld us\n\n", (long)elapsed);
// ==================================================================================

// Do a soft RESET
   *CtrlRegA = ctrl_mask | (1 << OUT_CP_RESET);
   *CtrlRegA = ctrl_mask;
   usleep(1000);

// Wait for the hardware to be ready -- should be on first check.
   while ( ((*DataRegA) & (1 << IN_SM_READY)) == 0 );

// Start clock
   gettimeofday(&t0, 0);

// Start the VHDL Controller
   *CtrlRegA = ctrl_mask | (1 << OUT_CP_START);
   *CtrlRegA = ctrl_mask;

// Controller expects data to be transferred to the BRAM as the first operation.
   load_unload = 0;
   LoadUnloadBRAM(MAX_STRING_LEN, MAX_DATA_VALS, num_vals, load_unload, data_arr_in, CtrlRegA, DataRegA, ctrl_mask);

// Data transfer in time
   gettimeofday(&t1, 0); elapsed = (t1.tv_sec-t0.tv_sec)*1000000 + t1.tv_usec-t0.tv_usec; 
   printf("\tHardware Transfer In time %ld us\n\n", (long)elapsed);

// Start clock
   gettimeofday(&t0, 0);

// Wait for 'stopped' to be asserted by hardware. When this occurs, histogram FSM is finished and its ready to transfer
// data out.
   while ( ((*DataRegA) & (1 << IN_SM_HANDSHAKE)) == 0 );

// Approx. runtime of hardware excluding I/O
   gettimeofday(&t1, 0); elapsed = (t1.tv_sec-t0.tv_sec)*1000000 + t1.tv_usec-t0.tv_usec; 
   printf("\tHardware Runtime %ld us\n\n", (long)elapsed);

// Check for a HISTO error 
   if ( ((*DataRegA) & (1 << IN_SM_HISTO_ERR)) == 1 )
      { printf("ERROR: Histogram error!\n"); exit(EXIT_FAILURE); }

// Start clock
   gettimeofday(&t0, 0);

// After computing the histogram, Controller expects to transfer histogram memory and distribution parameters back to C program
   load_unload = 1;
   LoadUnloadBRAM(MAX_STRING_LEN, MAX_HISTO_VALS, MAX_HISTO_VALS, load_unload, histo_arr_out, CtrlRegA, DataRegA, ctrl_mask);

// Data transfer out time
   gettimeofday(&t1, 0); elapsed = (t1.tv_sec-t0.tv_sec)*1000000 + t1.tv_usec-t0.tv_usec; 
   printf("\tHardware Transfer Out time %ld us\n\n", (long)elapsed);

// ==================================================================================
// Print out the histogram. The mean and range are the last two values (of the 2048).
   int i;
   printf("HISTOGRAM VALUES:\n");
   for ( i = 0; i < MAX_HISTO_VALS - 2; i++ )
      {
      printf("(%4d) %3d  ", i, histo_arr_out[i]);
      if ( ((i+1) % 10) == 0 )
         printf("\n");

// Sanity check. Both the hardware and software histogram should be identical.
      if ( histo_arr_out[i] != software_histo[i] )
         {
         printf("ERROR: Mismatch between hardware %d and software %d histos at index %d\n", 
            histo_arr_out[i], software_histo[i], i); exit(EXIT_FAILURE); 
         }
      }
   printf("\n\n");


// Write out an xy file with histogram data for histogram plotting with R. Assumes the input file is "yyy.txt"
   FILE *OUTFILE;
   char temp_str[MAX_STRING_LEN];

   strcpy(temp_str, infile_name);
   temp_str[strlen(infile_name) - 3]  = '\0';

   strcpy(outfile_name, "Output_");
   strcat(outfile_name, temp_str);
   strcat(outfile_name, "xy");
   
   if ( (OUTFILE = fopen(outfile_name, "w")) == NULL )
      { printf("ERROR: ReadData(): Could not open %s\n", outfile_name); exit(EXIT_FAILURE); }
   for ( i = 0; i < MAX_HISTO_VALS - 2; i++ )
      fprintf(OUTFILE, "%d\t%d\n", i, histo_arr_out[i]);
   fclose(OUTFILE);


   printf("Hardware Computed Mean %.4f\tRange %d\n", 
      (float)histo_arr_out[MAX_HISTO_VALS-2]/precision_scaler, histo_arr_out[MAX_HISTO_VALS-1]);
// ==================================================================================

// Check if Controller returned to idle
   if ( ((*DataRegA) & (1 << IN_SM_READY)) == 0 )
      { printf("ERROR: Controller did NOT return to idle!\n"); exit(EXIT_FAILURE); }

   return 0;
   } 