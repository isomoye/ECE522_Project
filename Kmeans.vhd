----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Professor Jim Plusquellic
-- 
-- Create Date:
-- Design Name: 
-- Module Name:    Kmeans - Behavioral 
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

-- ===================================================================================================
-- ===================================================================================================

-- Kmeans bins 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity Kmeans is
   port( 
      Clk: in  std_logic;
      RESET: in std_logic;
      start: in std_logic;
      ready: out std_logic;
      PN_Diff_ERR: out std_logic;
      PNL_BRAM_addr: out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
      PNL_BRAM_din: out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_dout: in std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_we: out std_logic_vector(0 to 0)
      );
end Kmeans;

architecture beh of Kmeans is
   type state_type is (idle, clear_mem, get_lower_addr, get_lower_val, get_upper_addr, get_upper_val, get_diff, inc_diff_addr, check_Kmeans_error);
   signal state_reg, state_next: state_type;

   signal ready_reg, ready_next: std_logic;

-- Address registers for the PNs and Kmeansgram portions of memory
   signal PN_addr_reg, PN_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal upper_pn_addr_reg, upper_pn_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal lower_pn_addr_reg, lower_pn_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

-- For selecting between PN or Kmeans portion of memory during memory accesses
   signal do_PN_diff_addr: std_logic;

-- Stores the full 16-bit PN that is the smallest among all in the data set
   signal smallest_val_reg, smallest_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal lower_val_reg, lower_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal upper_val_reg, upper_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);

-- These are 12 bits each to hold only the 12-bit integer portion of the PNs
   signal shifted_dout: signed(PN_INTEGER_NB-1 downto 0);
   signal shifted_smallest_val: signed(PN_INTEGER_NB-1 downto 0);

-- These signals used in the calculation of the address in the Kmeansgram memory of the cell to add 1 to during the Kmeans
-- contruction. They are addresses and therefore need to match the address width of the memory.
   signal offset_addr: signed(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal diff_cell_addr: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

-- These variables will store the PNL_BRAM addresses when the LV and HV bounds are met.
   signal LV_addr_reg, LV_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal HV_addr_reg, HV_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

-- Use for error checking when the range of the distribution is computed.
   signal LV_set_reg, LV_set_next: std_logic; 
   signal HV_set_reg, HV_set_next: std_logic;


-- The register used to sum up the counts in the Kmeansgram as it is parsed left to right. It WILL count up to the number of 
-- PNs stored, which is currently 4096, so we need 13-bit here, not 12.
   signal diff_reg, diff_next: unsigned(NUM_PNS_NB downto 0);

-- Storage for the mean must be able to accommodate a sum of 4096 values (NUM_PNS) each of which is 16-bits (PNL_BRAM_DBITS_WIDTH_NB) 
-- wide. The number of values summed is 4096 so we need 12-bits, NUM_PNS_NB) where each value is 16-bits (PN_SIZE_NB) so we need
-- an adder that is 28 bits (27 downto 0). The sum is likely to require much fewer bits -- this is worst case. 
   signal dist_mean_sum_reg, dist_mean_sum_next: signed(NUM_PNS_NB+PN_SIZE_NB-1 downto 0);

-- The final mean and range computed from the Kmeansgram. Written to memory below.
   signal dist_mean: std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal dist_range: std_logic_vector(Kmeans_MAX_RANGE_NB-1 downto 0);

-- Error flag is set to '1' if distribution is too narrow to be characterized with the specified bounds, or the integer portion of
-- a PN value is outside the range of -1023 and 1024.
   signal DIFF_ERR_reg, DIFF_ERR_next: std_logic;

   begin

-- Compute the mean with full precision. Divide through by 2^12 or 4096 since that's the number of PNs we add to the sum.
   dist_mean <= std_logic_vector(resize(dist_mean_sum_reg/(2**NUM_PNS_NB), PNL_BRAM_DBITS_WIDTH_NB));

