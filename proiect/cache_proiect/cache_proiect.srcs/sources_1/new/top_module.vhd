library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.Cache_Types.all; 

entity top_module is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        cmd0_en, cmd0_rw : in std_logic;
        cmd0_addr : in std_logic_vector(15 downto 0);
        cmd0_data : in std_logic_vector(7 downto 0);
        sts0_done : out std_logic;
        sts0_data : out std_logic_vector(7 downto 0);

        cmd1_en, cmd1_rw : in std_logic;
        cmd1_addr : in std_logic_vector(15 downto 0);
        cmd1_data : in std_logic_vector(7 downto 0);
        sts1_done : out std_logic;
        sts1_data : out std_logic_vector(7 downto 0);

        cmd2_en, cmd2_rw : in std_logic;
        cmd2_addr : in std_logic_vector(15 downto 0);
        cmd2_data : in std_logic_vector(7 downto 0);
        sts2_done : out std_logic;
        sts2_data : out std_logic_vector(7 downto 0)
    );
end top_module;

architecture Structural of top_module is

    -- Signals
    signal s_cpu_addr      : t_addr_array;
    signal s_cpu_wdata     : t_data8_array;
    signal s_cpu_rdata     : t_data8_array;
    signal s_cpu_read      : t_bit_array;
    signal s_cpu_write     : t_bit_array;
    signal s_cpu_hit       : t_bit_array;

    signal s_mem_req       : std_logic_vector(2 downto 0);
    signal s_mem_addr      : t_addr_array;
    signal s_mem_rwitm     : std_logic_vector(2 downto 0);
    signal s_cache_out     : t_evict_array;
    signal s_brd_data      : t_data32_array;
    signal s_brd_mesi      : t_mesi_array;
    
    signal s_snoop_addr      : std_logic_vector(15 downto 0);
    signal s_snoop_check     : std_logic_vector(2 downto 0);
    signal s_snoop_hit       : std_logic_vector(2 downto 0);
    signal s_snoop_mesi      : t_mesi_array;
    signal s_snoop_update_en : std_logic_vector(2 downto 0);
    signal s_snoop_new_st    : t_mesi_array;
    signal s_mesi_response   : t_mesi_array; 

    signal s_cache_wb_en     : std_logic_vector(2 downto 0);
    signal s_grant_id        : integer range 0 to 2;
    signal s_bus_active      : std_logic;
    signal s_bus_abort       : std_logic;

    signal s_sys_addr        : std_logic_vector(15 downto 0);
    signal s_sys_cmd         : std_logic_vector(1 downto 0); 
    signal s_sys_wdata       : std_logic_vector(31 downto 0);

    signal s_ram_rdata       : std_logic_vector(31 downto 0);
    signal s_ram_read        : std_logic;
    signal s_ram_write       : std_logic;
    signal s_ram_addr_in     : std_logic_vector(15 downto 0);
    
    signal s_snoop_data_mux  : std_logic_vector(31 downto 0);
    signal s_evict_addr      : std_logic_vector(15 downto 0);
    
    signal s_ram_ready_delayed : std_logic;
    signal s_mem_counter       : integer range 0 to 10 := 0;
    
    signal arr_cmd_en    : std_logic_vector(0 to 2);
    signal arr_cmd_rw    : std_logic_vector(0 to 2);
    signal arr_cmd_addr  : t_addr_array;
    signal arr_cmd_data  : t_data8_array;
    signal arr_sts_done  : std_logic_vector(0 to 2);
    signal arr_sts_data  : t_data8_array;
    
    constant CMD_BUS_RD  : std_logic_vector(1 downto 0) := "01";
    constant CMD_BUS_RDX : std_logic_vector(1 downto 0) := "10";
    constant CMD_NOP     : std_logic_vector(1 downto 0) := "00";

