library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity cache is
    Port (i_clk:in std_logic;
          i_rst:in std_logic;
          i_address_cpu:in std_logic_vector(15 downto 0);--address of the data that the cpu needs
          i_write_data_cpu: in std_logic_vector(7 downto 0);--the data that needs to be writen in the memory
          i_read: in std_logic;--the read signal
          i_write: in std_logic;--the write signal
          i_address_cc: in std_logic_vector(15 downto 0);--address from the cache controler to check if there is present a data in the cache
          i_invalidate: in std_logic;--if the data is in the cache that line needs to become invalid
          i_mesi_cc: in std_logic_vector(1 downto 0);
          i_mem_ready: in  std_logic;--the signal that the data requested is ready        
          i_mem_data: in  std_logic_vector(31 downto 0);   -- the data needed
          i_data_request: in std_logic;
          o_rwitm: out std_logic;--signal to indicate that we have the intent to modify the data once we have it
          o_invalidate: out std_logic;--broadcastin to invalidate a line     
          o_data_broadcast : out std_logic_vector(31 downto 0);   
          o_data_out: out std_logic_vector(47 downto 0);--the data that is ejected from the cache
          o_mesi_cache: out std_logic_vector(1 downto 0);--the mesi bits that have the state of a line
          o_read_data_cpu: out std_logic_vector(7 downto 0);--the data needed by the cpu
          o_mem_request : out std_logic; --if we do not have the data that we need we make a request
          o_mem_address : out std_logic_vector(15 downto 0);--the address of the data that we requested
          o_hit : out std_logic);
end cache;

architecture Behavioral of cache is
    type cache_array_type is array (15 downto 0) of std_logic_vector(47 downto 0);
    type T_STATE is (S_IDLE, S_MISS_WAIT_WRITE, S_MISS_WAIT_READ, S_HIT_SHARED);
    
    signal r_cache_lines: cache_array_type:=(others => (others => '0'));
    signal r_state: T_STATE:= S_IDLE;
    signal r_target_index: integer range 0 to 15 := 0;
    signal s_hit: std_logic := '0';
    signal s_hit_index: integer range 0 to 15 := 0;
    signal s_miss: std_logic := '0';