-- The range of the distribution is computed as the difference in the addresses which were set when the running sum of the counts in
-- the Kmeans (as we sweep left to right) became equal to the percentages we defined as the limits, e.g., 6.25% and 93.75%.
-- NOTE: 'Kmeans_MAX_RANGE_NB" is 12 because the number of memory elements allocated for Kmeans memory is 2^12 = 2048, so 12 bits are 
-- needed to allow the range to reach 2048 (one bigger than 2047, which is 2^11).
   dist_range <= std_logic_vector(resize(HV_addr_reg - LV_addr_reg + 1, Kmeans_MAX_RANGE_NB));


-- =============================================================================================
-- State and register logic
-- =============================================================================================
   process(Clk, RESET)
      begin
      if ( RESET = '1' ) then
         state_reg <= idle;
         ready_reg <= '1';
         PN_addr_reg <= (others => '0');
         lower_pn_addr_reg <= (others => '0');
		 upper_pn_addr_reg <= (others => '0');
         smallest_val_reg <= (others => '0');
         LV_addr_reg <= (others => '0');
         HV_addr_reg <= (others => '0');
         LV_set_reg <= '0';
         HV_set_reg <= '0';
         dist_cnt_sum_reg <= (others => '0');
         dist_mean_sum_reg <= (others => '0');
         DIFF_ERR_reg <= '0';
      elsif ( Clk'event and Clk = '1' ) then
         state_reg <= state_next;
         ready_reg <= ready_next;
         PN_addr_reg <= PN_addr_next;
         lower_pn_addr_reg <= lower_pn_addr_next;
		 uppper_pn_addr_reg <= upper_pn_addr_next;
         smallest_val_reg <= smallest_val_next;
         LV_addr_reg <= LV_addr_next;
         HV_addr_reg <= HV_addr_next;
         LV_set_reg <= LV_set_next;
         HV_set_reg <= HV_set_next;
         dist_cnt_sum_reg <= dist_cnt_sum_next;
         dist_mean_sum_reg <= dist_mean_sum_next;
         DIFF_ERR_reg <= Kmeans_ERR_next;
      end if; 
   end process;


-- Convert the two quantities that will participate in computing the address of appropriate distribution cell that we will
-- add 1 to to create the Kmeansgram. these trim off the low order 4 bits of precision of the current word on the output
-- of the BRAM and the smallest_val computed in the loop below. NOTE: the RANGE MUST NEVER EXCEED +/- 1023 since we have 
-- ONLY 2048 memory locations dedicated to the distribution. 
   shifted_dout <= resize(signed(PNL_BRAM_dout)/16, PN_INTEGER_NB);
--  shifted_smallest_val <= resize(smallest_val_reg/16, PN_INTEGER_NB);

-- Compute the offset address in the Kmeans portion of memory by taking the integer portion of 'dout' - the integer portion
-- of the smallest value among all PNs. This address MUST fall into the range 0 to 2047.
-- offset_addr <= resize(shifted_dout, PNL_BRAM_ADDR_SIZE_NB) - resize(shifted_smallest_val, PNL_BRAM_ADDR_SIZE_NB);

-- Add the offset computed above to the base address of the Kmeansgram portion of BRAM.
-- Kmeans_cell_addr <= unsigned(offset_addr) + to_unsigned(Kmeans_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);

-- Compute the bounds of the distribution by adding up Kmeans cells from left to right until the sum becomes larger/smaller than
-- a 'fraction' of the total number of values counted in the Kmeansgram (which is 4096). Use 4 here to set the fraction limits to
-- 6.25% and 93.75% for the LV and HV bounds. With a total count across Kmeans cells of 4096, the bounds become 256 and 3840. 
--   LV_bound <= to_unsigned(NUM_PNs, NUM_PNS_NB+1) srl Kmeans_BOUND_PCT_SHIFT_NB;
--   HV_bound <= to_unsigned(NUM_PNs, NUM_PNS_NB+1) - LV_bound;

-- =============================================================================================
-- Combo logic
-- =============================================================================================

   process (state_reg, start, ready_reg, lower_pn_addr_reg,upper_pn_addr_reg, diff_addr_reg, lower_val_reg, upper_val_reg,PNL_BRAM_dout)
      begin
      state_next <= state_reg;
      ready_next <= ready_reg;

      PN_addr_next <= PN_addr_reg;
	  lower_pn_addr_next <= lower_pn_addr_reg;
	  uppper_pn_addr_next <= upper_pn_addr_reg;
      diff_addr_next <= diff_addr_reg;
      smallest_val_next <= smallest_val_reg;
      LV_addr_next <= LV_addr_reg; 
      HV_addr_next <= HV_addr_reg;
      LV_set_next <= LV_set_reg;
      HV_set_next <= HV_set_reg; 
      dist_cnt_sum_next <= dist_cnt_sum_reg;
      dist_mean_sum_next <= dist_mean_sum_reg;
      Kmeans_ERR_next <= Kmeans_ERR_reg;

-- Default value is 0 -- used during memory initialization.
      PNL_BRAM_din <= (others=>'0');
      PNL_BRAM_we <= "0";

      do_PN_diff_addr <= '0';

      case state_reg is

-- =====================
         when idle =>
            ready_next <= '1';

            if ( start = '1' ) then
               ready_next <= '0';

-- Reset error flag
               DIFF_ERR_next <= '0';

-- Zero the register that will eventually define the differences.
               diff_next <= (others=>'0');

-- Allow Kmeans_addr to drive PNL_BRAM
               do_PN_diff_addr <= '1';

-- Assert 'we' to zero out the first cell at 0.
               PNL_BRAM_we <= "1";
               diff_addr_next <= to_unsigned(DIFF_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
			   lower_pn_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
			   PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
               state_next <= get_lower_val;
            end if;


			
		when get_lower_addr =>
			
			if ( lower_pn_addr_reg = DIFF_BRAM_UPPER_LIMIT - 1 ) then
			state_next <= idle;
			
			else
			PN_addr_next <= lower_pn_addr_reg;
			state_next <= get_lower_val;
			
			
			
-- =====================
-- Find smallest value (this works for signed PN values, e.g., positive or negative).
         when get_lower_val =>
		 
			lower_val_next < = signed(PNL_BRAM_dout);
			state_next <= get_upper_addr;
               

-- =====================
-- Start constructing the Kmeansgram. PN portion of memory is selected and driving 'dout' since 'do_PN_diff_addr' was set to '0' 
-- in previous state.
        when get_upper_addr =>

			PN_addr_next <= lower_pn_addr_reg + PN_DIFF_VALUE;			
			state_next <= get_upper_val;

-- =====================
-- Add 1 to the memory location addressed by diff_addr_next/reg
        when get_upper_val =>
		
		 	upper_val_next <= signed(PNL_BRAM_dout);
			lower_pn_addr_next <= lower_pn_addr_reg +1; 
			diff_addr_next <= diff_addr_reg;
			state_next <= get_diff;
			
		when get_diff =>
			
			do_PN_diff_addr <= 1;
			PNL_BRAM_we <= "1";
			PNL_BRAM_din <= std_logic_vector(upper_val_reg - lower_val_reg);
			state_next <= inc_diff_addr;
		
		when inc_diff_addr =>
		
			diff_addr_next <= diff_addr_reg + 1;
			state_next <= get_lower_addr;

      end case;
   end process;

-- Using _reg here (not the look-ahead _next value).
   with do_PN_diff_addr select
      PNL_BRAM_addr <= std_logic_vector(PN_addr_next) when '0',
                       std_logic_vector(diff_addr_next) when others;

   Kmeans_ERR <= Kmeans_ERR_reg;
   ready <= ready_reg;

end beh;


