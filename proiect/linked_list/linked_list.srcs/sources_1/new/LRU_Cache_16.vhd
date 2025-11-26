library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.LRU_Types.all;

entity LRU_Cache_16 is
    port (
        i_clk          : in  std_logic;
        i_rst          : in  std_logic;
        i_access_en    : in  std_logic;
        i_access_data  : in  T_DATA;
        o_busy         : out std_logic;
        o_hit          : out std_logic;
        o_miss         : out std_logic;
        o_evicted_data : out T_DATA;
        o_debug_lines  : out T_CACHE_LINES  -- ? debug output
    );
end entity LRU_Cache_16;

architecture Behavioral of LRU_Cache_16 is

    type T_STATE is (S_IDLE, S_HIT_SHIFT, S_MISS_SHIFT);

    signal r_cache_lines  : T_CACHE_LINES := (others => (others => '0'));
    signal r_state        : T_STATE := S_IDLE;
    signal r_target_index : integer range 0 to C_DEPTH - 1 := 0;
    signal r_shift_counter: integer range 0 to C_DEPTH := 0;
    signal r_temp_data    : T_DATA := (others => '0');
    signal s_hit          : std_logic := '0';
    signal s_hit_index    : integer range 0 to C_DEPTH - 1 := 0;
    signal s_miss       : std_logic := '0'; 
    signal r_evicted_data : T_DATA := (others => '0');

begin

    -- Combinational "CAM" search
    process (i_access_data)
        variable v_hit : std_logic := '0';
        variable v_hit_index : integer range 0 to C_DEPTH - 1 := 0;
    begin
        v_hit := '0';
        v_hit_index := 0;
    
        for i in 0 to C_DEPTH - 1 loop
            if r_cache_lines(i) = i_access_data then
                v_hit := '1';
                v_hit_index := i;
                exit;
            end if;
        end loop;
    
        -- Now assign signals based on final values
        s_hit       <= v_hit;
        s_hit_index <= v_hit_index;
        s_miss      <= not v_hit;
    end process;


    -- Main FSM
    process (i_clk, i_rst)
        variable v_next_data : T_DATA;
    begin
        if i_rst = '1' then
            r_cache_lines  <= (others => (others => '0'));
            r_state        <= S_IDLE;
            r_target_index <= 0;
            r_shift_counter<= 0;
            r_evicted_data <= (others => '0');
        elsif rising_edge(i_clk) then
            case r_state is
                when S_IDLE =>
                    if i_access_en = '1' then
                        if s_hit = '1' then
                            if s_hit_index > 0 then
                                -- Move hit to front
                                r_temp_data <= r_cache_lines(s_hit_index);
                                for j in s_hit_index downto 1 loop
                                    r_cache_lines(j) <= r_cache_lines(j-1);
                                end loop;
                                r_cache_lines(0) <= r_temp_data;
                            end if;
                        else
                            -- Miss: shift down all and insert new
                            r_evicted_data <= r_cache_lines(C_DEPTH - 1);
                            for j in C_DEPTH - 1 downto 1 loop
                                r_cache_lines(j) <= r_cache_lines(j-1);
                            end loop;
                            r_cache_lines(0) <= i_access_data;
                        end if;
                    end if;
                    
                    
                when others =>
                    r_state <= S_IDLE;
            end case;
        end if;
    end process;

    o_busy         <= '0' when r_state = S_IDLE else '1';
    o_hit          <= s_hit;
    o_miss         <= s_miss;
    o_evicted_data <= r_evicted_data;
    o_debug_lines  <= r_cache_lines; -- ? debug output

end architecture Behavioral;