begin

    process (i_clk, i_rst)
        variable v_hit : std_logic := '0';
        variable v_hit_index : integer range 0 to 15 := 0;
        variable v_temp_data: std_logic_vector(47 downto 0):= (others => '0');
        variable v_evicted_data: std_logic_vector(47 downto 0):= (others => '0');
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
        
        
        
        s_hit <= v_hit;
        s_hit_index <= v_hit_index;
        
        if i_rst = '1' then
            r_cache_lines  <= (others => (others => '0'));
            r_target_index <= 0;
            o_invalidate <= '0';
            v_evicted_data := (others => '0');
        elsif rising_edge(i_clk) then
            if i_data_request = '1' then
                for i in 0 to 15 loop
                    if r_cache_lines(i)(47 downto 34) = i_address_cc(15 downto 2) then
                        o_data_broadcast <= r_cache_lines(i)(31 downto 0);
                        o_mesi_cache <= r_cache_lines(i)(33 downto 32);
                        exit;
                    end if;
                end loop;
            end if;
            if(i_invalidate = '1') then
                for i in 0 to 15 loop
                    if r_cache_lines(i)(47 downto 34) = i_address_cc(15 downto 2) then
                        r_cache_lines(i)(33 downto 32) <= "11";
                        exit;
                    end if;
                end loop;
            end if;
            case r_state is
                when S_IDLE =>
                    if (i_write = '1') xor (i_read = '1') then
                        if v_hit = '1' then
                            if v_hit_index > 0 then
                                v_temp_data := r_cache_lines(v_hit_index);
                                for j in v_hit_index downto 1 loop
                                    r_cache_lines(j) <= r_cache_lines(j-1);--index
                                end loop;
                                r_cache_lines(0) <= v_temp_data;
                            end if;
                            if i_write = '1' then
                                if r_cache_lines(0)(33 downto 32) = "01" then --exclusive
                                   r_cache_lines(0)(33 downto 32) <= "00"; 
                                elsif r_cache_lines(0)(33 downto 32) = "10" then --shared
                                    --invalidate add invalidate signal
                                    o_invalidate <= '1';
                                    o_mem_address<=i_address_cpu;
                                    r_cache_lines(0)(33 downto 32) <= "00";
                                    r_state <= S_HIT_SHARED;
                                end if;
                                
                                case i_address_cpu(1 downto 0) is
                                    when "00"=> r_cache_lines(0)(31 downto 24)<=i_write_data_cpu;
                                    when "01"=> r_cache_lines(0)(23 downto 16)<=i_write_data_cpu;
                                    when "10"=> r_cache_lines(0)(15 downto 8)<=i_write_data_cpu;
                                    when "11"=> r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                                    when others => r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                                end case;
                            end if;
                            if i_read = '1' then
                                case i_address_cpu(1 downto 0) is
                                    when "00"=> o_read_data_cpu <= r_cache_lines(0)(31 downto 24);
                                    when "01"=> o_read_data_cpu <= r_cache_lines(0)(23 downto 16);
                                    when "10"=> o_read_data_cpu <= r_cache_lines(0)(15 downto 8);
                                    when "11"=> o_read_data_cpu <= r_cache_lines(0)(7 downto 0);
                                    when others => r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                                end case;   
                            end if;
                            
                        else
                            o_mem_request<='1';
                            o_mem_address<=i_address_cpu;
                            if i_write = '1' then
                                o_rwitm <= '1';
                                r_state <= S_MISS_WAIT_WRITE;
                            elsif i_read = '1' then
                                r_state <= S_MISS_WAIT_READ;
                            end if;
                            
                        end if;
                    end if;
            when S_HIT_SHARED =>
                o_invalidate <= '0';
                r_state <= S_IDLE;
            when S_MISS_WAIT_WRITE =>
                o_mem_request <= '0';
                o_rwitm <= '0';
                if i_mem_ready = '1' then
                    v_evicted_data := r_cache_lines(15);
                    for j in 15 downto 1 loop
                        r_cache_lines(j) <= r_cache_lines(j-1);--
                    end loop;
                    o_data_out<=v_evicted_data;
                    r_cache_lines(0) <= i_address_cpu(15 downto 2) & i_mesi_cc & i_mem_data;
                    case i_address_cpu(1 downto 0) is
                        when "00"=> r_cache_lines(0)(31 downto 24)<=i_write_data_cpu;
                        when "01"=> r_cache_lines(0)(23 downto 16)<=i_write_data_cpu;
                        when "10"=> r_cache_lines(0)(15 downto 8)<=i_write_data_cpu;
                        when "11"=> r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                        when others => r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                    end case;
                    r_state <= S_IDLE;
                end if;
            when S_MISS_WAIT_READ =>
                o_mem_request <= '0';
                if i_mem_ready = '1' then
                    v_evicted_data := r_cache_lines(15);
                    for j in 15 downto 1 loop
                        r_cache_lines(j) <= r_cache_lines(j-1);
                    end loop;
                    r_cache_lines(0) <= i_address_cpu(15 downto 2) & i_mesi_cc & i_mem_data;
                    o_data_out<=v_evicted_data;
                    case i_address_cpu(1 downto 0) is
                        when "00"=> o_read_data_cpu <= r_cache_lines(0)(31 downto 24);
                        when "01"=> o_read_data_cpu <= r_cache_lines(0)(23 downto 16);
                        when "10"=> o_read_data_cpu <= r_cache_lines(0)(15 downto 8);
                        when "11"=> o_read_data_cpu <= r_cache_lines(0)(7 downto 0);
                        when others => r_cache_lines(0)(7 downto 0)<=i_write_data_cpu;
                    end case;
                    r_state <= S_IDLE;
                end if;
            when others =>
                    r_state <= S_IDLE;
            end case;
                    
        end if;
    end process;
    o_hit<=s_hit;
end Behavioral;
