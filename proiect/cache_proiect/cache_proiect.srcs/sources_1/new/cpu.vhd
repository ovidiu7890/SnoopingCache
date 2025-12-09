library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu is
    Port (
        clk              : in std_logic;
        rst              : in std_logic;
        
        -- ============================================================
        -- COMMAND INTERFACE (Control this from your Testbench)
        -- ============================================================
        cmd_enable       : in std_logic;                     -- Pulse '1' to start a transaction
        cmd_rw           : in std_logic;                     -- '0' = Read, '1' = Write
        cmd_addr         : in std_logic_vector(15 downto 0); -- Address to access
        cmd_data_in      : in std_logic_vector(7 downto 0);  -- Data to write (if write)
        
        status_done      : out std_logic;                    -- Goes '1' when transaction finishes
        status_data_out  : out std_logic_vector(7 downto 0); -- Data read back (if read)

        -- ============================================================
        -- CACHE INTERFACE (Connects to your Cache Entity)
        -- ============================================================
        o_address_cpu    : out std_logic_vector(15 downto 0);
        o_write_data_cpu : out std_logic_vector(7 downto 0);
        o_read           : out std_logic;
        o_write          : out std_logic;
        i_read_data_cpu  : in std_logic_vector(7 downto 0);
        i_hit            : in std_logic
    );
end cpu;

architecture Behavioral of cpu is

    type t_state is (S_IDLE, S_ACCESS, S_WAIT_HIT, S_DONE);
    signal r_state : t_state := S_IDLE;
    
    -- Registers to hold command values
    signal r_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal r_data : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_rw   : std_logic := '0'; -- 0: Read, 1: Write

begin

    process(clk, rst)
    begin
        if rst = '1' then
            r_state          <= S_IDLE;
            o_address_cpu    <= (others => '0');
            o_write_data_cpu <= (others => '0');
            o_read           <= '0';
            o_write          <= '0';
            status_done      <= '0';
            status_data_out  <= (others => '0');
            
        elsif rising_edge(clk) then
            
            case r_state is
                -- 1. Wait for command from Testbench
                when S_IDLE =>
                    status_done <= '0';
                    o_read      <= '0';
                    o_write     <= '0';
                    
                    if cmd_enable = '1' then
                        r_addr  <= cmd_addr;
                        r_data  <= cmd_data_in;
                        r_rw    <= cmd_rw;
                        r_state <= S_ACCESS;
                    end if;

                -- 2. Drive signals to Cache
                when S_ACCESS =>
                    o_address_cpu <= r_addr;
                    
                    if r_rw = '1' then
                        -- WRITE
                        o_write_data_cpu <= r_data;
                        o_write          <= '1';
                        o_read           <= '0';
                    else
                        -- READ
                        o_write          <= '0';
                        o_read           <= '1';
                    end if;
                    
                    r_state <= S_WAIT_HIT;

                -- 3. Wait for Cache to return 'Hit'
                -- If it is a Miss, 'i_hit' will stay 0 until memory fetch is done.
                when S_WAIT_HIT =>
                    if i_hit = '1' then
                        -- Transaction Successful
                        if r_rw = '0' then
                            status_data_out <= i_read_data_cpu; -- Capture read data
                        end if;
                        
                        -- Deassert signals
                        o_read  <= '0';
                        o_write <= '0';
                        r_state <= S_DONE;
                    else
                        -- Keep signals asserted and wait (Stall)
                        if r_rw = '1' then
                            o_write <= '1';
                        else
                            o_read  <= '1';
                        end if;
                    end if;

                -- 4. Handshake with Testbench
                when S_DONE =>
                    status_done <= '1';
                    -- Return to IDLE immediately
                    r_state <= S_IDLE;
                    
                when others =>
                    r_state <= S_IDLE;
            end case;
        end if;
    end process;

end Behavioral;