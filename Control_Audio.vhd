library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Control_Audio is
    generic(
        CLK_FREQ : integer := 50000000 -- 50 MHz
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        en_beep    : in  std_logic; 
        dir        : in  std_logic; 
        buzzer_out : out std_logic
    );
end Control_Audio;
architecture Behavioral of Control_Audio is
    -- Tiempos mucho más cortos para una alarma real
    constant T_MODO_A : integer := CLK_FREQ / 5; -- 0.2 segundos (Rápido)
    constant T_MODO_B : integer := CLK_FREQ / 2; -- 0.5 segundos (Lento)
    
    signal counter : integer := 0;
    signal t_max   : integer := 0;
    signal beep_s  : std_logic := '0';
begin

    t_max <= T_MODO_A when dir = '0' else T_MODO_B;

    process(clk, rst)
    begin
        if rst = '1' then
            counter <= 0;
            beep_s  <= '0';
        elsif rising_edge(clk) then
            if en_beep = '1' then
                if counter >= t_max then
                    counter <= 0;
                    beep_s  <= not beep_s; 
                else
                    counter <= counter + 1;
                end if;
            else
                -- IMPORTANTE: Al soltar el sensor, reseteamos todo
                counter <= 0;
                beep_s  <= '1'; -- Lo dejamos listo en '1' para que el sig. choque sea instantáneo
            end if;
        end if;
    end process;

    -- Solo sacamos el sonido si en_beep está activo
    buzzer_out <= beep_s when en_beep = '1' else '0';

end Behavioral;