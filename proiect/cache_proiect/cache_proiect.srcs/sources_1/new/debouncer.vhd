library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity debouncer is
  Port ( clk : in std_logic;
        btn : in std_logic;
        en : out std_logic );
end debouncer;

architecture Behavioral of debouncer is

signal count : std_logic_vector(15 downto 0) := (others => '0');
signal q1 : std_logic := '0';
signal q2 : std_logic := '0';
signal q3 : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            count <= count + 1;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if count(15 downto 0) = x"1111" then
                q1 <= btn;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            q2 <= q1;
            q3 <= q2;
        end if;
    end process;

    en <= q2 and (not q3);

end Behavioral;