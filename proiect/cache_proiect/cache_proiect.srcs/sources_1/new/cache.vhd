library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity cache is
    Port ( 
        i_clk             : in std_logic;
        i_rst             : in std_logic;
        i_address_cpu     : in std_logic_vector(15 downto 0);
        i_write_data_cpu  : in std_logic_vector(7 downto 0);
        i_read            : in std_logic;
        i_write           : in std_logic;
        o_read_data_cpu   : out std_logic_vector(7 downto 0);
        o_hit             : out std_logic;
        
        i_address_cc      : in std_logic_vector(15 downto 0);
        i_data_request    : in std_logic;
        i_invalidate      : in std_logic; 
        
        i_snoop_update_en : in std_logic;
        i_snoop_new_state : in std_logic_vector(1 downto 0);
        o_snoop_hit       : out std_logic;

        i_mem_ready       : in std_logic;
        i_mem_data        : in std_logic_vector(31 downto 0);
        i_mesi_cc         : in std_logic_vector(1 downto 0);
        
        o_mem_request     : out std_logic;
        o_mem_address     : out std_logic_vector(15 downto 0);
        o_rwitm           : out std_logic;
        o_data_out        : out std_logic_vector(47 downto 0);
        o_writeback_en    : out std_logic;
        o_data_broadcast  : out std_logic_vector(31 downto 0);
        o_mesi_cache      : out std_logic_vector(1 downto 0);
        o_invalidate      : out std_logic
    );
end cache;

architecture Behavioral of cache is
    type cache_array_type is array (15 downto 0) of std_logic_vector(47 downto 0);
    type T_STATE is (S_IDLE, S_MISS_WAIT_WRITE, S_MISS_WAIT_READ);
    
    signal r_cache_lines : cache_array_type := (others => (others => '0'));
    signal r_state       : T_STATE := S_IDLE;
    signal s_hit         : std_logic := '0';
    signal s_hit_index   : integer range 0 to 15 := 0;
    signal r_is_upgrade  : std_logic := '0';
    signal r_is_wb       : std_logic := '0';

