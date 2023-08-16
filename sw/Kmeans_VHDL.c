// ===================================================================================================
// kmeans.c
// Ethan Brodsky
// October 2011
// https://www.medphysics.wisc.edu/~ethan/kmeans/
// Modified by Jim Plusquellic, Sept, 2017.

// This is C source code for a simple implementation of the popular k-means clustering algorithm. It is based 
// on the implementation in Matlab, which was in turn based on GAF Seber, Multivariate Observations, 1964, and 
// H Spath, Cluster Dissection and Analysis: Theory, FORTRAN Programs, Examples.

// The algorithm is based on a two-pass implementation with an iterative "batch update" process occuring in the 
// first pass and an iterative "point by point" update in the second pass. The "point by point" or "online update" 
// process does not seem to be working, but that may just be a consequence of the particular type of datasets I 
// have been working with. It is currently commented out - I welcome feedback on this, especially if somebody 
// managed to fix it.

// This code has currently been tested on a 2D dataset with tens of millions of points being grouped into <10 
// clusters. Note that the max number of clusters and max number of iterations are hard-coded using #define - you 
// may need to change these for your application. 

#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>  
#include <sys/mman.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h> 
#include <netdb.h> 

#include <time.h>
#include <sys/time.h>
#include <math.h>

#define sqr(x) ((x)*(x))
#define MAX_CLUSTERS 100
#define MAX_ITERATIONS 100

// String size
#define MAX_STRING_LEN 2000
#define MAX_SHORT_POS 32767
#define MAX_SHORT_NEG -32768

#define MAX_STRING_VAL 2000
#define MAX_DATA_VALS 4096

// ===================================================================================================
// ===================================================================================================
// Calculate distance. No need for square root -- just watch out for overflow

double CalcDistance(int num_dims, double *p1, double *p2)
   {
   double distance_sq_sum = 0;
   int dim_num;
    
   for ( dim_num = 0; dim_num < num_dims; dim_num++ )
      {
      distance_sq_sum += sqr(p1[dim_num] - p2[dim_num]);

printf("CalcDistance(): Dim Num %d\tP1 %f\tP2 %f\tSum Curr Sqrd Distance %f\n", dim_num, p1[dim_num], p2[dim_num], distance_sq_sum);
      }

   return distance_sq_sum;
   }


// ===================================================================================================
// Calculate the distance values between each point and each centroid across all dimensions dim

void CalcAllDistances(int num_dims, int num_points, int num_clusters, double *points, double *centroids, double *distance_arr)
   {
   int point_num, clust_num;

// For each point and then for each cluster
   for ( point_num = 0; point_num < num_points; point_num++ )
      for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
         {

// Calculate distance between point and cluster centroids
         distance_arr[point_num*num_clusters + clust_num] = CalcDistance(num_dims, &points[point_num*num_dims], &centroids[clust_num*num_dims]);

printf("CalcAllDistances(): Point Num %d\tCluster Num %d\tNum Dims %d\tDistance %f\n", 
   point_num, clust_num, num_dims, distance_arr[point_num*num_clusters + clust_num]); fflush(stdout);
         }
   }


// ===================================================================================================
// Sum the distance between all points and their assigned cluster. NOTE: points with cluster assignment -1 
// are ignored.

double CalcTotalDistance(int num_dims, int num_points, int num_clusters, double *points, double *centroids, 
   int *cluster_assignment_index)
   {
   double tot_D = 0;
   int point_num;
    
// For every point
   for ( point_num = 0; point_num < num_points; point_num++ )
      {

// Get cluster 
      int active_cluster = cluster_assignment_index[point_num];
        
// Sum distance
      if (active_cluster != -1)
         tot_D += CalcDistance(num_dims, &points[point_num*num_dims], &centroids[active_cluster*num_dims]);
      }

printf("CalcTotalDistance(): Total Distance %f\n", tot_D); fflush(stdout);
      
   return tot_D;
   }


// ===================================================================================================
// Find the smallest distance for each point to one of the centroids associated with the clusters.
// Returns an integer array of indexes correlating points to the centroid number.

