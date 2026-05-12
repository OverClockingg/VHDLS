--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Generador de Base de Tiempo para LCD
-- Archivo     : LCD_Timer.vhd
-- Descripción :
-- Este módulo implementa un divisor de frecuencia parametrizable utilizado
-- para generar señales de habilitación temporizadas (Clock Enable).
--
-- Su propósito principal es proporcionar una base de tiempo precisa para
-- los módulos de control del LCD, permitiendo trabajar con retardos en
-- microsegundos sin necesidad de utilizar múltiples contadores internos
-- en cada bloque funcional.
--
-- Funcionamiento:
--
-- El módulo cuenta ciclos del reloj principal de la FPGA hasta alcanzar
-- el número equivalente al tiempo definido por RESOLUTION_US.
--
-- Cuando el contador alcanza el límite:
--
--   - Se reinicia automáticamente
--   - Se genera un pulso de habilitación (ce_1us)
--   - El pulso dura exactamente un ciclo de reloj
--
-- Ejemplo:
--
--   CLK_FREQ_HZ = 50 MHz
--   RESOLUTION_US = 1 us
--
-- Entonces:
--
--   50 ciclos de reloj = 1 pulso ce_1us
--
-- Características:
--
--   - Resolución parametrizable
--   - Salida completamente registrada
--   - Diseño sintetizable
--   - Protección mediante assertions
--   - Bajo consumo lógico
--
-- Dependencias:
--   - IEEE.STD_LOGIC_1164
--   - IEEE.NUMERIC_STD
--

--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity LCD_Timer is
    generic (

        ------------------------------------------------------------------------
        -- Frecuencia del reloj principal de la FPGA
        ------------------------------------------------------------------------
        CLK_FREQ_HZ : integer := 50_000_000;

        ------------------------------------------------------------------------
        -- Resolución temporal deseada en microsegundos
        ------------------------------------------------------------------------
        RESOLUTION_US : integer := 1
    );

    port (

        ------------------------------------------------------------------------
        -- Entradas de control
        ------------------------------------------------------------------------
        clk : in std_logic; -- Reloj maestro del sistema

        rst : in std_logic; -- Reset síncrono

        en  : in std_logic; -- Habilitación del temporizador

        ------------------------------------------------------------------------
        -- Salida de habilitación
        ------------------------------------------------------------------------
        -- Pulso activo durante un único ciclo de reloj
        ------------------------------------------------------------------------
        ce_1us : out std_logic
    );
end entity;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture RTL of LCD_Timer is

    ----------------------------------------------------------------------------
    -- CONSTANTES DE CONFIGURACIÓN
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Número de ciclos de reloj equivalentes a RESOLUTION_US
    --
    -- Ejemplo:
    --   CLK_FREQ_HZ = 50 MHz
    --   RESOLUTION_US = 1
    --
    --   CYCLES_LIMIT = 50
    ------------------------------------------------------------------------
    constant CYCLES_LIMIT : integer :=
        (CLK_FREQ_HZ / 1_000_000) * RESOLUTION_US;

    ----------------------------------------------------------------------------
    -- VERIFICACIÓN DE PARÁMETROS
    ----------------------------------------------------------------------------
    -- Garantiza:
    --   1. Frecuencia mínima válida
    --   2. Resolución positiva
    ----------------------------------------------------------------------------
    constant PARAM_OK : boolean :=
        (CLK_FREQ_HZ >= 1_000_000) and
        (RESOLUTION_US > 0);

    ----------------------------------------------------------------------------
    -- SEÑALES INTERNAS
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Contador principal
    ------------------------------------------------------------------------
    signal counter : integer range 0 to CYCLES_LIMIT := 0;

    ------------------------------------------------------------------------
    -- Registro interno de la salida ce_1us
    ------------------------------------------------------------------------
    signal r_ce : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- ASSERTION DE SEGURIDAD
    ----------------------------------------------------------------------------
    -- Previene síntesis inválidas si los parámetros son incorrectos.
    ----------------------------------------------------------------------------
    assert PARAM_OK
        report "ERROR: Parámetros de tiempo inválidos. Revise CLK_FREQ_HZ y RESOLUTION_US."
        severity failure;

    ----------------------------------------------------------------------------
    -- PROCESO PRINCIPAL
    ----------------------------------------------------------------------------
    -- Implementa un divisor de frecuencia mediante contador síncrono.
    --
    -- Operación:
    --
    --   1. Incrementa el contador en cada flanco positivo de reloj
    --   2. Cuando el contador alcanza CYCLES_LIMIT:
    --        - El contador se reinicia
    --        - Se genera un pulso ce_1us
    --   3. El pulso dura un único ciclo de reloj
    ----------------------------------------------------------------------------
    process(clk)
    begin

        ------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ------------------------------------------------------------------------
        if rising_edge(clk) then

            --------------------------------------------------------------------
            -- RESET SÍNCRONO
            --------------------------------------------------------------------
            if rst = '1' then

                counter <= 0;

                r_ce <= '0';

            --------------------------------------------------------------------
            -- TIMER HABILITADO
            --------------------------------------------------------------------
            elsif en = '1' then

                ----------------------------------------------------------------
                -- Valor por defecto:
                -- El pulso permanece inactivo
                ----------------------------------------------------------------
                r_ce <= '0';

                ----------------------------------------------------------------
                -- Verificación de fin de cuenta
                ----------------------------------------------------------------
                if counter >= CYCLES_LIMIT - 1 then

                    ------------------------------------------------------------
                    -- Reinicio del contador
                    ------------------------------------------------------------
                    counter <= 0;

                    ------------------------------------------------------------
                    -- Generación del pulso de habilitación
                    ------------------------------------------------------------
                    r_ce <= '1';

                else

                    ------------------------------------------------------------
                    -- Incremento normal del contador
                    ------------------------------------------------------------
                    counter <= counter + 1;
                end if;

            --------------------------------------------------------------------
            -- TIMER DESHABILITADO
            --------------------------------------------------------------------
            else

                ----------------------------------------------------------------
                -- La salida permanece inactiva
                ----------------------------------------------------------------
                r_ce <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- ASIGNACIÓN DE SALIDA
    ----------------------------------------------------------------------------
    -- La salida se registra para evitar glitches combinacionales
    -- y mejorar la estabilidad temporal del sistema.
    ----------------------------------------------------------------------------
    ce_1us <= r_ce;

end architecture;
