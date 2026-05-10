--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    PRACTICA4
-- Módulo:      LCD_Timer
-- Descripción: Generador de señales de habilitación (Clock Enable) para 
--              referencias temporales precisas. Por defecto genera un pulso
--              cada 1 microsegundo, esencial para los retardos del LCD.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LCD_Timer is
    generic (
        CLK_FREQ_HZ   : integer := 50_000_000; -- Frecuencia del oscilador de la FPGA
        RESOLUTION_US : integer := 1            -- Resolución deseada en microsegundos
    );
    port (
        clk    : in  std_logic; -- Reloj maestro del sistema
        rst    : in  std_logic; -- Reset síncrono
        en     : in  std_logic; -- Habilitación del contador
        ce_1us : out std_logic  -- Señal de Clock Enable (pulso de 1 ciclo de clk)
    );
end entity;

architecture RTL of LCD_Timer is
    
    -- Cálculos de constantes de síntesis
    -- CYCLES_LIMIT: Determina cuántos pulsos de clk equivalen a RESOLUTION_US.
    constant CYCLES_LIMIT : integer := (CLK_FREQ_HZ / 1_000_000) * RESOLUTION_US;
    
    -- Verificación de seguridad en tiempo de compilación
    constant PARAM_OK : boolean := (CLK_FREQ_HZ >= 1_000_000) and (RESOLUTION_US > 0);
    
    -- Señales de control
    signal counter : integer range 0 to CYCLES_LIMIT := 0;
    signal r_ce    : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- ASERCIÓN DE SEGURIDAD
    -- Evita la generación de hardware inválido si los parámetros son erróneos.
    ----------------------------------------------------------------------------
    assert PARAM_OK 
        report "ERROR: Parámetros de tiempo inválidos. Revise CLK_FREQ_HZ y RESOLUTION_US."
        severity failure;

    ----------------------------------------------------------------------------
    -- PROCESO: Divisor de frecuencia mediante contador
    -- Genera un pulso de '1' durante un solo ciclo de reloj cada microsegundo.
    ----------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter <= 0;
                r_ce    <= '0';
            elsif en = '1' then
                -- Comportamiento por defecto: el pulso de habilitación está bajo
                r_ce <= '0'; 
                
                -- Verificación de alcance de cuenta
                if counter >= CYCLES_LIMIT - 1 then
                    counter <= 0;
                    r_ce    <= '1'; -- Activación del Clock Enable por un ciclo
                else
                    counter <= counter + 1;
                end if;
            else
                -- Si el timer está deshabilitado, la salida se mantiene en 0
                r_ce <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- SALIDA REGISTRADA
    -- Se asigna la salida registrada para evitar 'glitches' combinacionales
    -- en los módulos de jerarquía superior (LCD_Init y FSM_LCD).
    ----------------------------------------------------------------------------
    ce_1us <= r_ce;

end architecture;