void FindClosestCentroid(int num_dims, int num_points, int num_clusters, double *distance_array, 
   int *cluster_assignment_index)
   {
   double cur_distance, closest_distance; 
   int point_num, clust_num, best_index;

// For each sample
   for ( point_num = 0; point_num < num_points; point_num++ )
      {
      best_index = -1;
        
// For each cluster
      for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
         {

// Distance between point and cluster centroid
         cur_distance = distance_array[point_num*num_clusters + clust_num];
         if ( clust_num == 0 || cur_distance < closest_distance )
            {
            best_index = clust_num;
            closest_distance = cur_distance;
            }
         }

printf("FindClosestCentroid(): Point Num %d\tclosest to centroid %d\n", point_num, best_index); fflush(stdout);

// Record in array
      cluster_assignment_index[point_num] = best_index;
      }
   }


// ===================================================================================================
// Compute the cluster centroids by summing up all data points in each cluster along each dimension and 
// then dividing through by the number in each cluster.
void CalcClusterCentroids(int num_dims, int num_points, int num_clusters, double *Points, 
   int *cluster_assignment_index, double *new_cluster_centroids)
   {
   int cluster_member_count[MAX_CLUSTERS];
   int clust_num, dim_num, point_num;
   int active_cluster; 

// Sanity check
   if ( num_dims * num_clusters > MAX_CLUSTERS )
      { printf("ERROR: CalcClusterCentroids(): Increase size of 'MAX_CLUSTERS' in program -- must be at least %d\n", num_dims * num_clusters); exit(EXIT_FAILURE); }
  





// Initialize cluster centroid coordinate sums to zero.
   for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
      {
      cluster_member_count[clust_num] = 0;
        
      for ( dim_num = 0; dim_num < num_dims; dim_num++ )
         new_cluster_centroids[clust_num*num_dims + dim_num] = 0;
      }






// Parse all points 
   for ( point_num = 0; point_num < num_points; point_num++ )
      {

// Get current cluster assignment for the data point
      active_cluster = cluster_assignment_index[point_num];

// Update count of members in that cluster
      cluster_member_count[active_cluster]++;
        
// Create sum from each point value in each dimension separately as a mechanism to compute the centroid.
// 'active_cluster' identifies the cluster to which the current point belongs.
      for ( dim_num = 0; dim_num < num_dims; dim_num++ )
         new_cluster_centroids[active_cluster*num_dims + dim_num] += Points[point_num*num_dims + dim_num];
      }
      






// Now divide each sum (in all dimensions) by number of members to find mean/centroid for each cluster
   for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
      {
      if ( cluster_member_count[clust_num] == 0 )
         printf("WARNING: Empty cluster %d! \n", clust_num);
          
// For each dimension, XXXX will divide by zero here for any empty clusters!
      for ( dim_num = 0; dim_num < num_dims; dim_num++ )
         {
         new_cluster_centroids[clust_num*num_dims + dim_num] /= cluster_member_count[clust_num];  

printf("CalcClusterCentroids(): Cluster Num %d\tDimension %d\tMean %f\n", 
   clust_num, dim_num, new_cluster_centroids[clust_num*num_dims + dim_num]); fflush(stdout);
         }
      }
   }


// ===================================================================================================
// Compute total number of points in each cluster using the 'cluster_assignment_index' array.

void GetClusterMemberCount(int num_points, int num_clusters, int *cluster_assignment_index, int *cluster_member_count)
   {
   int clust_num, point_num;

// Initialize cluster member counts
   for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
      cluster_member_count[clust_num] = 0;
  
// Count members of each cluster    
   for ( point_num = 0; point_num < num_points; point_num++ )
      cluster_member_count[cluster_assignment_index[point_num]]++;
   }


// ===================================================================================================
// Print out results. Assumes a 2-D dimension

void ClusterDiag(int num_dims, int num_points, int num_clusters, double *Points, int *cluster_assignment_index, 
   double *cluster_centroids)
   {
   int cluster_member_count[MAX_CLUSTERS];
   int clust_num;

   if ( num_dims != 2 )
      { printf("ERROR: ClusterDiag(): Number of dimensions MUST be 2!\n"); exit(EXIT_FAILURE); }
    
// Get total number of points in each cluster using the 'cluster_assignment_index' array.
   GetClusterMemberCount(num_points, num_clusters, cluster_assignment_index, cluster_member_count);
     
   printf("\nFINAL centroids\n");
   for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
      printf("\tCluster %d: Members: %8d\tCentroid (%.1f %.1f)\n", clust_num, 
         cluster_member_count[clust_num], cluster_centroids[clust_num*num_dims + 0], cluster_centroids[clust_num*num_dims + 1]);
   }


