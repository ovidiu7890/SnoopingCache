library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.Cache_Types.all; -- Include your MESI Array package

entity top_module is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- CPU 0 Controls
        cmd0_en   : in std_logic;
        cmd0_rw   : in std_logic;
        cmd0_addr : in std_logic_vector(15 downto 0);
        cmd0_data : in std_logic_vector(7 downto 0);
        sts0_done : out std_logic;
        sts0_data : out std_logic_vector(7 downto 0);

        -- CPU 1 Controls
        cmd1_en   : in std_logic;
        cmd1_rw   : in std_logic;
        cmd1_addr : in std_logic_vector(15 downto 0);
        cmd1_data : in std_logic_vector(7 downto 0);
        sts1_done : out std_logic;
        sts1_data : out std_logic_vector(7 downto 0);

        -- CPU 2 Controls
        cmd2_en   : in std_logic;
        cmd2_rw   : in std_logic;
        cmd2_addr : in std_logic_vector(15 downto 0);
        cmd2_data : in std_logic_vector(7 downto 0);
        sts2_done : out std_logic;
        sts2_data : out std_logic_vector(7 downto 0)
    );
end top_module;

architecture Structural of top_module is

    -- =======================================================
    -- SIGNAL DECLARATIONS
    -- =======================================================

    -- CPU <-> Cache Signals (Arrays)
    signal s_cpu_addr      : t_addr_array;
    signal s_cpu_wdata     : t_data8_array;
    signal s_cpu_rdata     : t_data8_array;
    signal s_cpu_read      : t_bit_array;
    signal s_cpu_write     : t_bit_array;
    signal s_cpu_hit       : t_bit_array;

    -- Cache <-> Bus Signals
    signal s_mem_req       : std_logic_vector(2 downto 0); -- To Arbiter
    signal s_mem_addr      : t_addr_array;
    signal s_mem_rwitm     : std_logic_vector(2 downto 0); -- Read With Intent To Modify
    signal s_cache_out     : t_evict_array;                -- Data evicted from cache
    signal s_brd_data      : t_data32_array;
    signal s_brd_mesi      : t_mesi_array;
    
    -- Controller <-> Cache Signals
    signal s_snoop_addr      : std_logic_vector(15 downto 0);
    signal s_snoop_check     : std_logic_vector(2 downto 0);
    signal s_snoop_hit       : std_logic_vector(2 downto 0);
    signal s_snoop_mesi      : t_mesi_array;
    signal s_snoop_update_en : std_logic_vector(2 downto 0);
    signal s_snoop_new_st    : t_mesi_array;
    signal s_mesi_response   : t_mesi_array; -- New: Response from Controller (E vs S)

    -- Write-Back Signals
    signal s_cache_wb_en     : std_logic_vector(2 downto 0);

    -- Bus Arbiter Signals
    signal s_grant_id        : integer range 0 to 2;
    signal s_bus_active      : std_logic;
    signal s_bus_abort       : std_logic; -- From Controller

    -- Muxed Bus Signals (The "System Bus")
    signal s_sys_addr        : std_logic_vector(15 downto 0);
    signal s_sys_cmd         : std_logic_vector(1 downto 0); -- 01: Rd, 10: RdX
    signal s_sys_wdata       : std_logic_vector(31 downto 0); -- Data to RAM

    -- RAM Signals
    signal s_ram_rdata       : std_logic_vector(31 downto 0);
    signal s_ram_read        : std_logic;
    signal s_ram_write       : std_logic;
    
    -- Intermediate Arrays for CPU Interface (Scalar -> Array packing)
    signal arr_cmd_en    : std_logic_vector(0 to 2);
    signal arr_cmd_rw    : std_logic_vector(0 to 2);
    signal arr_cmd_addr  : t_addr_array;
    signal arr_cmd_data  : t_data8_array;
    
    signal arr_sts_done  : std_logic_vector(0 to 2);
    signal arr_sts_data  : t_data8_array;
    
    -- Helper constants
    constant CMD_BUS_RD  : std_logic_vector(1 downto 0) := "01";
    constant CMD_BUS_RDX : std_logic_vector(1 downto 0) := "10";
    constant CMD_NOP     : std_logic_vector(1 downto 0) := "00";