begin

    -- 1. CPU Hit Detection
    process(r_cache_lines, i_address_cpu)
        variable v_hit : std_logic;
        variable v_hit_index : integer range 0 to 15;
    begin
        v_hit := '0';
        v_hit_index := 0;
        for i in 0 to 15 loop
            if r_cache_lines(i)(47 downto 34) = i_address_cpu(15 downto 2) then
                if r_cache_lines(i)(33 downto 32) /= "11" then
                    v_hit := '1';
                    v_hit_index := i; 
                    exit;
                end if;
            end if;
        end loop;
        s_hit <= v_hit; s_hit_index <= v_hit_index; o_hit <= v_hit;
    end process;

    -- 2. Snoop Hit Detection
    process(r_cache_lines, i_address_cc, i_data_request)
    begin
        o_snoop_hit      <= '0';
        o_data_broadcast <= (others => '0');
        o_mesi_cache     <= "11"; 

        for i in 0 to 15 loop
            if r_cache_lines(i)(47 downto 34) = i_address_cc(15 downto 2) then
                if r_cache_lines(i)(33 downto 32) /= "11" then
                    o_data_broadcast <= r_cache_lines(i)(31 downto 0);
                    o_mesi_cache     <= r_cache_lines(i)(33 downto 32);
                    if i_data_request = '1' then
                        o_snoop_hit <= '1';
                    end if;
                    exit; 
                end if;
            end if;
        end loop;
    end process;

    -- 3. Main Process 
    process (i_clk, i_rst)
        variable v_temp_data : std_logic_vector(47 downto 0);
        variable v_new_line  : std_logic_vector(47 downto 0);
    begin
        if i_rst = '1' then
            r_cache_lines    <= (others => (others => '0'));
            r_state          <= S_IDLE;
            o_mem_request    <= '0';
            o_rwitm          <= '0'; 
            o_writeback_en   <= '0';
            o_read_data_cpu  <= (others => '0'); 
            o_invalidate     <= '0';
            r_is_upgrade     <= '0';
            r_is_wb          <= '0';
            
        elsif rising_edge(i_clk) then
            o_writeback_en <= r_is_wb;
            --apply snoop update
            if i_data_request = '1' then
                for i in 0 to 15 loop
                    if r_cache_lines(i)(47 downto 34) = i_address_cc(15 downto 2) then
                        if r_cache_lines(i)(33 downto 32) /= "11" then
                            if i_snoop_update_en = '1' then
                                if r_cache_lines(i)(33 downto 32) = "00" then
                                    -- Wait for RAM Ready before downgrading state
                                    if i_mem_ready = '1' then
                                        r_cache_lines(i)(33 downto 32) <= i_snoop_new_state;
                                    end if;
                                else
                                    -- Not flushing , update immediately
                                    r_cache_lines(i)(33 downto 32) <= i_snoop_new_state;
                                end if;
                            end if;
                            exit;
                        end if;
                    end if;
                end loop;
            end if;

            -- CPU STATE MACHINE
            case r_state is
                when S_IDLE =>
                    if (i_write = '1') or (i_read = '1') then
                        if s_hit = '1' then
                            if s_hit_index > 0 then
                                v_temp_data := r_cache_lines(s_hit_index);
                                for j in 15 downto 1 loop
                                    if j <= s_hit_index then r_cache_lines(j) <= r_cache_lines(j-1); end if;
                                end loop;
                                r_cache_lines(0) <= v_temp_data;
                            end if;
                            
                            if i_write = '1' then
                                if r_cache_lines(0)(33 downto 32) = "10" then 
                                    o_mem_request <= '1';
                                    o_mem_address <= i_address_cpu;
                                    o_rwitm       <= '1'; 
                                    r_is_upgrade  <= '1';
                                    r_state       <= S_MISS_WAIT_WRITE; 
                                else
                                    r_cache_lines(0)(33 downto 32) <= "00";
                                    case i_address_cpu(1 downto 0) is
                                        when "00" => r_cache_lines(0)(31 downto 24) <= i_write_data_cpu;
                                        when "01" => r_cache_lines(0)(23 downto 16) <= i_write_data_cpu;
                                        when "10" => r_cache_lines(0)(15 downto 8)  <= i_write_data_cpu;
                                        when "11" => r_cache_lines(0)(7 downto 0)   <= i_write_data_cpu;
                                        when others => null;
                                    end case;
                                end if;
                            end if;
                            if i_read = '1' then
                                case i_address_cpu(1 downto 0) is
                                    when "00" => o_read_data_cpu <= r_cache_lines(0)(31 downto 24);
                                    when "01" => o_read_data_cpu <= r_cache_lines(0)(23 downto 16);
                                    when "10" => o_read_data_cpu <= r_cache_lines(0)(15 downto 8);
                                    when "11" => o_read_data_cpu <= r_cache_lines(0)(7 downto 0);
                                    when others => null;
                                end case;
                            end if;
                        else
                            r_is_upgrade  <= '0';
                            o_mem_request <= '1'; 
                            o_mem_address <= i_address_cpu;
                            if r_cache_lines(15)(33 downto 32) = "00" then
                                r_is_wb        <= '1';
                                o_writeback_en <= '1';
                                o_data_out     <= r_cache_lines(15);
                            end if;
                            if i_write = '1' then
                                o_rwitm <= '1';
                                r_state <= S_MISS_WAIT_WRITE;
                            elsif i_read = '1' then
                                o_rwitm <= '0';
                                r_state <= S_MISS_WAIT_READ;
                            end if;
                        end if;
                    end if;

                when S_MISS_WAIT_WRITE =>
                    o_mem_request <= '1';
                    o_rwitm <= '1';
                    
                    if i_mem_ready = '1' then
                        o_mem_request  <= '0';
                        o_rwitm        <= '0';
                        r_is_wb        <= '0';
                        o_writeback_en <= '0';
                        if r_is_upgrade = '0' then
                            for j in 15 downto 1 loop r_cache_lines(j) <= r_cache_lines(j-1); end loop;
                        end if;
                        v_new_line := i_address_cpu(15 downto 2) & "00" & i_mem_data;
                        case i_address_cpu(1 downto 0) is
                            when "00" => v_new_line(31 downto 24) := i_write_data_cpu;
                            when "01" => v_new_line(23 downto 16) := i_write_data_cpu;
                            when "10" => v_new_line(15 downto 8)  := i_write_data_cpu;
                            when "11" => v_new_line(7 downto 0)   := i_write_data_cpu;
                            when others => null;
                        end case;
                        r_cache_lines(0) <= v_new_line;
                        r_state <= S_IDLE;
                    end if;

                when S_MISS_WAIT_READ =>
                    o_mem_request <= '1';
                    o_rwitm <= '0';
                    if i_mem_ready = '1' then
                        o_mem_request  <= '0';
                        r_is_wb        <= '0';
                        o_writeback_en <= '0';
                        for j in 15 downto 1 loop r_cache_lines(j) <= r_cache_lines(j-1); end loop;
                        v_new_line := i_address_cpu(15 downto 2) & i_mesi_cc & i_mem_data;
                        r_cache_lines(0) <= v_new_line;
                        case i_address_cpu(1 downto 0) is
                            when "00" => o_read_data_cpu <= v_new_line(31 downto 24);
                            when "01" => o_read_data_cpu <= v_new_line(23 downto 16);
                            when "10" => o_read_data_cpu <= v_new_line(15 downto 8);
                            when "11" => o_read_data_cpu <= v_new_line(7 downto 0);
                            when others => null;
                        end case;
                        r_state <= S_IDLE;
                    end if;

                when others => r_state <= S_IDLE;
            end case;
        end if;
    end process;
end Behavioral;