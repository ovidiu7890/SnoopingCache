library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM is
    Port (
        i_clk: in std_logic;
        i_address: in std_logic_vector(15 downto 0);
        o_data: out std_logic_vector(31 downto 0);
        i_data: in std_logic_vector(31 downto 0);
        i_read: in std_logic;
        i_write: in std_logic
    );
end RAM;

architecture Behavioral of RAM is
    type RAM_type is array (0 to 65535) of std_logic_vector(7 downto 0);
    signal RAM : RAM_type := (others => (others => '0'));
begin

    process(i_address, i_data, i_read, i_write, i_clk)
        variable base_addr : integer;
    begin

        base_addr := to_integer(unsigned(i_address(15 downto 2)))*4;
        
        if rising_edge (i_clk) then
            if i_write = '1' then
                RAM(base_addr + 3) <= i_data(31 downto 24);
                RAM(base_addr + 2) <= i_data(23 downto 16);
                RAM(base_addr + 1) <= i_data(15 downto 8);
                RAM(base_addr + 0) <= i_data(7  downto 0); 
            end if;
        end if;
        if i_read = '1' then
            o_data <= 
                RAM(base_addr + 3) &
                RAM(base_addr + 2) &
                RAM(base_addr + 1) &
                RAM(base_addr + 0);
        else
            o_data <= (others => '0');
        end if;
        
        

    end process;

end Behavioral;
