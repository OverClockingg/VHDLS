--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    Exergame "BUM BAM BIRI" - Tarea 1 DLP
-- Módulo:      LCD_Init_FSM
-- Descripción: Máquina de estados para la inicialización del LCD 16x2.
--              Configura el modo de 4 bits, encendido de display y limpieza.
--              Cumple con los tiempos de espera críticos del fabricante.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_init_fsm is
    generic ( 
        CLK_FREQ_HZ : integer := 50_000_000 -- Frecuencia de entrada para cálculos de tiempo
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        ce_1us    : in  std_logic; -- Clock Enable de 1 microsegundo
        
        -- Puertos físicos del LCD
        LCD_RS    : out std_logic;
        LCD_E     : out std_logic;
        LCD_D     : out std_logic_vector(3 downto 0);
        
        -- Control de sistema
        init_done : out std_logic -- Bandera de inicialización completada
    );
end entity;

architecture RTL of lcd_init_fsm is

    -- Cálculo de ciclos para garantizar tiempos de setup/hold
    constant CYCLES_1US : integer := (CLK_FREQ_HZ / 1_000_000);

    -- Estados de la FSM de inicialización
    -- POWER_UP:    Espera inicial de 15ms tras encendido.
    -- LOAD_BUS:    Coloca el comando/nibble en los pines de datos.
    -- STABILIZE:   Garantiza el tiempo de establecimiento (Setup Time).
    -- PULSE_E:     Genera el pulso de habilitación (E='1').
    -- HOLD_DATA:   Garantiza el tiempo de mantenimiento (Hold Time).
    -- DELAY_STATE: Aplica los retardos específicos entre comandos.
    type state_type is (
        POWER_UP, LOAD_BUS, STABILIZE, PULSE_E, HOLD_DATA, DELAY_STATE, DONE
    );
    
    signal state      : state_type := POWER_UP;
    signal timer      : integer range 0 to 65535 := 0;
    signal bus_timer  : integer range 0 to CYCLES_1US + 1 := 0;
    signal step       : integer range 0 to 12 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= POWER_UP; timer <= 0; bus_timer <= 0;
                LCD_E <= '0'; LCD_RS <= '0'; LCD_D <= "0000";
                init_done <= '0'; step <= 0;
            else
                case state is

                    -- Espera inicial > 15ms requerida por el driver HD44780
                    when POWER_UP =>
                        if ce_1us = '1' then
                            if timer < 15000 then timer <= timer + 1;
                            else timer <= 0; state <= LOAD_BUS; end if;
                        end if;

                    ---------------------------------------------------
                    -- ETAPA 1: Registro de salida (Poner datos en bus)
                    ---------------------------------------------------
                    when LOAD_BUS =>
                        LCD_E <= '0';
                        case step is
                            -- Comandos de "Wake up" (3 veces 0x3)
                            when 0 | 1 | 2 => LCD_D <= "0011"; LCD_RS <= '0';
                            -- Cambio a modo 4 bits (0x2)
                            when 3         => LCD_D <= "0010"; LCD_RS <= '0';
                            -- Function Set: 2 líneas, 5x8 puntos (0x28)
                            when 4         => LCD_D <= "0010"; LCD_RS <= '0'; -- Nibble High
                            when 5         => LCD_D <= "1000"; LCD_RS <= '0'; -- Nibble Low
                            -- Display ON/OFF: Display ON, Cursor OFF (0x0C)
                            when 6         => LCD_D <= "0000"; LCD_RS <= '0'; 
                            when 7         => LCD_D <= "1100"; LCD_RS <= '0';
                            -- Clear Display (0x01)
                            when 8         => LCD_D <= "0000"; LCD_RS <= '0'; 
                            when 9         => LCD_D <= "0001"; LCD_RS <= '0';
                            when others    => LCD_D <= "0000"; LCD_RS <= '0';
                        end case;
                        state <= STABILIZE;

                    ---------------------------------------------------
                    -- ETAPA 2: Garantía de Setup Time
                    ---------------------------------------------------
                    when STABILIZE =>
                        bus_timer <= 0;
                        state <= PULSE_E;

                    ---------------------------------------------------
                    -- ETAPA 3: Habilitación (Pulso E='1')
                    ---------------------------------------------------
                    when PULSE_E =>
                        LCD_E <= '1';
                        if bus_timer < CYCLES_1US - 1 then
                            bus_timer <= bus_timer + 1;
                        else
                            bus_timer <= 0;
                            state <= HOLD_DATA;
                        end if;

                    ---------------------------------------------------
                    -- ETAPA 4: Garantía de Hold Time (E='0')
                    ---------------------------------------------------
                    when HOLD_DATA =>
                        LCD_E <= '0';
                        if bus_timer < CYCLES_1US - 1 then
                            bus_timer <= bus_timer + 1;
                        else
                            timer <= 0;
                            state <= DELAY_STATE;
                        end if;

                    -- Gestión de retardos críticos entre pasos de inicialización
                    when DELAY_STATE =>
                        if ce_1us = '1' then
                            case step is
                                when 0      => if timer < 4100 then timer <= timer + 1; else state <= LOAD_BUS; step <= 1; end if;
                                when 1      => if timer < 100  then timer <= timer + 1; else state <= LOAD_BUS; step <= 2; end if;
                                -- Clear Display requiere más de 1.5ms
                                when 8 | 9  => if timer < 2000 then timer <= timer + 1; else state <= LOAD_BUS; step <= step + 1; end if;
                                when 10     => state <= DONE;
                                -- Comandos estándar requieren 40us
                                when others => if timer < 40   then timer <= timer + 1; else state <= LOAD_BUS; step <= step + 1; end if;
                            end case;
                        end if;

                    when DONE =>
                        init_done <= '1';

                    when others => state <= POWER_UP;
                end case;
            end if;
        end if;
    end process;

end architecture;