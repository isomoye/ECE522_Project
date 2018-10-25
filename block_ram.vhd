library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.DataTypes_pkg.all;

entity ram_mod is
	port(Clk     : in  std_logic;
	     address : in  integer;
	     we      : in  std_logic;
	     data_i  : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	     data_o  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0)
	    );
end ram_mod;

architecture Behavioral of ram_mod is

	--Declaration of type and signal of a 256 element RAM
	--with each element being 16 bit wide.
	type ram_t is array (0 to  ARRAY_SIZE - 1) of std_logic_vector(0 to  PNL_BRAM_DBITS_WIDTH_NB - 1);
	signal ram : ram_t := (others => (others => '0'));
	
begin

	--process for read and write operation.
	PROCESS(Clk)
	BEGIN
		if (rising_edge(Clk)) then
			if (we = '1') then
				ram(address) <= data_i;
			end if;
			data_o <= ram(address);
		end if;
	END PROCESS;

end Behavioral;