// ===================================================================================================
// Simply makes a copy of the array correlating each point to its closest centroid (given as an index).

void CopyAssignmentArray(int num_vals, int *src, int *tgt)
   {
   int val_num;
   for ( val_num = 0; val_num < num_vals; val_num++)
      tgt[val_num] = src[val_num];
   }
  

// ===================================================================================================
// Simply determines if the number of elements in each cluster has changed, where 'a' is current and
// 'b' is previous counts.

int CheckIfAssignmentCountChanged(int num_vals, int a[], int b[])
   {
   int change_count = 0;
   int val_num;

   for ( val_num = 0; val_num < num_vals; val_num++ )
      if (a[val_num] != b[val_num])
         change_count++;
        
   return change_count;
   }


// ===================================================================================================
// Parameters are dimension of data, pointer to data, number of elements, number of clusters, initial 
// cluster centroids and output.

void KMeans(int num_dims, double *Points, int num_points, int num_clusters, double *cluster_centroids, 
   int *final_cluster_assignment)
   {
   double *distance_arr         = (double *)malloc(sizeof(double) * num_points * num_clusters);
   int *cluster_assignment_cur  = (int *)malloc(sizeof(int) * num_points);
   int *cluster_assignment_prev = (int *)malloc(sizeof(int) * num_points);
   double *point_move_score     = (double *)malloc(sizeof(double) * num_points * num_clusters);
    
   if ( !distance_arr || !cluster_assignment_cur || !cluster_assignment_prev || !point_move_score )
      { printf("ERROR: KMeans(): Error allocating arrays"); exit(EXIT_FAILURE); }
    
printf("\n\nINITIAL\n");

// Calculate the squared distance values between each point and each centroid across all dimensions dim
   CalcAllDistances(num_dims, num_points, num_clusters, Points, cluster_centroids, distance_arr);

// Find the smallest distance for each point to one of the centroids associated with the clusters.
// Returns an integer array of indexes correlating points to the centroid number.
   FindClosestCentroid(num_dims, num_points, num_clusters, distance_arr, cluster_assignment_cur);

// Simply makes a copy of the array correlating each point to its closest centroid (given as an index).
   CopyAssignmentArray(num_points, cluster_assignment_cur, cluster_assignment_prev);

// ==========================================
// BATCH UPDATE
   double prev_totD = 0.0;
   int iteration = 0;
   double totD = 0.0;
   int change_count; 
   while ( iteration < MAX_ITERATIONS )
      {

printf("\n\nIteration %d\n", iteration);
// ClusterDiag(num_dims, n, k, Points, cluster_assignment_cur, cluster_centroids);
        
// Update cluster centroids
      CalcClusterCentroids(num_dims, num_points, num_clusters, Points, cluster_assignment_cur, cluster_centroids);

// Deal with empty clusters, e.g., FORCE a value into the empty cluster or delete the cluster.
// XXXXXXXXXXXXXX

// Determine if we failed to improve. Sum the distance between all points and their assigned cluster. NOTE: points with 
// cluster assignment -1 are ignored.
      totD = CalcTotalDistance(num_dims, num_points, num_clusters, Points, cluster_centroids, cluster_assignment_cur);

// Failed to improve - current solution worse than previous
      if ( iteration != 0 && totD > prev_totD )
         {

// Restore old assignments
         CopyAssignmentArray(num_points, cluster_assignment_prev, cluster_assignment_cur);

// Recalc centroids
         CalcClusterCentroids(num_dims, num_points, num_clusters, Points, cluster_assignment_cur, cluster_centroids);
         printf("Negative progress made on this step (%.2f) -- Done with iterations!\n", totD - prev_totD);

// Done with this phase
         break;
         }
           
// Save previous assignments in '_prev' array.
      CopyAssignmentArray(num_points, cluster_assignment_cur, cluster_assignment_prev);
         
// Re-inspect all points and move them potentially to a new cluster.
      CalcAllDistances(num_dims, num_points, num_clusters, Points, cluster_centroids, distance_arr);
      FindClosestCentroid(num_dims, num_points, num_clusters, distance_arr, cluster_assignment_cur);
         
      change_count = CheckIfAssignmentCountChanged(num_points, cluster_assignment_cur, cluster_assignment_prev);
         
      printf("%3d   %u   %9d  %16.2f %17.2f\n", iteration, 1, change_count, totD, totD - prev_totD);
      fflush(stdout);
         
// Done with this phase if nothing has changed
      if ( change_count == 0 )
         {
         printf("No change made on this step - Done with iterations!\n");
         break;
         }

      prev_totD = totD;
      iteration++;
      }

   ClusterDiag(num_dims, num_points, num_clusters, Points, cluster_assignment_cur, cluster_centroids);

// Save to output array
   CopyAssignmentArray(num_points, cluster_assignment_cur, final_cluster_assignment);    
    
   free(distance_arr);
   free(cluster_assignment_cur);
   free(cluster_assignment_prev);
   free(point_move_score);
   }           


