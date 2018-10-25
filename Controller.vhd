----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Professor Jim Plusquellic
-- 
-- Create Date:
-- Design Name: 
-- Module Name:    Controller - Behavioral 
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

-- This is the master control module. It is started by the C program and controls the other modules in this project. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity Controller is
	port(
		Clk                 : in  std_logic;
		RESET               : in  std_logic;
		start               : in  std_logic;
		ready               : out std_logic;
		LM_ULM_start        : out std_logic;
		LM_ULM_ready        : in  std_logic;
		LM_ULM_base_address : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		LM_ULM_upper_limit  : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		LM_ULM_load_unload  : out std_logic;
		Kmeans_start        : out std_logic;
		Kmeans_ready        : in  std_logic
	);
end Controller;

architecture beh of Controller is
	type state_type is (idle, wait_lM_ULM_load, wait_Kmeans, wait_LM_ULM_unload);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

begin

	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg <= idle;
			ready_reg <= '1';
		elsif (Clk'event and Clk = '1') then
			state_reg <= state_next;
			ready_reg <= ready_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================
	process(state_reg, start, ready_reg, LM_ULM_ready, Kmeans_ready)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		LM_ULM_start <= '0';
		Kmeans_start <= '0';

		LM_ULM_base_address <= (others => '0');
		LM_ULM_upper_limit  <= (others => '0');
		LM_ULM_load_unload  <= '0';

		-- Give LoadUnloadMem default control of the memory

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Start data load operation from C program
					LM_ULM_start <= '1';

					-- Setup memory base and upper_limit for loading of PNs into BRAM. ALWAYS SUBSTRACT 1 from the 'UPPER_LIMIT'
					LM_ULM_base_address <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB));
					LM_ULM_upper_limit  <= std_logic_vector(to_unsigned(PNL_BRAM_NUM_WORDS_NB - 1, PNL_BRAM_ADDR_SIZE_NB));

					state_next <= wait_LM_ULM_load;
				end if;

			-- =====================
			-- Wait for PN load of BRAM to complete.
			when wait_LM_ULM_load =>
				if (LM_ULM_ready = '1') then
					Kmeans_start <= '1';

					-- Give Kmeans module control of the memory
					state_next <= wait_Kmeans;
				end if;

			-- =====================
			-- Wait for hostogram calculation to complete. Continue to give Kmeans module control of the memory
			when wait_Kmeans =>

				if (Kmeans_ready = '1') then

					-- Start memory output operation to C program
					LM_ULM_start <= '1';

					-- Setup memory base and upper_limit for unloading of Kmeansgram from BRAM. ALWAYS SUBSTRACT 1 from the 'UPPER_LIMIT'
					LM_ULM_base_address <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					LM_ULM_upper_limit  <= std_logic_vector(to_unsigned( DIST_BRAM_BASE - 1, PNL_BRAM_ADDR_SIZE_NB));

					-- Set LoadUnloadMem mode to 'unload' data from BRAM to C program
					LM_ULM_load_unload <= '1';
					state_next         <= wait_LM_ULM_unload;
				end if;

			-- =====================
			-- Wait for Kmeansgram data to be completely transfered to C program
			when wait_LM_ULM_unload =>
				LM_ULM_load_unload <= '1';
				if (LM_ULM_ready = '1') then
					state_next <= idle;
				end if;

		end case;
	end process;

	ready <= ready_reg;
end beh;
