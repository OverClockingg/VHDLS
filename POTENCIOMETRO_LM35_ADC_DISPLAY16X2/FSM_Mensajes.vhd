--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Gestor de Mensajes LCD con Refresco Dinámico
-- Archivo     : FSM_Mensajes.vhd
-- Descripción :
-- Este módulo implementa una Máquina de Estados Finitos (FSM) encargada
-- de administrar el envío de mensajes hacia el driver LCD.
--
-- Su función principal es actuar como una capa de control intermedia
-- entre:
--
--   1. La lógica de alto nivel del sistema
--   2. El driver físico del LCD (FSM_LCD)
--
-- El módulo incorpora:
--
--   - Sistema de Handshake con el driver
--   - Detección de cambios de mensaje
--   - Refresco automático para variables dinámicas
--   - Prevención de reenvíos redundantes
--   - Control de sincronización mediante busy_drv
--
-- Arquitectura:
--
--         +----------------------+
--         |   FSM_Mensajes       |
--         +----------+-----------+
--                    |
--        +-----------+-----------+
--        |                       |
--        v                       v
--   Lógica Sistema         Driver LCD
--                              FSM_LCD
--
-- Funcionalidad especial:
--
--   - Los mensajes dinámicos (temperatura/ángulo)
--     se refrescan automáticamente cada 500 ms.
--
--   - Los mensajes estáticos solo se transmiten
--     cuando existe un cambio de comando.
--
-- Dependencias:
--   - IEEE.STD_LOGIC_1164
--   - work.lcd_pkg
--
-- Autor       :
-- Fecha       :
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_pkg.all;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity FSM_Mensajes is
    port(

        ------------------------------------------------------------------------
        -- Entradas principales
        ------------------------------------------------------------------------
        clk : in std_logic;

        rst : in std_logic;

        ------------------------------------------------------------------------
        -- Clock Enable de refresco
        ------------------------------------------------------------------------
        -- Pulso periódico de 1 ms
        ------------------------------------------------------------------------
        ce_refresh : in std_logic;

        ------------------------------------------------------------------------
        -- Interfaz de control del sistema
        ------------------------------------------------------------------------

        -- Código de mensaje solicitado
        cmd : in std_logic_vector(3 downto 0);

        -- Indica que el LCD ya terminó su inicialización
        ready : in std_logic;

        ------------------------------------------------------------------------
        -- Interfaz de comunicación con FSM_LCD
        ------------------------------------------------------------------------

        -- Señal busy proveniente del driver
        busy_drv : in std_logic;

        -- Pulso de inicio para el driver
        start_drv : out std_logic;

        -- Identificador estable del mensaje
        msg_id : out std_logic_vector(3 downto 0)
    );