// ========================================================================================================
// Read integer data from a file and store it in an array.

int Read2DData(int max_string_len, int max_data_vals, char *infile_name, short *data_arr_in, int *actual_clusters)
   {
   char line[max_string_len], *char_ptr;
   int cluster_num, cluster_index;
   float x_val, y_val; 
   FILE *INFILE;
   int val_num;

   if ( (INFILE = fopen(infile_name, "r")) == NULL )
      { printf("ERROR: Read2DData(): Could not open %s\n", infile_name); fflush(stdout);  exit(EXIT_FAILURE); }

   val_num = 0;
   cluster_index = 0;
   while ( fgets(line, max_string_len, INFILE) != NULL )
      {

// Find the newline and eliminate it.
      if ((char_ptr = strrchr(line, '\n')) != NULL)
         *char_ptr = '\0';

// Skip blank lines
      if ( strlen(line) == 0 )
         continue;

// Sanity checks
      if ( val_num + 1 >= max_data_vals )
         { printf("ERROR: Read2DData(): Exceeded maximum number of vals %d!\n", max_data_vals); fflush(stdout); exit(EXIT_FAILURE); }
      if ( cluster_index >= max_data_vals )
         { printf("ERROR: Read2DData(): Exceeded maximum number of clusters %d!\n", max_data_vals); fflush(stdout); exit(EXIT_FAILURE); }

// Read and convert value into an integer
      if ( sscanf(line, "%f %f %d", &x_val, &y_val, &cluster_num) != 3 )
         { printf("ERROR: Read2DData(): Failed to read 3-tuple value from file '%s'!\n", line); fflush(stdout); exit(EXIT_FAILURE); }

// Sanity checks
      if ( (int)(x_val*16) > MAX_SHORT_POS || (int)(x_val*16) < MAX_SHORT_NEG )
         { printf("ERROR: Read2DData(): Scaled x_val (by 16) larger than max or smaller than min value for short %f!\n", x_val); fflush(stdout); exit(EXIT_FAILURE); }
      if ( (int)(y_val*16) > MAX_SHORT_POS || (int)(y_val*16) < MAX_SHORT_NEG )
         { printf("ERROR: Read2DData(): Scaled y_val (by 16) larger than max or smaller than min value for short %f!\n", y_val); fflush(stdout); exit(EXIT_FAILURE); }

      data_arr_in[val_num] = (short)(x_val*16);
      data_arr_in[val_num+1] = (short)(y_val*16);
      actual_clusters[cluster_index] = cluster_num;

printf("Read2DData(): Scaled input data at %d is (%d, %d) with actual cluster %d\n", val_num/2, data_arr_in[val_num], data_arr_in[val_num+1], actual_clusters[cluster_index]);

      val_num += 2;
      cluster_index++; 
      }

   fclose(INFILE);

// Divide by 2 since each point is 2-D
   return val_num/2;
   }


// ========================================================================================================
// Just for fun, compute and print the actual centroids based on the classification provided in the data set

