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

begin

    o_snoop_addr <= i_bus_addr;

    -- COMBINATORIAL PROCESS: Reacts instantly to snoop hits
    process(i_bus_cmd, i_bus_source_id, i_snoop_hit, i_snoop_mesi)
        variable v_copy_exists : std_logic;
    begin
        o_snoop_check     <= (others => '0');
        o_snoop_update_en <= (others => '0');
        o_snoop_new_state <= (others => "11");
        o_bus_abort       <= '0';
        o_response_mesi   <= (others => "10"); 
        v_copy_exists     := '0';

        -- 1. Trigger Snoops
        if i_bus_cmd = CMD_BUS_RD or i_bus_cmd = CMD_BUS_RDX then
            for i in 0 to 2 loop
                if i /= i_bus_source_id then
                    o_snoop_check(i) <= '1';
                else
                    o_snoop_check(i) <= '0';
                end if;
            end loop;
        end if;

        -- 2. Process Results
        for i in 0 to 2 loop
            if i /= i_bus_source_id then
                if i_snoop_hit(i) = '1' then
                    v_copy_exists := '1';
                    
                    if i_bus_cmd = CMD_BUS_RD then
                        -- If M, Flush and Downgrade
                        if i_snoop_mesi(i) = MESI_M then
                            o_bus_abort <= '1'; 
                            o_snoop_update_en(i) <= '1';
                            o_snoop_new_state(i) <= MESI_S;
                        -- If E, Downgrade
                        elsif i_snoop_mesi(i) = MESI_E then
                            o_snoop_update_en(i) <= '1';
                            o_snoop_new_state(i) <= MESI_S;
                        end if;

                    elsif i_bus_cmd = CMD_BUS_RDX then
                        if i_snoop_mesi(i) /= MESI_I then
                            o_snoop_update_en(i) <= '1';
                            o_snoop_new_state(i) <= MESI_I;
                            if i_snoop_mesi(i) = MESI_M then
                                o_bus_abort <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end loop;

        -- 3. Response
        if v_copy_exists = '1' then
            o_response_mesi(i_bus_source_id) <= MESI_S;
        else
            o_response_mesi(i_bus_source_id) <= MESI_E;
        end if;
    end process;

end Behavioral;