end FSM_Mensajes;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of FSM_Mensajes is

    ----------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS FSM
    ----------------------------------------------------------------------------
    --
    -- ST_IDLE:
    --   Espera cambios de comando o refresco dinámico
    --
    -- ST_LATCH:
    --   Captura y estabiliza msg_id
    --
    -- ST_TRIGGER:
    --   Genera pulso start_drv
    --
    -- ST_WAIT:
    --   Espera finalización del driver LCD
    ----------------------------------------------------------------------------
    type state_t is (
        ST_IDLE,
        ST_LATCH,
        ST_TRIGGER,
        ST_WAIT
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : state_t;

    ----------------------------------------------------------------------------
    -- REGISTROS INTERNOS
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Registro temporal del ID del mensaje
    ------------------------------------------------------------------------
    signal msg_id_reg : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------------------
    -- Registro del último comando enviado
    ----------------------------------------------------------------------------
    -- Se utiliza para detectar cambios de modo y evitar
    -- retransmisiones innecesarias.
    ----------------------------------------------------------------------------
    signal last_cmd_reg : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------------------
    -- SISTEMA DE REFRESCO TEMPORAL
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Contador de milisegundos
    ------------------------------------------------------------------------
    signal ms_counter : integer range 0 to 500;

    ------------------------------------------------------------------------
    -- Tick periódico de refresco
    ----------------------------------------------------------------------------
    -- Se activa cada 500 ms para refrescar mensajes dinámicos.
    ----------------------------------------------------------------------------
    signal refresh_tick : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- PROCESO: GENERADOR DE REFRESCO
    ----------------------------------------------------------------------------
    -- Implementa un temporizador basado en ce_refresh.
    --
    -- Entradas:
    --   ce_refresh = pulso cada 1 ms
    --
    -- Resultado:
    --   refresh_tick = pulso cada 500 ms
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------------------
        if rst = '1' then

            ms_counter <= 0;

            refresh_tick <= '0';

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Valor por defecto
            --------------------------------------------------------------------
            refresh_tick <= '0';

            --------------------------------------------------------------------
            -- Conteo habilitado por ce_refresh
            --------------------------------------------------------------------
            if ce_refresh = '1' then

                ----------------------------------------------------------------
                -- 500 ms alcanzados
                ----------------------------------------------------------------
                if ms_counter >= 499 then

                    ms_counter <= 0;

                    refresh_tick <= '1';

                else

                    ms_counter <= ms_counter + 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- FSM PRINCIPAL
    ----------------------------------------------------------------------------
    -- Gestiona el protocolo Handshake con FSM_LCD.
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------------------
        if rst = '1' then

            state <= ST_IDLE;

            start_drv <= '0';

            msg_id_reg <= (others => '0');

            msg_id <= (others => '0');

            --------------------------------------------------------------------
            -- Inicialización forzada distinta
            --------------------------------------------------------------------
            -- Permite detectar correctamente el primer mensaje.
            --------------------------------------------------------------------
            last_cmd_reg <= (others => '1');

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Pulso por defecto
            --------------------------------------------------------------------
            start_drv <= '0';

            --------------------------------------------------------------------
            -- Solo operar cuando LCD ya fue inicializado
            --------------------------------------------------------------------
            if ready = '1' then

                ----------------------------------------------------------------
                -- MÁQUINA DE ESTADOS
                ----------------------------------------------------------------
                case state is

                    ----------------------------------------------------------------
                    -- ST_IDLE
                    -- Espera eventos de actualización
                    ----------------------------------------------------------------
                    when ST_IDLE =>

                        ----------------------------------------------------------------
                        -- CASO 1:
                        -- Cambio de mensaje/modo
                        ----------------------------------------------------------------
                        if cmd /= last_cmd_reg then

                            ----------------------------------------------------------------
                            -- Captura nuevo mensaje
                            ----------------------------------------------------------------
                            msg_id_reg <= cmd;

                            last_cmd_reg <= cmd;

                            state <= ST_LATCH;

                        ----------------------------------------------------------------
                        -- CASO 2:
                        -- Refresco periódico de mensajes dinámicos
                        ----------------------------------------------------------------
                        elsif (cmd = "0100" or cmd = "0101")
                              and refresh_tick = '1' then

                            ----------------------------------------------------------------
                            -- Reenvío del mismo mensaje dinámico
                            ----------------------------------------------------------------
                            msg_id_reg <= cmd;

                            state <= ST_LATCH;
                        end if;

                    ----------------------------------------------------------------
                    -- ST_LATCH
                    -- Estabiliza salida msg_id
                    ----------------------------------------------------------------
                    when ST_LATCH =>

                        msg_id <= msg_id_reg;

                        state <= ST_TRIGGER;

                    ----------------------------------------------------------------
                    -- ST_TRIGGER
                    -- Genera start_drv si el driver está libre
                    ----------------------------------------------------------------
                    when ST_TRIGGER =>

                        ----------------------------------------------------------------
                        -- Verificación de disponibilidad
                        ----------------------------------------------------------------
                        if busy_drv = '0' then

                            ----------------------------------------------------------------
                            -- Pulso de activación
                            ----------------------------------------------------------------
                            start_drv <= '1';

                            state <= ST_WAIT;
                        end if;

                    ----------------------------------------------------------------
                    -- ST_WAIT
                    -- Espera finalización del driver LCD
                    ----------------------------------------------------------------
                    when ST_WAIT =>

                        ----------------------------------------------------------------
                        -- Handshake completado
                        ----------------------------------------------------------------
                        if busy_drv = '0' then

                            state <= ST_IDLE;
                        end if;

                    ----------------------------------------------------------------
                    -- ESTADO NO DEFINIDO
                    ----------------------------------------------------------------
                    when others =>

                        state <= ST_IDLE;
                end case;

            ----------------------------------------------------------------------------
            -- LCD aún no inicializado
            ----------------------------------------------------------------------------
            else

                state <= ST_IDLE;
            end if;
        end if;
    end process;

end Behavioral;
