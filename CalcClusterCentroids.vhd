-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use IEEE.fixed_pkg.all;

library work;
use work.DataTypes_pkg.all;

entity CalcClusterCentroids is
	port(
		Clk           : in  std_logic;
		RESET         : in  std_logic;
		start         : in  std_logic;
		ready         : out std_logic;
		PNL_BRAM_addr : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we   : out std_logic_vector(0 to 0)
	);
end CalcClusterCentroids;

architecture beh of CalcClusterCentroids is
	type state_type is (idle, get_prog_addr, get_prog_vals, clear_mem, get_point_addr, get_dims_addr, inc_cluster_val, get_curr_centroid, divide_cluster_val);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	type t_Row_Col is array (0 to PN_SIZE_NB - 1) of std_logic_vector(ARRAY_SIZE - 1 downto 0);
	--  array (0 to (NUM_PNS / 2) - 1, 0 to PN_SIZE_NB - 1) of std_logic_vector range 0 to 9;
	signal cluster_member_count_reg, cluster_member_count_next : t_Row_Col;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next               : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal points_addr_reg, points_addr_next       : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal cluster_addr_reg, cluster_addr_next     : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal centroids_addr_reg, centroids_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster
	signal dist_count_reg, dist_count_next       : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal cluster_count_reg, cluster_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal dims_count_reg, dims_count_next       : unsigned(3 downto 0);

	signal divide_iteration_reg, divide_iteration_next : std_logic;

	-- For selecting between PN or CalcAllDist portion of memory during memory accesses
	signal do_PN_cluster_addr : std_logic;

	-- Stores the full 16-bit distance 
	signal distance_val_reg, distance_val_next         : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal active_cluster_reg, active_cluster_next     : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal best_index_reg, best_index_next             : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal closest_distance_reg, closest_distance_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	signal num_vals_reg, num_vals_next         : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal num_clusters_reg, num_clusters_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal num_dims_reg, num_dims_next         : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

