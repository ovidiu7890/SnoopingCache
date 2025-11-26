library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.LRU_Types.all;

entity tb_LRU_Cache_16 is
end entity;

architecture sim of tb_LRU_Cache_16 is

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal access_en    : std_logic := '0';
    signal access_data  : T_DATA := (others => '0');
    signal busy         : std_logic;
    signal hit          : std_logic;
    signal miss         : std_logic;
    signal evicted_data : T_DATA;
    signal debug        : T_CACHE_LINES;

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: entity work.LRU_Cache_16
        port map (
            i_clk          => clk,
            i_rst          => rst,
            i_access_en    => access_en,
            i_access_data  => access_data,
            o_busy         => busy,
            o_hit          => hit,
            o_miss         => miss,
            o_evicted_data => evicted_data,
            o_debug_lines  => debug
        );

    clk <= not clk after CLK_PERIOD / 2;

    process
begin
    -- Reset phase
    rst <= '1';
    wait for 50 ns;
    rst <= '0';
    wait for 20 ns;

    report "=== CACHE TEST START ===";

    for i in 0 to 18 loop
        access_en   <= '1';
        access_data <= std_logic_vector(to_unsigned(i, 8));
        wait for CLK_PERIOD;
        access_en   <= '0';
        wait for 10 ns;  -- small gap to let hit/miss settle

        -- Log result
        if hit = '1' then
            report "Accessed " & integer'image(i) & " -> HIT";
        elsif miss = '1' then
            report "Accessed " & integer'image(i) & " -> MISS (fetching...)";
            
            -- Simulate memory fetch delay on miss
            wait for 300 ns;
            report "Memory fetch done for " & integer'image(i);
        else
            report "Accessed " & integer'image(i) & " -> UNKNOWN (no hit/miss)";
        end if;

        wait for 50 ns;  -- small separation before next access
    end loop;

    report "=== CACHE TEST DONE ===";
    wait for 2 us;
    assert false report "Simulation finished" severity failure;
end process;


end architecture sim;