int clusters[MAX_CLUSTERS];
double actual_cluster_centroids[MAX_CLUSTERS];
double temp_vals[MAX_DATA_VALS];

int ComputeActualCentroids(int num_points, int max_data_vals, int num_dims, short *points_short, 
   int *actual_clusters)
   {
   int point_num, clust_num, num_clusters, dim_num;

// Find and print unique cluster numbers.
   num_clusters = 0;
   for ( point_num = 0; point_num < num_points; point_num++)
      {
      for ( clust_num = 0; clust_num < num_clusters; clust_num++)
         if ( actual_clusters[point_num] == clusters[clust_num] )
            break;

// Not found, add unique cluster num to array.
      if ( clust_num == num_clusters )
         {
         clusters[num_clusters] = actual_clusters[point_num];
         num_clusters++;
         }
      }

// Sanity check
   if ( num_dims * num_clusters > MAX_CLUSTERS )
      { printf("ERROR: ComputeActualCentroids(): Increase size of 'MAX_CLUSTERS' in program -- must be at least %d\n", num_dims * num_clusters); exit(EXIT_FAILURE); }

// Print out found clusters and re-number them from 0 to num_clusters-1.
   for ( clust_num = 0; clust_num < num_clusters; clust_num++)
      {
      printf("%d) Unique actual cluster num %d -- renumbering to %d\n", clust_num, clusters[clust_num], clust_num);
      for ( point_num = 0; point_num < num_points; point_num++)
         if ( actual_clusters[point_num] == clusters[clust_num] )
            actual_clusters[point_num] = clust_num;
      }

// Convert short to double
   for ( point_num = 0; point_num < 2*num_points; point_num++ )
      temp_vals[point_num] = (double)points_short[point_num];

   CalcClusterCentroids(num_dims, num_points, num_clusters, temp_vals, actual_clusters, actual_cluster_centroids);

// Print out the actual centroid values
   printf("\nACTUAL Centroids\n");
   for ( clust_num = 0; clust_num < num_clusters; clust_num++)
      {
      for ( dim_num = 0; dim_num < num_dims; dim_num++)
         printf("CalcClusterCentroids(): Cluster Num %d\tDimension %d\tMean %f\n", 
            clust_num, dim_num, actual_cluster_centroids[clust_num*num_dims + dim_num]); fflush(stdout);
      }

   return num_clusters;
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


   
   
   
   
   
   
// ===================================================================================================
// ===================================================================================================

int main(int argc, char *argv[])
   {
	   
	volatile unsigned int *CtrlRegA;
	volatile unsigned int *DataRegA;
	unsigned int ctrl_mask;
	
   int num_points, num_dims, num_clusters; 

   double *points, *centroids; 
   int *final_cluster_assignment;

   short *points_short, centroids_short, hw_data;
   int *actual_clusters;

   char infile_name[MAX_STRING_LEN];

   int point_num, dim_num, clust_num, hw_num;

// ======================================================================================================================
// COMMAND LINE
   if ( argc != 3 )
      {
      printf("ERROR: kmeans.elf(): Datafile name (R15) -- number of clusters (2-n)\n");
      return(1);
      }

   sscanf(argv[1], "%s", infile_name);
   sscanf(argv[2], "%d", &num_clusters);
   
   
   
   // Open up the memory mapped device so we can access the GPIO registers.
   int fd = open("/dev/mem", O_RDWR|O_SYNC);

   if (fd < 0) 
      { printf("ERROR: /dev/mem could NOT be opened!\n"); exit(EXIT_FAILURE); }

// Add 2 for the DataReg (for an offset of 8 bytes for 32-bit integer variables)
   DataRegA = mmap(0, getpagesize(), PROT_READ|PROT_WRITE, MAP_SHARED, fd, GPIO_0_BASE_ADDR);
   CtrlRegA = DataRegA + 2;
   

// ================================================
// Parameters
   num_dims = 2;
// ================================================

// Read the data from the input file
   if ( (points_short = (short *)calloc(sizeof(short), MAX_DATA_VALS)) == NULL )
      { printf("ERROR: Failed to allocate data 'points_short' array!\n"); exit(EXIT_FAILURE); }
   if ( (centroids_short = (short *)calloc(sizeof(short), MAX_DATA_VALS)) == NULL )
      { printf("ERROR: Failed to allocate data 'points_short' array!\n"); exit(EXIT_FAILURE); }
   if ( (hw_data = (short *)calloc(sizeof(short), MAX_DATA_VALS*MAX_DATA_VALS)) == NULL )
      { printf("ERROR: Failed to allocate data 'points_short' array!\n"); exit(EXIT_FAILURE); }
    
   if ( (actual_clusters = (int *)calloc(sizeof(int), MAX_DATA_VALS)) == NULL )
      { printf("ERROR: Failed to allocate data 'actual_clusters' array!\n"); exit(EXIT_FAILURE); }
   num_points = Read2DData(MAX_STRING_LEN, MAX_DATA_VALS, infile_name, points_short, actual_clusters);

   if ( ComputeActualCentroids(num_points, MAX_DATA_VALS, num_dims, points_short, actual_clusters) != num_clusters )
      { printf("ERROR: Number of clusters extracted from data file DOES NOT equal number specified on command line!\n"); exit(EXIT_FAILURE); }

   if ((points = (double *)malloc(sizeof(double) * num_points * num_dims)) == NULL )
      { printf("ERROR: Failed to allocate data 'points' array!\n"); exit(EXIT_FAILURE); }
   if ((centroids = (double *)malloc(sizeof(double) * num_dims * num_clusters)) == NULL )
      { printf("ERROR: Failed to allocate data 'centroids' array!\n"); exit(EXIT_FAILURE); }
   if ((final_cluster_assignment  = (int *)malloc(sizeof(int) * num_points)) == NULL )
      { printf("ERROR: Failed to allocate data 'final_cluster_assignment' array!\n"); exit(EXIT_FAILURE); }

  
  
  
   // Set the control mask to indicate enrollment. 
   ctrl_mask = 0;
  
// Convert the short data to double
   for ( point_num = 0; point_num < num_points; point_num++ )
      for ( dim_num = 0; dim_num < num_dims; dim_num++ )
         points[point_num*num_dims + dim_num] = (double)points_short[point_num*num_dims + dim_num];

	 
	 
// Randomly select data points that will serve as the initial guess on the thresholds. NOTE: You MUST define ALL dimensions in 
// the centroids. Individual dimensions are stored consecutatively.
   srand((unsigned) 0);
   for ( clust_num = 0; clust_num < num_clusters; clust_num++ )
      {
      point_num = rand() % num_points;
      for ( dim_num = 0; dim_num < num_dims; dim_num++ )
         {
         centroids[clust_num*num_dims + dim_num] = points[point_num*num_dims + dim_num];
		 centroids_short[clust_num*num_dims + dim_num] = (short)centroids[clust_num*num_dims + dim_num];
         printf("Centroid %d choosen as random point %d with value %f\n", clust_num, point_num, centroids[clust_num*num_dims + dim_num]); 
         }
      }
	  
	  
	  
		CopyAssignmentArray(1, (short)num_vals, hw_data[0]);
		CopyAssignmentArray(1, (short)num_clusters, hw_data[1]);
		CopyAssignmentArray(1, (short)num_dims, hw_data[2]);		
		CopyAssignmentArray(num_points*num_dims, points_short, hw_data[3]); 
		CopyAssignmentArray(num_dims * num_clusters, centroids_short, hw_data[num_points*num_dims +3]); 
		
		
		hw_num = (num_points*num_dims)+ (num_dims * num_clusters) +3;
	  
	  
	  
// ==================================================================================
// Software computed values. Hardware reports mean WITH 4 bits of precision but range using ONLY the integer portion.
   gettimeofday(&t0, 0);
// Compute the clusters using the k-means algorithm.
   KMeans(num_dims, points, num_points, num_clusters, centroids, final_cluster_assignment);
   
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
   LoadUnloadBRAM(MAX_STRING_LEN, MAX_DATA_VALS, hw_num, load_unload, hw_data, CtrlRegA, DataRegA, ctrl_mask);

   for ( point_num = 0; point_num < num_points; point_num++ )
      printf("Point %d assigned to cluster %d\n", point_num, final_cluster_assignment[point_num]);

   return(0);
   }