begin

	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg                <= idle;
			ready_reg                <= '1';
			PN_addr_reg              <= (others => '0');
			points_addr_reg          <= (others => '0');
			centroids_addr_reg       <= (others => '0');
			distance_val_reg         <= (others => '0');
			cluster_count_reg        <= (others => '0');
			divide_iteration_reg     <= '0';
			cluster_member_count_reg <= (others => (others => '0'));
			cluster_addr_reg         <= (others => '0');
			num_vals_reg             <= (others => '0');
			best_index_reg           <= (others => '0');
			num_clusters_reg         <= (others => '0');
			dims_count_reg           <= (others => '0');
			dims_count_reg           <= (others => '0');
			dist_count_reg           <= (others => '0');
			cluster_addr_reg         <= (others => '0');
			active_cluster_reg       <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg                <= state_next;
			ready_reg                <= ready_next;
			PN_addr_reg              <= PN_addr_next;
			points_addr_reg          <= points_addr_next;
			cluster_count_reg        <= cluster_count_next;
			centroids_addr_reg       <= centroids_addr_next;
			cluster_member_count_reg <= cluster_member_count_next;
			cluster_addr_reg         <= cluster_addr_next;
			best_index_reg           <= best_index_next;
			divide_iteration_reg     <= divide_iteration_next;
			distance_val_reg         <= distance_val_next;
			dims_count_reg           <= dims_count_next;
			num_vals_reg             <= num_vals_next;
			num_clusters_reg         <= num_clusters_next;
			num_dims_reg             <= num_dims_next;
			dist_count_reg           <= dist_count_next;
			active_cluster_reg       <= active_cluster_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================

	process(state_reg, start, ready_reg, points_addr_reg, divide_iteration_reg, active_cluster_next, centroids_addr_reg, cluster_member_count_reg, cluster_count_reg, active_cluster_reg, dist_count_reg, PN_addr_reg, dims_count_reg, closest_distance_reg, distance_val_reg, num_clusters_reg, num_vals_reg, num_dims_reg, num_clusters_next, cluster_addr_reg, best_index_reg, PNL_BRAM_dout)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next              <= PN_addr_reg;
		points_addr_next          <= points_addr_reg;
		centroids_addr_next       <= centroids_addr_reg;
		distance_val_next         <= distance_val_reg;
		cluster_count_next        <= cluster_count_reg;
		cluster_addr_next         <= cluster_addr_reg;
		best_index_next           <= best_index_reg;
		dims_count_next           <= dims_count_reg;
		cluster_member_count_next <= cluster_member_count_reg;
		active_cluster_next       <= active_cluster_reg;
		dist_count_next           <= dist_count_reg;
		num_vals_next             <= num_vals_reg;
		num_clusters_next         <= num_clusters_next;
		num_dims_next             <= num_dims_reg;
		divide_iteration_next     <= divide_iteration_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');

		PNL_BRAM_we <= "0";

		do_PN_cluster_addr <= '0';

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Zero the register that will store distances
					distance_val_next <= (others => '0');

					-- Allow CalcAllDist_addr to drive PNL_BRAM
					--do_PN_cluster_addr <= '1';

					-- Assert 'we' to zero out the first cell at 0.
					--PNL_BRAM_we <= "1";
					distance_val_next         <= (others => '0');
					active_cluster_next       <= (others => '0');
					divide_iteration_next     <= '0';
					dist_count_next           <= (others => '0');
					cluster_count_next        <= (others => '0');
					cluster_member_count_next <= (others => (others => '0'));
					centroids_addr_next       <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					points_addr_next          <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					PN_addr_next              <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					state_next                <= get_prog_addr;
				end if;

			when get_prog_addr =>
				if (dist_count_reg = to_unsigned(PROG_VALS, PNL_BRAM_ADDR_SIZE_NB)) then
					dist_count_next <= (others => '0');
					state_next      <= clear_mem;
				else
					PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + dist_count_reg;
					state_next   <= get_prog_vals;
				end if;

			when get_prog_vals =>
				if (dist_count_reg = 0) then
					num_vals_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = 1) then
					num_clusters_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = 2) then
					dims_count_next <= resize(unsigned(PNL_BRAM_dout), PROG_VALS + 1);
				end if;

			-- =====================
			-- Clear out the center portion of memory. 'cluster_addr_reg' tracks BRAM cells in (8192 to 10240) portion of memory 
			when clear_mem =>
				if (divide_iteration_reg = '0') then
					if (cluster_count_reg = num_clusters_reg - 1) then
						-- Reset PN_addr and get first value
						--PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
						cluster_count_next <= (others => '0');
						state_next         <= get_point_addr;

					elsif (dims_count_reg = num_dims_reg - 1) then
						--cluster_count_next <= (others => '0');
						--dist_count_next    <= dist_count_reg + 1;
						--cluster_member_count(cluster_count_reg) <= (others => '0');
						cluster_count_next <= cluster_count_reg + 1;
						dims_count_next    <= (others => '0');

					else
						do_PN_cluster_addr <= '1';
						PNL_BRAM_we        <= "1";
						cluster_addr_next  <= resize(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + ((cluster_count_reg * num_dims_reg) + dims_count_reg), PNL_BRAM_ADDR_SIZE_NB);
						dims_count_next    <= dims_count_reg + 1;
						state_next         <= get_prog_addr;
					end if;
				else

					if (cluster_count_reg = num_clusters_reg - 1) then
						-- Reset PN_addr and get first value
						--PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
						cluster_count_next    <= (others => '0');
						divide_iteration_next <= '0';
						state_next            <= idle;

					elsif (dims_count_reg = num_dims_reg - 1) then
						--cluster_count_next <= (others => '0');
						--dist_count_next    <= dist_count_reg + 1;
						--cluster_member_count(cluster_count_reg) <= (others => '0');
						cluster_count_next <= cluster_count_reg + 1;
						dims_count_next    <= (others => '0');

					else
						do_PN_cluster_addr <= '1';
						--PNL_BRAM_we        <= "1";
						PN_addr_next       <= resize(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + ((cluster_count_reg * num_dims_reg) + dims_count_reg), PNL_BRAM_ADDR_SIZE_NB);
						state_next         <= get_curr_centroid;
					end if;
				end if;

			when get_point_addr =>
				if (dist_count_reg = num_vals_reg - 1) then
					dist_count_next       <= (others => '0');
					dims_count_next       <= (others => '0');
					cluster_count_next    <= (others => '0');
					divide_iteration_next <= '1';
					state_next            <= clear_mem;
				else
					--	points_addr_next <= to_unsigned(KMEANS_PN_BRAM_LOWER_LIMIT,PNL_BRAM_ADDR_SIZE_NB) 
					--	+ (dist_count_reg * dims_count);
					state_next <= get_dims_addr;

					PN_addr_next <= resize(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + dist_count_reg, PNL_BRAM_ADDR_SIZE_NB);

					active_cluster_next <= unsigned(PNL_BRAM_dout);

					cluster_member_count_next(to_integer(unsigned(active_cluster_next))) <= std_logic_vector(unsigned(cluster_member_count_reg(to_integer(unsigned(active_cluster_next)))) + 1);
				end if;

			when get_dims_addr =>
				if (dims_count_reg = num_dims_reg - 1) then
					cluster_count_next <= cluster_count_reg + 1;
					state_next         <= get_point_addr;
					dims_count_next    <= (others => '0');
				else
					dims_count_next       <= dims_count_reg + 1;
					PN_addr_next          <= resize(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + unsigned((dist_count_reg * num_dims_reg) + dims_count_reg) + PROG_VALS, PNL_BRAM_ADDR_SIZE_NB);
					closest_distance_next <= unsigned(PNL_BRAM_dout);
					state_next            <= inc_cluster_val;

				end if;

			when inc_cluster_val =>

				PNL_BRAM_din       <= std_logic_vector(signed(PNL_BRAM_dout) + 1);
				do_PN_cluster_addr <= '1';
				cluster_addr_next  <= resize(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + ((unsigned(active_cluster_reg) * num_dims_reg) + dims_count_reg), PNL_BRAM_ADDR_SIZE_NB);
				PNL_BRAM_we        <= "1";
				state_next         <= get_dims_addr;

			when get_curr_centroid =>
				distance_val_next     <= unsigned(PNL_BRAM_dout);
				closest_distance_next <= resize(unsigned(cluster_member_count_reg(to_integer(unsigned(cluster_count_reg)))), PNL_BRAM_DBITS_WIDTH_NB);
				state_next            <= divide_cluster_val;

			when divide_cluster_val =>
				PNL_BRAM_din       <= std_logic_vector(distance_val_reg / closest_distance_reg);
				do_PN_cluster_addr <= '1';
				cluster_addr_next  <= resize(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + ((unsigned(active_cluster_reg) * num_dims_reg) + dims_count_reg), PNL_BRAM_ADDR_SIZE_NB);
				PNL_BRAM_we        <= "1";
				dims_count_next    <= dims_count_reg + 1;
				state_next         <= clear_mem;

		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	with do_PN_cluster_addr select PNL_BRAM_addr <=
		std_logic_vector(PN_addr_next) when '0',
		std_logic_vector(cluster_addr_next) when others;

	ready <= ready_reg;

end beh;

