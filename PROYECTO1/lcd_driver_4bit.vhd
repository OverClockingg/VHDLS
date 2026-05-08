--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    Interfaz LCD 16x2 en FPGA
-- Módulo:      lcd_driver_4bit
-- ============================================================================
-- DESCRIPCIÓN GENERAL
-- ============================================================================
-- Este módulo implementa el controlador físico (driver) para un display LCD
-- basado en el controlador HD44780 operando en modo de 4 bits.
--
-- Su función principal es traducir bytes de entrada (ASCII o comandos)
-- provenientes de una FSM superior en la secuencia de señales eléctricas
-- requerida por el LCD.
--
-- El módulo encapsula completamente:
--   - El protocolo de comunicación en 4 bits
--   - La temporización del pulso Enable (E)
--   - El retardo requerido entre escrituras
--
-- Esto permite desacoplar la lógica de alto nivel (control, menús, scroll)
-- del manejo de bajo nivel del hardware LCD.
--
-- ============================================================================
-- INTERFAZ DEL MÓDULO
-- ============================================================================
--
-- Entradas:
--   clk       : Reloj del sistema (típicamente 50 MHz)
--   rst       : Reset síncrono activo en alto
--   valid     : Pulso de escritura (1 ciclo de reloj)
--   char_in   : Byte de datos a enviar (ASCII o comando)
--   rs_in     : Selección de registro
--               '0' → Comando
--               '1' → Dato (carácter)
--
-- Salidas:
--   busy      : Indica que el driver está ocupado procesando un dato
--   LCD_RS    : Señal RS hacia el LCD
--   LCD_E     : Señal Enable hacia el LCD
--   LCD_D     : Bus de datos de 4 bits (DB7–DB4 del LCD)
--
-- ============================================================================
-- PROTOCOLO DE OPERACIÓN (HD44780 - MODO 4 BITS)
-- ============================================================================
--
-- Cada byte se transmite en dos fases:
--
--   1) Nibble alto (bits 7–4)
--   2) Nibble bajo (bits 3–0)
--
-- Para cada nibble:
--   - Colocar datos en el bus
--   - Generar pulso en E
--   - Mantener estabilidad (hold)
--
-- Secuencia total:
--
--   SETUP_HIGH → PULSE_HIGH → HOLD_HIGH
--   SETUP_LOW  → PULSE_LOW  → HOLD_LOW
--   WRITE_DELAY
--
-- ============================================================================
-- TEMPORIZACIÓN
-- ============================================================================
--
-- Basado en el datasheet del HD44780:
--
--   - Enable pulse width (E HIGH): ≥ 450 ns
--   - Data setup time:             ≥ 40 ns
--   - Data hold time:              ≥ 10 ns
--   - Execution time:              ~37 µs (hasta 1.52 ms en clear)
--
-- En este diseño se utilizan tiempos conservadores:
--
--   T_PULSE = 100 µs   → pulso robusto para garantizar captura
--   T_WRITE = 2 ms     → margen amplio entre escrituras
--
--
-- ============================================================================
-- ARQUITECTURA
-- ============================================================================
--
--   FSM (Máquina de estados finitos):
--
--   IDLE        : Espera de nuevo dato (valid)
--   SETUP_HIGH  : Coloca nibble alto en el bus
--   PULSE_HIGH  : Genera pulso E
--   HOLD_HIGH   : Retención post-flanco
--
--   SETUP_LOW   : Coloca nibble bajo
--   PULSE_LOW   : Pulso E
--   HOLD_LOW    : Retención final
--
--   WRITE_DELAY : Tiempo de ejecución del LCD
--
-- ============================================================================
-- CONSIDERACIONES DE DISEÑO
-- ============================================================================
--
--  Se utilizan señales internas (rs_i, e_i, d_i) para evitar errores de
--  "multiple drivers" en síntesis.
--
--  El handshake se basa en:
--  valid → (interno) → busy
--
--  El módulo NO consulta el Busy Flag del LCD (lectura RW no implementada),
--  por lo que depende de delays temporizados.
--
--  Diseño completamente síncrono (flanco de subida de clk).
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_driver_4bit is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000
    );
    port (
        clk     : in std_logic;
        rst     : in std_logic;
        valid   : in  std_logic;
        char_in : in  std_logic_vector(7 downto 0);
        rs_in   : in  std_logic;
        busy    : out std_logic;
        LCD_RS  : out std_logic;
        LCD_E   : out std_logic;
        LCD_D   : out std_logic_vector(3 downto 0)
    );
end entity;

architecture RTL of lcd_driver_4bit is

    type state_type is (IDLE, SETUP_HIGH, PULSE_HIGH, HOLD_HIGH, 
                        SETUP_LOW, PULSE_LOW, HOLD_LOW, WRITE_DELAY);

    signal state : state_type := IDLE;
    signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal timer : integer := 0;

    -- Señales internas para evitar el error de "multiple drivers"
    signal rs_i : std_logic := '0';
    signal e_i  : std_logic := '0';
    signal d_i  : std_logic_vector(3 downto 0) := (others => '0');

	-- En el driver o el controlador, actualiza estas constantes:
	 constant CYCLES_1US : integer := CLK_FREQ_HZ / 1_000_000;

	-- Tiempo de "valid" o enable activo
	 constant T_PULSE : integer := 100 * CYCLES_1US; -- 100us para asegurar captura

	-- Tiempo de espera entre caracteres (Handshake de seguridad)
	 constant T_WRITE : integer := 2000 * CYCLES_1US; -- 2ms es el balance perfecto

begin

    -- ASIGNACIONES ÚNICAS A LOS PINES FÍSICOS
    LCD_RS <= rs_i;
    LCD_E  <= e_i;
    LCD_D  <= d_i;
    busy   <= '1' when state /= IDLE else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                timer <= 0;
                rs_i  <= '0';
                e_i   <= '0';
                d_i   <= (others => '0');
            else
                case state is

                    when IDLE =>
                        e_i <= '0';
                        if valid = '1' then
                            data_reg <= char_in;
                            rs_i     <= rs_in; -- Captura RS (Comando o Dato)
                            state    <= SETUP_HIGH;
                        end if;

                    when SETUP_HIGH =>
                        d_i   <= data_reg(7 downto 4);
                        timer <= 0;
                        state <= PULSE_HIGH;

                    when PULSE_HIGH =>
                        e_i <= '1';
                        if timer < T_PULSE then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            e_i   <= '0';
                            state <= HOLD_HIGH;
                        end if;

                    when HOLD_HIGH =>
                        if timer < T_PULSE then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= SETUP_LOW;
                        end if;

                    when SETUP_LOW =>
                        d_i   <= data_reg(3 downto 0);
                        timer <= 0;
                        state <= PULSE_LOW;

                    when PULSE_LOW =>
                        e_i <= '1';
                        if timer < T_PULSE then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            e_i   <= '0';
                            state <= HOLD_LOW;
                        end if;

                    when HOLD_LOW =>
                        if timer < T_PULSE then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= WRITE_DELAY;
                        end if;

                    when WRITE_DELAY =>
                        if timer < T_WRITE then
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= IDLE;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture;