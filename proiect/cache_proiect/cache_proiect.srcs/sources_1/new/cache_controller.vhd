library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.Cache_Types.all;

entity cache_controller is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        i_bus_addr      : in std_logic_vector(15 downto 0);
        i_bus_cmd       : in std_logic_vector(1 downto 0);
        i_bus_source_id : in integer range 0 to 2;
        o_bus_abort     : out std_logic;
        o_snoop_addr    : out std_logic_vector(15 downto 0);
        o_snoop_check   : out std_logic_vector(2 downto 0);
        i_snoop_hit     : in  std_logic_vector(2 downto 0);
        i_snoop_mesi    : in  t_mesi_array;
        o_snoop_update_en : out std_logic_vector(2 downto 0);
        o_snoop_new_state : out t_mesi_array;
        o_response_mesi   : out t_mesi_array 
    );
end cache_controller;

architecture Behavioral of cache_controller is
    constant MESI_M : std_logic_vector(1 downto 0) := "00";
    constant MESI_E : std_logic_vector(1 downto 0) := "01";
    constant MESI_S : std_logic_vector(1 downto 0) := "10";
    constant MESI_I : std_logic_vector(1 downto 0) := "11";
    constant CMD_BUS_RD  : std_logic_vector(1 downto 0) := "01";
    constant CMD_BUS_RDX : std_logic_vector(1 downto 0) := "10";

    signal s_abort_internal : std_logic;
    signal r_flush_counter : integer range 0 to 3 := 0;

begin

    o_snoop_addr <= i_bus_addr;
    o_bus_abort  <= s_abort_internal;

    -- 1. Sequential Process: Flush Timer
    process(clk, rst)
    begin
        if rst = '1' then
            r_flush_counter <= 0;
        elsif rising_edge(clk) then
            if s_abort_internal = '1' then
                if r_flush_counter < 2 then
                    r_flush_counter <= r_flush_counter + 1;
                end if;
            else
                r_flush_counter <= 0;
            end if;
        end if;
    end process;

    -- 2. Combinatorial Process: Control Logic
    process(i_bus_cmd, i_bus_source_id, i_snoop_hit, i_snoop_mesi, r_flush_counter)
        variable v_copy_exists : std_logic;
        variable v_needs_flush : std_logic;
    begin
        o_snoop_check     <= (others => '0');
        o_snoop_update_en <= (others => '0');
        o_snoop_new_state <= (others => "11");
        s_abort_internal  <= '0';
        o_response_mesi   <= (others => "10"); 
        v_copy_exists     := '0';
        v_needs_flush     := '0';

        -- A. Trigger Snoops
        if i_bus_cmd = CMD_BUS_RD or i_bus_cmd = CMD_BUS_RDX then
            for i in 0 to 2 loop
                if i /= i_bus_source_id then
                    o_snoop_check(i) <= '1';
                else
                    o_snoop_check(i) <= '0';
                end if;
            end loop;
        end if;

        -- B. Analyze Snoop Results
        for i in 0 to 2 loop
            if i /= i_bus_source_id then
                if i_snoop_hit(i) = '1' then
                    v_copy_exists := '1';
                    if i_snoop_mesi(i) = MESI_M then
                        v_needs_flush := '1';
                    end if;
                end if;
            end if;
        end loop;

        -- C. Execute Logic (with Flush Timing)
        if v_needs_flush = '1' then
            -- M State Detected: Abort immediately to trigger RAM Write
            s_abort_internal <= '1';
            
            -- Only allow state change after 2 cycles of flushing
            if r_flush_counter >= 2 then
                for i in 0 to 2 loop
                    if i /= i_bus_source_id and i_snoop_hit(i)='1' then
                        o_snoop_update_en(i) <= '1';
                        if i_bus_cmd = CMD_BUS_RD then
                            o_snoop_new_state(i) <= MESI_S;
                        else
                            o_snoop_new_state(i) <= MESI_I;
                        end if;
                    end if;
                end loop;
            end if;
        else
            -- No Flush needed: Standard MESI updates
             for i in 0 to 2 loop
                if i /= i_bus_source_id and i_snoop_hit(i)='1' then
                    -- If Shared or Exclusive, update immediately
                    if i_snoop_mesi(i) /= MESI_M then
                        o_snoop_update_en(i) <= '1';
                        if i_bus_cmd = CMD_BUS_RD then
                            o_snoop_new_state(i) <= MESI_S;
                        else
                            o_snoop_new_state(i) <= MESI_I;
                        end if;
                    end if;
                end if;
            end loop;
        end if;

        -- D. Response to Requestor
        if v_copy_exists = '1' then
            o_response_mesi(i_bus_source_id) <= MESI_S;
        else
            o_response_mesi(i_bus_source_id) <= MESI_E;
        end if;

    end process;
end Behavioral;