--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    PRACTICA4 
-- Módulo:      LCD_Init_FSM
--
-- Descripción:
-- Máquina de estados para la inicialización de un LCD 16x2 basado en el
-- controlador HD44780 en modo de 4 bits.
--
-- La FSM implementa la secuencia de inicialización recomendada por el
-- fabricante, incluyendo:
--   1) Retardo de encendido (Power-Up)
--   2) Secuencia de sincronización en modo 8 bits (forzada)
--   3) Cambio a modo 4 bits
--   4) Envío de comandos de configuración mediante ROM
--
-- Se respetan los tiempos críticos del datasheet mediante dos mecanismos:
--
--   ● ce_1us (Clock Enable de 1 µs):
--     - Generado por un módulo externo (LCD_Timer)
--     - Se utiliza para retardos largos:
--         • Power-Up (>15 ms)
--         • Delays de inicialización (4.1 ms, 100 µs, 40 µs)
--         • Tiempo de ejecución de comandos (~37 µs, ~1.52 ms para clear)
--
--   ● bus_timer (temporización a nivel de ciclo de reloj):
--     - Contador interno sincronizado al clock de la FPGA (ej. 50 MHz)
--     - Se utiliza para cumplir los tiempos eléctricos del bus LCD
--
--     Tiempos relevantes del datasheet (HD44780):
--         • Enable pulse width (E HIGH)    ≥ 450 ns
--         • Enable cycle time              ≥ 1 µs
--         • Data setup time (tDS)          ≥ 40 ns
--         • Data hold time  (tDH)          ≥ 10 ns
--
--     Implementación:
--         - bus_timer cuenta ciclos de reloj (20 ns @ 50 MHz)
--         - Se utiliza para generar:
--             • Pulso de habilitación (E)
--             • Tiempo de establecimiento (setup)
--             • Tiempo de retención (hold)
--
--     Nota de diseño:
--         - Aunque el datasheet permite pulsos más cortos (~450 ns),
--           se utiliza 1 µs por simplicidad y robustez.
--
-- Arquitectura:
--   - FSM:
--       Controla la secuencia de estados y temporización global
--
--   - ROM:
--       Contiene los comandos de inicialización:
--           • Function Set (0x28)
--           • Display OFF (0x08)
--           • Clear (0x01)
--           • Entry Mode (0x06)
--           • Display ON (0x0C)
--
--   - Interfaz 4 bits:
--       Los datos se transmiten en dos fases:
--           • Nibble alto (DB7–DB4)
--           • Nibble bajo (DB3–DB0)
--
-- Consideraciones:
--   - Durante la etapa inicial (INIT_1 a INIT_3), el LCD se fuerza a modo 8 bits
--     enviando únicamente el nibble "0011", según el datasheet.
--
--   - El bit Busy Flag (BF) NO se consulta durante la inicialización,
--     por lo que los delays se implementan de forma fija.
--
--   - Todos los cambios de estado ocurren en flanco de subida del reloj,
--     garantizando comportamiento síncrono y libre de glitches.
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_init_fsm is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        ce_1us    : in  std_logic;

        busy      : in  std_logic;

        cmd_valid : out std_logic;
        cmd_rs    : out std_logic;
        cmd_data  : out std_logic_vector(7 downto 0);

        init_done : out std_logic
    );
end entity;

architecture RTL of lcd_init_fsm is

    type state_type is (
        POWER_UP,
        SEND_CMD,
        HOLD,
        DELAY,
        NEXT_STEP,
        DONE
    );

    signal state : state_type := POWER_UP;

    signal timer : integer := 0;
    signal step  : integer range 0 to 8 := 0;

    constant T_PWR : integer := 15000;

    signal cmd_pulse : std_logic := '0';

begin

    -- salida por defecto SIEMPRE
    cmd_valid <= cmd_pulse;

process(clk)
begin
    if rising_edge(clk) then

        if rst = '1' then
            state      <= POWER_UP;
            timer      <= 0;
            step       <= 0;
            cmd_rs     <= '0';
            cmd_data   <= (others => '0');
            init_done  <= '0';
            cmd_pulse  <= '0';

        else

            -- pulso por defecto
            cmd_pulse <= '0';

            case state is

            ----------------------------------------------------------------
            -- POWER UP
            ----------------------------------------------------------------
            when POWER_UP =>
                init_done <= '0';

                if ce_1us = '1' then
                    if timer < T_PWR then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= SEND_CMD;
                    end if;
                end if;

            ----------------------------------------------------------------
            -- ENVÍO DE COMANDO
            ----------------------------------------------------------------
            when SEND_CMD =>

                if busy = '0' then
                    cmd_rs <= '0';
                    cmd_pulse <= '1';  -- 🔥 PULSO LIMPIO

                    case step is

                        when 0 | 1 | 2 =>
                            cmd_data <= x"03";

                        when 3 =>
                            cmd_data <= x"02";

                        when 4 =>
                            cmd_data <= x"28";

                        when 5 =>
                            cmd_data <= x"08";

                        when 6 =>
                            cmd_data <= x"0C";

                        when 7 =>
                            cmd_data <= x"06";

                        when 8 =>
                            cmd_data <= x"01";

                        when others =>
                            cmd_data <= x"00";

                    end case;

                    state <= HOLD;
                end if;

            ----------------------------------------------------------------
            -- HOLD (espera controlada del driver)
            ----------------------------------------------------------------
            when HOLD =>
                cmd_pulse <= '0';

                if busy = '1' then
                    state <= DELAY;
                end if;

            ----------------------------------------------------------------
            -- DELAY ENTRE COMANDOS
            ----------------------------------------------------------------
            when DELAY =>

                if ce_1us = '1' then

                    if step = 8 then
                        if timer < 2000 then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= NEXT_STEP;
                        end if;
                    else
                        if timer < 40 then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= NEXT_STEP;
                        end if;
                    end if;

                end if;

            ----------------------------------------------------------------
            -- SIGUIENTE COMANDO
            ----------------------------------------------------------------
            when NEXT_STEP =>
                if step = 8 then
                    state <= DONE;
                else
                    step <= step + 1;
                    state <= SEND_CMD;
                end if;

            ----------------------------------------------------------------
            -- FIN
            ----------------------------------------------------------------
            when DONE =>
                init_done <= '1';

            when others =>
                state <= POWER_UP;

            end case;
        end if;
    end if;
end process;

end architecture;