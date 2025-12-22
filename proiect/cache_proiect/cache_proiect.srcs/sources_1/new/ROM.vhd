library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ROM is
    Port (
        i_step        : in  integer range 0 to 31;
        o_cpu_id      : out integer range 0 to 2;
        o_addr        : out std_logic_vector(15 downto 0);
        o_rw          : out std_logic; -- 0: Read, 1: Write
        o_data_in     : out std_logic_vector(7 downto 0);
        o_expected    : out std_logic_vector(7 downto 0);
        o_check_en    : out std_logic -- 1: Check Result, 0: Ignore (for Writes)
    );
end ROM;

architecture Behavioral of ROM is
    type t_instr is record
        cpu_id   : integer range 0 to 2;
        addr     : std_logic_vector(15 downto 0);
        rw       : std_logic;
        data_in  : std_logic_vector(7 downto 0);
        expected : std_logic_vector(7 downto 0);
        check    : std_logic;
    end record;
    
    type t_rom is array (0 to 15) of t_instr;
    
    constant ROM : t_rom := (
        -- STEP 0: CPU 0 Read 0x1000 (Cold Miss) -> Expect Random/00 (RAM init 0)
        (0, x"1000", '0', x"00", x"00", '0'),
        
        -- STEP 1: CPU 1 Read 0x1000 (Share) -> Expect Same as CPU 0
        (1, x"1000", '0', x"00", x"00", '0'),
        
        -- STEP 2: CPU 1 Writes 0xAA to 0x1000 (Upgrade to M)
        (1, x"1000", '1', x"AA", x"00", '0'),
        
        -- STEP 3: CPU 0 Reads 0x1000 (Expect 0xAA via Flush)
        (0, x"1000", '0', x"00", x"AA", '1'), -- CHECK ENABLED
        
        -- STEP 4: CPU 2 Writes 0xBB to 0x1000 (Invalidate Others)
        (2, x"1000", '1', x"BB", x"00", '0'),
        
        -- STEP 5: CPU 1 Reads 0x1000 (Expect 0xBB)
        (1, x"1000", '0', x"00", x"BB", '1'), -- CHECK ENABLED
        
        -- STEP 6: Fill Cache 0 (Addr 0x3000, Data 0x10)
        (0, x"3000", '1', x"10", x"00", '0'),
        
        -- STEP 7: Evict 0x3000 by writing 0x4000
        (0, x"4000", '1', x"FF", x"00", '0'),
        
        -- STEP 8: Verify Eviction (CPU 2 Reads 0x3000 -> Expect 0x10 from RAM)
        (2, x"3000", '0', x"00", x"10", '1'), -- CHECK ENABLED
        
        others => (0, x"0000", '0', x"00", x"00", '0')
    );
begin
    process(i_step)
    begin
        if i_step <= 8 then
            o_cpu_id   <= ROM(i_step).cpu_id;
            o_addr     <= ROM(i_step).addr;
            o_rw       <= ROM(i_step).rw;
            o_data_in  <= ROM(i_step).data_in;
            o_expected <= ROM(i_step).expected;
            o_check_en <= ROM(i_step).check;
        else
            o_cpu_id <= 0; o_addr <= (others=>'0'); o_rw <= '0'; 
            o_data_in <= (others=>'0'); o_expected <= (others=>'0'); o_check_en <= '0';
        end if;
    end process;
end Behavioral;