begin

    arr_cmd_en(0)   <= cmd0_en;   
    arr_cmd_en(1)   <= cmd1_en;   
    arr_cmd_en(2)   <= cmd2_en;
    
    arr_cmd_rw(0)   <= cmd0_rw;   
    arr_cmd_rw(1)   <= cmd1_rw;   
    arr_cmd_rw(2)   <= cmd2_rw;
    
    arr_cmd_addr(0) <= cmd0_addr; 
    arr_cmd_addr(1) <= cmd1_addr; 
    arr_cmd_addr(2) <= cmd2_addr;
    
    arr_cmd_data(0) <= cmd0_data; 
    arr_cmd_data(1) <= cmd1_data; 
    arr_cmd_data(2) <= cmd2_data;

    sts0_done <= arr_sts_done(0); 
    sts1_done <= arr_sts_done(1); 
    sts2_done <= arr_sts_done(2);
    
    sts0_data <= arr_sts_data(0); 
    sts1_data <= arr_sts_data(1); 
    sts2_data <= arr_sts_data(2);

    u_Arbiter : entity work.Bus_Arbiter
    port map (
        clk => clk, 
        rst => rst,
        i_req => s_mem_req, 
        o_grant_id => s_grant_id, 
        o_bus_active => s_bus_active
    );

    u_Controller : entity work.cache_controller
    port map (
        clk => clk, 
        rst => rst,
        i_bus_addr => s_sys_addr, 
        i_bus_cmd => s_sys_cmd, 
        i_bus_source_id => s_grant_id,
        o_bus_abort => s_bus_abort, 
        o_snoop_addr => s_snoop_addr, 
        o_snoop_check => s_snoop_check,
        i_snoop_hit => s_snoop_hit, 
        i_snoop_mesi => s_snoop_mesi,
        o_snoop_update_en => s_snoop_update_en, 
        o_snoop_new_state => s_snoop_new_st,
        o_response_mesi => s_mesi_response 
    );

    -- Route Snooped Data
    process(s_snoop_hit, s_brd_data)
    begin
        s_snoop_data_mux <= (others => '0');
        if s_snoop_hit(0) = '1' then 
            s_snoop_data_mux <= s_brd_data(0);
        elsif s_snoop_hit(1) = '1' then 
            s_snoop_data_mux <= s_brd_data(1);
        elsif s_snoop_hit(2) = '1' then 
            s_snoop_data_mux <= s_brd_data(2);
        end if;
    end process;

    --write back 
    s_evict_addr <= s_cache_out(s_grant_id)(47 downto 34) & "00";

    s_ram_addr_in <= s_evict_addr when s_cache_wb_en(s_grant_id) = '1' else s_sys_addr;

    s_ram_write <= '1' when (s_bus_active = '1' and s_cache_wb_en(s_grant_id) = '1') 
              else '1' when (s_bus_active = '1' and s_bus_abort = '1') 
              else '0';

    s_ram_read  <= '1' when (s_bus_active = '1' and (s_sys_cmd = CMD_BUS_RD or s_sys_cmd = CMD_BUS_RDX) 
                             and s_cache_wb_en(s_grant_id) = '0' 
                             and s_bus_abort = '0') 
              else '0';

    s_sys_wdata <= s_cache_out(s_grant_id)(31 downto 0) when s_cache_wb_en(s_grant_id) = '1' 
              else s_snoop_data_mux                     when s_bus_abort = '1'
              else (others => '0');
              
    --s_ram_ready_delayed <= s_bus_active and (not s_bus_abort);

    process(clk, rst)
    begin
        if rst = '1' then
            s_mem_counter <= 0; 
            s_ram_ready_delayed <= '0';
        elsif rising_edge(clk) then
            if s_bus_active = '0' or s_bus_abort = '1' then
                s_mem_counter <= 0;
                s_ram_ready_delayed <= '0';
            else
                if s_mem_counter < 4 then
                    s_mem_counter <= s_mem_counter + 1;
                    s_ram_ready_delayed <= '0';
                else
                    s_ram_ready_delayed <= '1';
                end if;
            end if;
        end if;
    end process;

    u_RAM : entity work.RAM
    port map (
        i_clk => clk, 
        i_address => s_ram_addr_in,
        o_data => s_ram_rdata, 
        i_data => s_sys_wdata, 
        i_read => s_ram_read, 
        i_write => s_ram_write
    );

    --the bus grant
    process(s_grant_id, s_mem_addr, s_mem_rwitm, s_bus_active)
    begin
        if s_bus_active = '0' then
            s_sys_addr <= (others => '0'); 
            s_sys_cmd  <= CMD_NOP;
        else
            s_sys_addr <= s_mem_addr(s_grant_id);
            if s_mem_rwitm(s_grant_id) = '1' then 
                s_sys_cmd <= CMD_BUS_RDX; 
            else 
                s_sys_cmd <= CMD_BUS_RD; 
            end if;
        end if;
    end process;

    gen_cores: for i in 0 to 2 generate
        u_CPU : entity work.cpu
        port map (
            clk => clk, rst => rst,
            cmd_enable => arr_cmd_en(i),
            cmd_rw => arr_cmd_rw(i),
            cmd_addr => arr_cmd_addr(i), 
            cmd_data_in => arr_cmd_data(i),
            status_done => arr_sts_done(i), 
            status_data_out => arr_sts_data(i),
            o_address_cpu => s_cpu_addr(i), 
            o_write_data_cpu => s_cpu_wdata(i),
            o_read => s_cpu_read(i), 
            o_write => s_cpu_write(i),
            i_read_data_cpu => s_cpu_rdata(i), 
            i_hit => s_cpu_hit(i)
        );

        u_Cache : entity work.cache
        port map (
            i_clk => clk, 
            i_rst => rst,
            i_address_cpu => s_cpu_addr(i), 
            i_write_data_cpu => s_cpu_wdata(i),
            i_read => s_cpu_read(i), 
            i_write => s_cpu_write(i),
            o_read_data_cpu => s_cpu_rdata(i),
             o_hit => s_cpu_hit(i),
            
            i_address_cc => s_snoop_addr, 
            i_data_request => s_snoop_check(i), 
            i_invalidate => '0',
            i_snoop_update_en => s_snoop_update_en(i), 
            i_snoop_new_state => s_snoop_new_st(i),
            o_snoop_hit => s_snoop_hit(i),
            
            i_mem_ready => s_ram_ready_delayed, 
            
            i_mem_data => s_ram_rdata, 
            i_mesi_cc => s_mesi_response(i),         
            o_mem_request => s_mem_req(i), 
            o_mem_address => s_mem_addr(i),
            o_rwitm => s_mem_rwitm(i), 
            o_writeback_en => s_cache_wb_en(i),
            o_data_out => s_cache_out(i), 
            o_data_broadcast => s_brd_data(i), 
            o_mesi_cache => s_snoop_mesi(i), 
            o_invalidate => open
        );
    end generate gen_cores;

end Structural;