library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Frecuencia_Bobinas is
generic(
    CLK_FREQ : integer := 50000000; -- Frecuencia del FPGA (Hz)
    STEP_FREQ: integer := 100     -- Frecuencia deseada (Hz)
);
port( 
    clk           : in  std_logic;
    rst           : in  std_logic;
    tick_bobinas  : out std_logic
);
end Frecuencia_Bobinas;

architecture Behavioral of Frecuencia_Bobinas is

-- cálculo automático del divisor
constant MAX_COUNT : integer := CLK_FREQ / STEP_FREQ;

signal counter : integer range 0 to MAX_COUNT := 0;

begin

process(clk, rst)
begin
    if rst = '1' then
        counter <= 0;
        tick_bobinas <= '0';

    elsif rising_edge(clk) then

        if counter = MAX_COUNT - 1 then
            counter <= 0;
            tick_bobinas <= '1';  -- pulso de 1 ciclo
        else
            counter <= counter + 1;
            tick_bobinas<= '0';
        end if;

    end if;
end process;

end Behavioral;