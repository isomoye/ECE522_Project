-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity FindClosestCentroid is
   port( 
      Clk: in  std_logic;
      RESET: in std_logic;
      start: in std_logic;
      ready: out std_logic;
      PNL_BRAM_addr: out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
      PNL_BRAM_din: out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_dout: in std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_we: out std_logic_vector(0 to 0)
      );
end FindClosestCentroid;

architecture beh of FindClosestCentroid is
   type state_type is (idle, get_point_addr, get_cluster_addr,get_dist_val, get_closest_distance);
   signal state_reg, state_next: state_type;

   signal ready_reg, ready_next: std_logic;

-- Address registers for the PNs and CalcAllDistgram portions of memory
   signal PN_addr_reg, PN_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal cluster_addr_reg, cluster_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   
   
   
   signal centroids_addr_reg, centroids_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   
-- for iterating through # of points and #cluster
   signal cluster_reg, cluster_next : unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal dist_count_reg, dist_count_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
-- signal cluster_val_reg, cluster_val_next:  unsigned(3 downto 0);
   signal count_dims_reg, count_dims_next: unsigned(3 downto 0);
   
   signal received : std_logic;
-- For selecting between PN or CalcAllDist portion of memory during memory accesses
   signal do_PN_cluster_addr: std_logic;

-- Stores the full 16-bit distance 
	signal cluster_val_reg, cluster_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal dist_sqr_reg, dist_sqr_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal best_index_reg, best_index_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal closest_distance_reg, closest_distance_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal num_vals_reg, num_vals_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal num_clusters_reg, num_clusters_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	signal count_dims_reg, count_dims_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	
-- These are 12 bits each to hold only the 12-bit integer portion of the PNs
   signal shifted_dout: signed(PN_INTEGER_NB-1 downto 0);
   signal shifted_distance_val: signed(PN_INTEGER_NB-1 downto 0);


   begin

-- =============================================================================================
-- State and register logic
-- =============================================================================================
   process(Clk, RESET)
      begin
      if ( RESET = '1' ) then
         state_reg <= idle;
         ready_reg <= '1';
         PN_addr_reg <= (others => '0');
         points_addr_reg <= (others => '0');
		 centroids_addr_reg <= (others => '0');
         cluster_val_reg <= (others => '0');
		 cluster_addr_reg <= (others => '0');
		 num_vals_reg <= (others => '0');
		 num_clusters_reg <= (others => '0');
		 count_dims_reg <= (others => '0');
		 count_dims_reg <= (others => '0');
		 dist_count_reg <= (others => '0');
		 cluster_addr_reg <= (others => '0');
		 dist_sqr_reg <= (others => '0');
      elsif ( Clk'event and Clk = '1' ) then
         state_reg <= state_next;
         ready_reg <= ready_next;
         PN_addr_reg <= PN_addr_next;
         points_addr_reg <= points_addr_next;
		 cluster_val_reg <= cluster_val_next;
		 centroids_addr_reg <= centroids_addr_next;
		 cluster_addr_reg <= cluster_addr_next;
		 count_dims_reg <= count_dims_next;
		 num_vals_reg <= num_vals_next;
		 num_clusters_reg <= num_clusters_next;
		 num_dims_reg <= num_dims_next;
		 dist_count_reg <= dist_count_next;
		 dist_sqr_reg <= dist_sqr_next;
      end if; 
   end process;


-- =============================================================================================
-- Combo logic
-- =============================================================================================

   process (state_reg, start, ready_reg, points_addr_reg,centroids_addr_reg, cluster_val_reg,cluster_reg,PNL_BRAM_dout)
      begin
      state_next <= state_reg;
      ready_next <= ready_reg;

      PN_addr_next <= PN_addr_reg;
	  points_addr_next <= points_addr_reg;
	  centroids_addr_next <= centroids_addr_reg;
      cluster_next <= cluster_reg;
	  cluster_val_next <= cluster_val_reg;
	  cluster_addr_next <= cluster_addr_reg;
	  count_dims_next <= count_dims_reg;
	  dist_sqr_next <= dist_sqr_reg;
	  dist_count_next <= dist_count_reg;
	  num_vals_next <= num_vals_reg;
	  num_clusters_next <= num_clusters_next;
	  num_dims_next <= num_dims_reg;

-- Default value is 0 -- used during memory initialization.
      PNL_BRAM_din <= (others=>'0');
	  
      PNL_BRAM_we <= "0";

      do_PN_cluster_addr <= '0';

      case state_reg is

-- =====================
         when idle =>
            ready_next <= '1';

            if ( start = '1' ) then
               ready_next <= '0';




-- Allow CalcAllDist_addr to drive PNL_BRAM
               do_PN_cluster_addr <= '1';

-- Assert 'we' to zero out the first cell at 0.
               --PNL_BRAM_we <= "1";
			   cluster_next <= (others=>'0');
			   dist_sqr_next <= (others => '0');
			   dist_count_next <= (others => '0');
			   cluster_val_next <= (others => '0');
               centroids_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
			   points_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
			   PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
               state_next <= get_point_addr;
            end if;

		when get_prog_addr
			if(dist_count_reg = "4" - 1) then
			dist_count_next <= (others => '0');
			state_next <= get_point_addr;
			else 
			PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) +
			dist_addr_reg;
			state_next <= get_prog_vals
			end if;
		
		when get_prog_vals 
			if(dist_count_reg = 0) then
			num_vals_next <= unsigned(PNL_BRAM_dout);
			else if(dist_count_reg = 1) then
			num_clusters_next <= unsigned(PNL_BRAM_dout);
			else if(dist_count_reg = 2) then
			count_dims_next <= unsigned(PNL_BRAM_dout);
			end if;
			
			dist_count_next <= dist_count_reg + 1;
			state_next <= get_prog_addr;
			
		when get_cluster_addr =>
			
			if ( dist_count_reg = num_vals_reg - 1 ) then
			state_next <= idle;			
			else
		--	points_addr_next <= to_unsigned(KMEANS_PN_BRAM_LOWER_LIMIT,PNL_BRAM_ADDR_SIZE_NB) 
		--	+ (dist_count_reg * count_dims);
			PN_addr_next <= to_unsigned(KMEANS_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB)
			+ dist_count_reg;
			state_next <= get_cluster_val;			
			
-- =====================
-- get bram address of current centroid.
         when get_cluster_val =>
			cluster_val_next <= signed(PNL_BRAM_dout);
			state_next <= store_val;
-- get p1 value
		when store_val	
			PNL_BRAM_din <= cluster_val_reg;
			cluster_addr_next <= PN_addr_next <= to_unsigned(KMEANS_COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB)
			+ dist_count_reg;
			distance_val_next <= signed(PNL_BRAM_dout);	
			state_next <= get_closest_distance;			
			
			
	    when get_closest_distance
		
			if(cluster_val_reg <= "0" || distance_val_reg < closest_distance_reg )
				best_index_next <= dist_count_reg;
				closest_distance_next <= distance_val_reg;
			end if;			
				cluster_addr_next <= to_unsigned(KMEANS_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) +
				dist_count_reg;
				cluster_val_next <= cluster_val_reg + 1;
				state_next <= get_cluster_addr;
			
			

-- Using _reg here (not the look-ahead _next value).
   with do_PN_cluster_addr select
      PNL_BRAM_addr <= std_logic_vector(PN_addr_next) when '0',
                       std_logic_vector(cluster_addr_next) when others;

   CalcAllDist_ERR <= CalcAllDist_ERR_reg;
   ready <= ready_reg;

end beh;

