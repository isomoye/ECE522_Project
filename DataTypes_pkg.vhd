----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Professor Jim Plusquellic
-- 
-- Create Date:
-- Design Name: 
-- Module Name:    DataTypes_pkg - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

package DataTypes_pkg is

	-- We represent numbers in FIXED-POINT format, with 12-bit integer portion of the 16-bit number stored in the PN BRAM. 
	-- The fractional component is given by 'PRECISION' and the sum is PN_SIZE_NB. PN_SIZE_LB needs to be able to count 
	-- to PN_SIZE_NB.
	constant PN_INTEGER_NB   : integer := 12;
	constant PN_PRECISION_NB : integer := 4;
	constant PN_SIZE_LB      : integer := 4;
	constant PN_SIZE_NB      : integer := PN_INTEGER_NB + PN_PRECISION_NB;
	constant PROG_VALS       : integer := 3;

	constant BYTE_SIZE_LB : integer := 3;
	constant BYTE_SIZE_NB : integer := 8;

	constant WORD_SIZE_LB : integer := 4;
	constant WORD_SIZE_NB : integer := 16;

	-- BRAM SIZES: PNL is currently 16384 bytes with 16-bit words. 
	constant PNL_BRAM_ADDR_SIZE_NB   : integer := 15;
	constant PNL_BRAM_DBITS_WIDTH_LB : integer := PN_SIZE_LB;
	constant PNL_BRAM_DBITS_WIDTH_NB : integer := PN_SIZE_NB;
	constant PNL_BRAM_NUM_WORDS_NB   : integer := 2**PNL_BRAM_ADDR_SIZE_NB;

	-- Total number PNs loaded into region 4096 to 8192 is 2^12 = 4096.
	constant NUM_PNS_NB : integer := 12;
	constant NUM_PNS    : integer := 2**NUM_PNS_NB;
	constant ARRAY_SIZE : integer := NUM_PNS / 2;

	-- Largest positive (signed) value for PNs is 1023.9375 which is in binary 01111111111.1111, BUT AS a integer binary value with no 
	-- decimal place, it is 16383 (0011111111111111) (note, we have 16-bit for the word size now).
	constant LARGEST_POS_VAL : integer := 16383;

	-- My largest negative value is -1023.9375 or 110000000000.0001, AND as a integer binary value, -16383
	constant LARGEST_NEG_VAL : integer := -16383;

	-- We store the raw data in the upper half of memory (locations 4096 to 8191). 
	constant PN_BRAM_BASE   : integer := 24576;
	constant PN_UPPER_LIMIT : integer := PNL_BRAM_NUM_WORDS_NB;

	-- Kmeans range
	constant DIST_BRAM_BASE            : integer := 10240;
	--constant DIST_BRAM_UPPER_LIMIT     : integer := 12288;
	constant CLUSTER_BASE_ADDR         : integer := 8192;
	constant COPY_CLUSTER_BASE_ADDR    : integer := 4096;
	--constant CENTROIDS_BASE_ADDR       : integer := 4096;
	constant FINAL_CLUSTER_UPPER_LIMIT : integer := 4096 / 2;
	constant FINAL_CLUSTER_BASE_ADDR   : integer := 0;

	constant NUM_VALS_ADDR     : integer := 0;
	constant NUM_CLUSTERS_ADDR : integer := 1;
	constant NUM_DIMS_ADDR     : integer := 2;

	constant MAX_ITERATIONS : integer := 100;

end DataTypes_pkg;
