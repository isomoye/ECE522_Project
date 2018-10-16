-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use IEEE.fixed_pkg.all;

library work;
use work.DataTypes_pkg.all;

entity CalcTotalDistance is
	port(
		Clk                    : in  std_logic;
		RESET                  : in  std_logic;
		start                  : in  std_logic;
		ready                  : out std_logic;
		PNL_BRAM_addr          : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din           : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout          : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we            : out std_logic_vector(0 to 0);
		calcDist_start         : out std_logic;
		calcDist_ready         : in  std_logic;
		P1_addr                : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		P2_addr                : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		CalcDist_dout          : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		CalcTotalDistance_dout : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		Num_Vals               : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Num_Dims               : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0)
	);
end CalcTotalDistance;

architecture beh of CalcTotalDistance is
	type state_type is (idle, get_point_addr, get_cluster_addr, start_calcDist, wait_calcDist);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next               : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal points_addr_reg, points_addr_next       : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal centroids_addr_reg, centroids_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal centroids_base_reg, centroids_base_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster
	signal dist_count_reg, dist_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--signal received        : std_logic;
	-- For selecting between PN or CalcAllDist portion of memory during memory accesses

	-- Stores the 16-bit accumulating distance value
	signal tot_D_reg, tot_D_next : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);

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
			dist_count_reg     <= (others => '0');
			centroids_addr_reg <= (others => '0');
			dist_count_reg     <= (others => '0');
			tot_D_reg          <= (others => '0');
			centroids_base_reg <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg          <= state_next;
			ready_reg          <= ready_next;
			PN_addr_reg        <= PN_addr_next;
			points_addr_reg    <= points_addr_next;
			centroids_addr_reg <= centroids_addr_next;
			dist_count_reg     <= dist_count_next;
			tot_D_reg          <= tot_D_next;
			centroids_base_reg <= centroids_base_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================

	process(state_reg, start, ready_reg, points_addr_reg, centroids_addr_reg, PN_addr_reg, dist_count_reg, tot_D_reg, calcDist_ready, CalcDist_dout, Num_Dims, centroids_base_reg, Num_Vals, PNL_BRAM_dout)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next        <= PN_addr_reg;
		points_addr_next    <= points_addr_reg;
		centroids_addr_next <= centroids_addr_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');
		PNL_BRAM_we  <= "0";

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Zero the register that will store distances
					tot_D_next          <= (others => '0');
					dist_count_next     <= (others => '0');
					centroids_addr_next <= (others => '0');
					points_addr_next    <= (others => '0');
					PN_addr_next        <= (others => '0');
					centroids_addr_next <= resize(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + (unsigned(Num_Vals) * unsigned(num_dims) + TO_UNSIGNED(PROG_VALS, PNL_BRAM_ADDR_SIZE_NB)), PNL_BRAM_ADDR_SIZE_NB);
					state_next          <= get_point_addr;
				end if;

			when get_point_addr =>

				if (dist_count_reg = unsigned(Num_Vals) - 1) then
					CalcTotalDistance_dout <= std_logic_vector(tot_D_reg);
					state_next             <= idle;

				else
					points_addr_next <= resize(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + unsigned(dist_count_reg * unsigned(Num_Dims)) + PROG_VALS, PNL_BRAM_ADDR_SIZE_NB);
					PN_addr_next     <= to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB) + dist_count_reg;
					state_next       <= start_calcDist;
				end if;

			when get_cluster_addr =>
				centroids_addr_next <= resize(centroids_base_reg + unsigned(PNL_BRAM_dout), PNL_BRAM_ADDR_SIZE_NB);
				state_next          <= start_calcDist;

			when start_calcDist =>
				P1_addr        <= std_logic_vector(points_addr_reg);
				P2_addr        <= std_logic_vector(centroids_addr_reg);
				calcDist_start <= '1';
				state_next     <= wait_calcDist;

			when wait_calcDist =>
				if (calcDist_ready = '1') then
					tot_D_next      <= tot_D_reg + to_sfixed(CalcDist_dout, PN_INTEGER_NB, -PN_PRECISION_NB);
					dist_count_next <= dist_count_reg + 1;
					state_next      <= get_point_addr;

				end if;
		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	PNL_BRAM_addr <= std_logic_vector(PN_addr_next);

	ready <= ready_reg;

end beh;

