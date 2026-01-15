library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM is
    Port (
        i_clk     : in std_logic;
        i_address : in std_logic_vector(15 downto 0);
        i_data    : in std_logic_vector(31 downto 0);
        i_write   : in std_logic;
        i_read    : in std_logic;
        o_data    : out std_logic_vector(31 downto 0)
    );
end RAM;

architecture Behavioral of RAM is
    constant DEPTH : integer := 32768;
    type ram_type is array (0 to DEPTH-1) of std_logic_vector(31 downto 0);
    signal mem : ram_type := (others => (others => '0'));
begin
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_write = '1' then
                mem(to_integer(unsigned(i_address(14 downto 2)))) <= i_data;
            end if;
            
            o_data <= mem(to_integer(unsigned(i_address(14 downto 2))));
        end if;
    end process;
end Behavioral;