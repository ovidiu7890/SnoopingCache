library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bus_arbiter is
    Port (
        clk           : in std_logic;
        rst           : in std_logic;
        i_req         : in std_logic_vector(2 downto 0);
        o_grant_id    : out integer range 0 to 2;
        o_bus_active  : out std_logic
    );
end bus_arbiter;

architecture Behavioral of bus_arbiter is
begin
    process(clk, rst)
    begin
        if rst = '1' then
            o_grant_id   <= 0;
            o_bus_active <= '0';
        elsif rising_edge(clk) then
            if i_req(0) = '1' then
                o_grant_id   <= 0;
                o_bus_active <= '1';
            elsif i_req(1) = '1' then
                o_grant_id   <= 1;
                o_bus_active <= '1';
            elsif i_req(2) = '1' then
                o_grant_id   <= 2;
                o_bus_active <= '1';
            else
                o_bus_active <= '0';
            end if;
        end if;
    end process;
end Behavioral;