begin

    -- =======================================================
    -- PACK INPUTS (Scalars -> Arrays)
    -- =======================================================
    arr_cmd_en(0)   <= cmd0_en;   arr_cmd_en(1)   <= cmd1_en;   arr_cmd_en(2)   <= cmd2_en;
    arr_cmd_rw(0)   <= cmd0_rw;   arr_cmd_rw(1)   <= cmd1_rw;   arr_cmd_rw(2)   <= cmd2_rw;
    arr_cmd_addr(0) <= cmd0_addr; arr_cmd_addr(1) <= cmd1_addr; arr_cmd_addr(2) <= cmd2_addr;
    arr_cmd_data(0) <= cmd0_data; arr_cmd_data(1) <= cmd1_data; arr_cmd_data(2) <= cmd2_data;

    -- =======================================================
    -- UNPACK OUTPUTS (Arrays -> Scalars)
    -- =======================================================
    sts0_done <= arr_sts_done(0); sts1_done <= arr_sts_done(1); sts2_done <= arr_sts_done(2);
    sts0_data <= arr_sts_data(0); sts1_data <= arr_sts_data(1); sts2_data <= arr_sts_data(2);

    -- =======================================================
    -- 1. INSTANTIATE ARBITER
    -- =======================================================
    u_Arbiter : entity work.Bus_Arbiter
    port map (
        clk          => clk,
        rst          => rst,
        i_req        => s_mem_req,
        o_grant_id   => s_grant_id,
        o_bus_active => s_bus_active
    );

    -- =======================================================
    -- 2. INSTANTIATE CONTROLLER
    -- =======================================================
    u_Controller : entity work.cache_controller
    port map (
        clk               => clk,
        rst               => rst,
        i_bus_addr        => s_sys_addr,
        i_bus_cmd         => s_sys_cmd,
        i_bus_source_id   => s_grant_id,
        o_bus_abort       => s_bus_abort,
        o_snoop_addr      => s_snoop_addr,
        o_snoop_check     => s_snoop_check,
        i_snoop_hit       => s_snoop_hit,
        i_snoop_mesi      => s_snoop_mesi,
        o_snoop_update_en => s_snoop_update_en,
        o_snoop_new_state => s_snoop_new_st,
        o_response_mesi   => s_mesi_response -- CONNECT NEW PORT
    );

    -- =======================================================
    -- 3. INSTANTIATE RAM (UPDATED FOR WRITE-BACK)
    -- =======================================================
    -- RAM Write Logic:
    -- Write if (Bus Active AND Write Command) OR (Bus Active AND Write-Back Triggered)
    s_ram_write <= '1' when (s_bus_active = '1' and s_sys_cmd = CMD_BUS_RDX and s_bus_abort = '0') 
                       else '1' when (s_bus_active = '1' and s_cache_wb_en(s_grant_id) = '1') -- Handle WB
                       else '0';

    s_ram_read  <= '1' when (s_bus_active = '1' and s_sys_cmd = CMD_BUS_RD and s_bus_abort = '0' and s_cache_wb_en(s_grant_id) = '0') 
                       else '0';

    -- RAM Data Mux
    -- If WB Enable is high, send Evicted Data. Else send nothing (RAM ignores input on Read).
    s_sys_wdata <= s_cache_out(s_grant_id)(31 downto 0) when s_cache_wb_en(s_grant_id) = '1' else (others => '0');

    u_RAM : entity work.RAM
    port map (
        i_clk     => clk,
        i_address => s_sys_addr, -- (Address switching logic would go here for full WB support)
        o_data    => s_ram_rdata,
        i_data    => s_sys_wdata, 
        i_read    => s_ram_read,
        i_write   => s_ram_write
    );

    -- =======================================================
    -- 4. SYSTEM BUS MUX (Multiplexer)
    -- =======================================================
    process(s_grant_id, s_mem_addr, s_mem_rwitm, s_bus_active)
    begin
        if s_bus_active = '0' then
            s_sys_addr <= (others => '0');
            s_sys_cmd  <= CMD_NOP;
        else
            s_sys_addr <= s_mem_addr(s_grant_id);
            
            if s_mem_rwitm(s_grant_id) = '1' then
                s_sys_cmd <= CMD_BUS_RDX; -- Write Intent
            else
                s_sys_cmd <= CMD_BUS_RD;  -- Read Intent
            end if;
        end if;
    end process;


    -- =======================================================
    -- 5. GENERATE 3 CORES (CPU + CACHE)
    -- =======================================================
    gen_cores: for i in 0 to 2 generate
        
        -- A. CPU Instance
        u_CPU : entity work.cpu
        port map (
            clk              => clk,
            rst              => rst,
            
            -- CLEAN MAPPING USING ARRAYS
            cmd_enable       => arr_cmd_en(i),
            cmd_rw           => arr_cmd_rw(i),
            cmd_addr         => arr_cmd_addr(i),
            cmd_data_in      => arr_cmd_data(i),
            
            status_done      => arr_sts_done(i),
            status_data_out  => arr_sts_data(i),
            
            -- Interface to Cache
            o_address_cpu    => s_cpu_addr(i),
            o_write_data_cpu => s_cpu_wdata(i),
            o_read           => s_cpu_read(i),
            o_write          => s_cpu_write(i),
            i_read_data_cpu  => s_cpu_rdata(i),
            i_hit            => s_cpu_hit(i)
        );

        -- B. Cache Instance
        u_Cache : entity work.cache
        port map (
            i_clk             => clk,
            i_rst             => rst,
            
            -- CPU Side
            i_address_cpu     => s_cpu_addr(i),
            i_write_data_cpu  => s_cpu_wdata(i),
            i_read            => s_cpu_read(i),
            i_write           => s_cpu_write(i),
            o_read_data_cpu   => s_cpu_rdata(i),
            o_hit             => s_cpu_hit(i),
            
            -- Controller Side
            i_address_cc      => s_snoop_addr,       
            i_data_request    => s_snoop_check(i),   
            i_invalidate      => '0',                
            
            i_snoop_update_en => s_snoop_update_en(i),
            i_snoop_new_state => s_snoop_new_st(i),
            o_snoop_hit       => s_snoop_hit(i),
            
            -- Bus Side
            i_mem_ready       => s_bus_active, 
            i_mem_data        => s_ram_rdata,  
            
            -- CONNECT CONTROLLER RESPONSE (E vs S)
            i_mesi_cc         => s_mesi_response(i),         
            
            o_mem_request     => s_mem_req(i),
            o_mem_address     => s_mem_addr(i),
            o_rwitm           => s_mem_rwitm(i),
            
            -- CONNECT NEW WRITE-BACK SIGNALS
            o_writeback_en    => s_cache_wb_en(i),
            o_data_out        => s_cache_out(i),         
            
            -- Broadcasts
            o_data_broadcast  => s_brd_data(i),
            o_mesi_cache      => s_snoop_mesi(i),
            o_invalidate      => open
        );
        
    end generate gen_cores;

end Structural;