-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use IEEE.fixed_pkg.all;

library work;
use work.DataTypes_pkg.all;

entity CalcAllDistance is
	port(
		Clk            : in  std_logic;
		RESET          : in  std_logic;
		start          : in  std_logic;
		ready          : out std_logic;
		PNL_BRAM_addr  : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din   : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we    : out std_logic_vector(0 to 0);
		calcDist_start : out std_logic;
		calcDist_ready : in  std_logic;
		P1_addr        : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		P2_addr        : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Num_Vals       : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Num_Clusters   : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Num_Dims       : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		CalcDist_dout  : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0)
	);
end CalcAllDistance;

architecture beh of CalcAllDistance is
	type state_type is (idle, get_point_addr, get_cluster_addr, start_calcDist, wait_calcDist);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next               : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal points_addr_reg, points_addr_next       : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal centroids_addr_reg, centroids_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal centroids_base_reg, centroids_base_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal dist_addr_reg, dist_addr_next           : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster

	signal dist_count_reg, dist_count_next       : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal cluster_count_reg, cluster_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--signal received        : std_logic;
	-- For selecting between PN or CalcAllDist portion of memory during memory accesses
	signal do_PN_dist_addr : std_logic;

	-- Stores the full 16-bit distance 
	signal distance_val_reg, distance_val_next : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);

	--values read from BRAM for portability of design

begin

	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg          <= idle;
			ready_reg          <= '1';
			PN_addr_reg        <= (others => '0');
			points_addr_reg    <= (others => '0');
			centroids_addr_reg <= (others => '0');
			centroids_base_reg <= (others => '0');
			dist_addr_reg      <= (others => '0');
			distance_val_reg   <= (others => '0');
			cluster_count_reg  <= (others => '0');
			dist_count_reg     <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg          <= state_next;
			ready_reg          <= ready_next;
			PN_addr_reg        <= PN_addr_next;
			points_addr_reg    <= points_addr_next;
			cluster_count_reg  <= cluster_count_next;
			centroids_addr_reg <= centroids_addr_next;
			centroids_base_reg <= centroids_base_next;
			distance_val_reg   <= distance_val_next;
			dist_addr_reg      <= dist_addr_next;
			dist_count_reg     <= dist_count_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================

	process(state_reg, start, ready_reg, points_addr_reg, calcDist_ready, CalcDist_dout, centroids_addr_reg, cluster_count_reg, dist_addr_reg, PN_addr_reg, dist_count_reg, distance_val_reg, Num_Vals, Num_Clusters, Num_Dims)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next        <= PN_addr_reg;
		points_addr_next    <= points_addr_reg;
		centroids_addr_next <= centroids_addr_reg;
		centroids_base_next <= centroids_base_reg;
		dist_addr_next      <= dist_addr_reg;
		distance_val_next   <= distance_val_reg;
		cluster_count_next  <= cluster_count_reg;
		dist_count_next     <= dist_count_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');
		PNL_BRAM_we  <= "0";

		do_PN_dist_addr <= '0';

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Zero the register that will store distances
					distance_val_next <= (others => '0');

					-- Allow CalcAllDist_addr to drive PNL_BRAM
					--do_PN_dist_addr <= '1';

					-- Assert 'we' to zero out the first cell at 0.
					dist_addr_next      <= (others => '0');
					cluster_count_next  <= (others => '0');
					distance_val_next   <= (others => '0');
					dist_count_next     <= (others => '0');
					centroids_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					centroids_base_next <= resize(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + (unsigned(Num_Vals) * unsigned(num_dims) + TO_UNSIGNED(PROG_VALS, PNL_BRAM_ADDR_SIZE_NB)), PNL_BRAM_ADDR_SIZE_NB);
					points_addr_next    <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					PN_addr_next        <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					state_next          <= get_point_addr;
				end if;

			when get_point_addr =>

				if (dist_count_reg >= unsigned(Num_Vals) - 1) then
					state_next <= idle;

				else
					points_addr_next <= resize(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + unsigned(dist_count_reg * unsigned(Num_Dims)) + PROG_VALS, PNL_BRAM_ADDR_SIZE_NB);
					state_next       <= get_cluster_addr;
				end if;

			-- =====================
			-- get bram address of current centroid.
			when get_cluster_addr =>
				if (cluster_count_reg >= unsigned(Num_Clusters) - 1) then
					cluster_count_next <= (others => '0');
					dist_count_next    <= dist_count_reg + 1;
					state_next         <= get_point_addr;
				else
					centroids_addr_next <= resize(centroids_base_reg + (cluster_count_reg * unsigned(Num_Dims)), PNL_BRAM_ADDR_SIZE_NB);
					--PN_addr_next        <= points_addr_reg;
					state_next          <= start_calcDist;
				end if;
			-- get p1 value
			when start_calcDist =>
				P1_addr        <= std_logic_vector(points_addr_reg);
				P2_addr        <= std_logic_vector(centroids_addr_reg);
				calcDist_start <= '1';
				state_next     <= wait_calcDist;

			when wait_calcDist =>
				if (calcDist_ready = '1') then
					do_PN_dist_addr    <= '1';
					PNL_BRAM_din       <= std_logic_vector(CalcDist_dout);
					PNL_BRAM_we        <= "1";
					dist_addr_next     <= resize(to_unsigned(DIST_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + ((dist_count_reg * unsigned(Num_Clusters)) + cluster_count_reg), PNL_BRAM_ADDR_SIZE_NB);
					cluster_count_next <= cluster_count_reg + 1;
					state_next         <= get_cluster_addr;
				end if;

		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	with do_PN_dist_addr select PNL_BRAM_addr <=
		std_logic_vector(PN_addr_next) when '0',
		std_logic_vector(dist_addr_next) when others;

	ready <= ready_reg;

end beh;

