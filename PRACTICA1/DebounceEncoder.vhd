library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DebounceEncoder is
port(
    clk               : in  std_logic;
    clk_enc_fisico    : in  std_logic;
    dt_enc_fisico     : in  std_logic;
    clk_clean_encoder         : out std_logic;
    dt_clean_encoder          : out std_logic
);
end DebounceEncoder;

architecture Behavioral of DebounceEncoder is
------------------------------------
-- Señales de sincronización
----------------------------------
signal clk_sync1, clk_sync2 : std_logic := '0';
signal dt_sync1,  dt_sync2  : std_logic := '0';
----------------------------------
-- Señales de debounce
-------------------------------
constant N : integer := 5000; -- ajusta (ej. 0.1 ms si clk=50MHz)

signal cnt_clk : integer := 0;
signal cnt_dt  : integer := 0;

signal clk_db : std_logic := '0';
signal dt_db  : std_logic := '0';

begin

-----------------------------------------------------------------------------------------------
--                                       SINCRONIZACIÓN 
------------------------------------------------------------------------------------------------
--Registro de estado Flip-flop D con Reset Asíncrono que captura un dato con el flanco de reloj
-----------------------------------------------------------------------------------------------
--La metaestabilidad es un fenómeno probabilístico que provoca fallos en sistemas digitales. 
--Ocurre con mayor probabilidad cuando un circuito recibe una señal asincrónica o se intercambian señales 
--entre sistemas sincrónicos con dominios de reloj no relacionados. 
--Para reducir el riesgo de propagación de la metaestabilidad a través de un circuito, se recomienda el empleo de
--sincronizadores, cuya efectividad puede expresarse mediante el parámetro MTBF (Mean Time Between Failure

-----------------------------------------------------------------------------------------------------------
process(clk)
begin
    if rising_edge(clk) then
        clk_sync1 <= clk_enc_fisico;
        clk_sync2 <= clk_sync1;

        dt_sync1 <=  dt_enc_fisico;
        dt_sync2 <= dt_sync1;
    end if;
end process;

-------------------------------------------------
-- DEBOUNCE CLK
-------------------------------------------------
process(clk)
begin
    if rising_edge(clk) then

        if clk_sync2 /= clk_db then  --si clk_sync2 es diferente de clk_db--
            cnt_clk <= cnt_clk + 1;
            if cnt_clk = N then
                clk_db <= clk_sync2;
                cnt_clk <= 0;
            end if;
        else
            cnt_clk <= 0;
        end if;

    end if;
end process;

-------------------------------------------------
-- DEBOUNCE DT
-------------------------------------------------
process(clk)
begin
    if rising_edge(clk) then

        if dt_sync2 /= dt_db then
            cnt_dt <= cnt_dt + 1;
            if cnt_dt = N then
                dt_db <= dt_sync2;
                cnt_dt <= 0;
            end if;
        else
            cnt_dt <= 0;
        end if;

    end if;
end process;

-------------------------------------------------
-- SALIDAS
-------------------------------------------------
clk_clean_encoder <= clk_db; ----CANAL A   
dt_clean_encoder <= dt_db;  ----CANAL B

end Behavioral;