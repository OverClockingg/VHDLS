--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Gestor de Mensajes para LCD 16x2
-- Archivo     : FSM_Mensajes.vhd
-- Descripción :
-- Este módulo implementa una Máquina de Estados Finitos (FSM) encargada
-- de administrar el envío de mensajes hacia el driver del LCD (FSM_LCD).
--
-- Su función principal es actuar como una capa de control superior,
-- evitando retransmisiones innecesarias y asegurando que únicamente se
-- envíen nuevos mensajes cuando el driver del LCD se encuentre disponible.
--
-- Funcionalidades principales:
--   1. Detectar cambios en el comando de entrada "cmd"
--   2. Filtrar comandos repetidos
--   3. Esperar a que el LCD esté listo
--   4. Generar el pulso de inicio para el driver LCD
--   5. Mantener estable el identificador del mensaje
--   6. Coordinar la sincronización con la señal busy del driver
--
-- Funcionamiento general:
-- Cuando se detecta un nuevo comando distinto al anterior y el driver
-- LCD no se encuentra ocupado, la FSM:
--
--   - Captura el ID del mensaje
--   - Lo estabiliza en la salida msg_id
--   - Genera un pulso start_drv
--   - Espera a que el driver complete la escritura
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
use work.lcd_pkg.all; -- Importa mensajes y definiciones del sistema

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity FSM_Mensajes is
    port(

        ------------------------------------------------------------------------
        -- Señales de reloj y reset
        ------------------------------------------------------------------------
        clk : in std_logic; -- Reloj principal del sistema
        rst : in std_logic; -- Reset asíncrono

        ------------------------------------------------------------------------
        -- Interfaz de control externa
        ------------------------------------------------------------------------

        -- Código del mensaje a mostrar
        cmd : in std_logic_vector(3 downto 0);

        -- Señal que indica que el LCD terminó su inicialización
        ready : in std_logic;

        ------------------------------------------------------------------------
        -- Interfaz con el Driver LCD (FSM_LCD)
        ------------------------------------------------------------------------

        -- Señal busy proveniente del driver LCD
        busy_drv : in std_logic;

        -- Pulso de inicio para activar al driver
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
    -- DEFINICIÓN DE ESTADOS DE LA FSM
    ----------------------------------------------------------------------------
    type state_t is (

        ------------------------------------------------------------------------
        -- Estado de espera
        ------------------------------------------------------------------------
        ST_IDLE,

        ------------------------------------------------------------------------
        -- Captura y estabilización del mensaje
        ------------------------------------------------------------------------
        ST_LATCH,

        ------------------------------------------------------------------------
        -- Generación del pulso de inicio al driver
        ------------------------------------------------------------------------
        ST_TRIGGER,

        ------------------------------------------------------------------------
        -- Espera mientras el driver LCD está ocupado
        ------------------------------------------------------------------------
        ST_WAIT,

        ------------------------------------------------------------------------
        -- Estado reservado para separación temporal entre comandos
        ------------------------------------------------------------------------
        ST_HOLD_OFF
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : state_t;

    ----------------------------------------------------------------------------
    -- REGISTROS INTERNOS
    ----------------------------------------------------------------------------

    -- Registro que almacena temporalmente el mensaje actual
    signal msg_id_reg : std_logic_vector(3 downto 0);

    -- Registro utilizado para detectar cambios de comando
    -- Evita reenviar el mismo mensaje continuamente
    signal last_cmd_reg : std_logic_vector(3 downto 0);

begin

    ----------------------------------------------------------------------------
    -- PROCESO PRINCIPAL
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET ASÍNCRONO
        ------------------------------------------------------------------------
        if rst = '1' then

            state        <= ST_IDLE;

            start_drv    <= '0';

            msg_id_reg   <= "0000";

            msg_id       <= "0000";

            last_cmd_reg <= "0000";

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Valor por defecto:
            -- start_drv solo debe durar un ciclo de reloj
            --------------------------------------------------------------------
            start_drv <= '0';

            --------------------------------------------------------------------
            -- La FSM únicamente opera cuando el LCD ya está inicializado
            --------------------------------------------------------------------
            if ready = '1' then

                ----------------------------------------------------------------
                -- MÁQUINA DE ESTADOS
                ----------------------------------------------------------------
                case state is

                    ----------------------------------------------------------------
                    -- ST_IDLE
                    -- Espera un nuevo comando válido
                    ----------------------------------------------------------------
                    when ST_IDLE =>

                        ----------------------------------------------------------------
                        -- Condiciones para aceptar un nuevo mensaje:
                        --   1. cmd distinto de 0000
                        --   2. cmd diferente al último enviado
                        --   3. El driver LCD no está ocupado
                        ----------------------------------------------------------------
                        if cmd /= "0000" and
                           cmd /= last_cmd_reg and
                           busy_drv = '0' then

                            ----------------------------------------------------------------
                            -- Captura del nuevo mensaje
                            ----------------------------------------------------------------
                            msg_id_reg   <= cmd;

                            ----------------------------------------------------------------
                            -- Actualización del último comando enviado
                            -- para evitar retransmisiones
                            ----------------------------------------------------------------
                            last_cmd_reg <= cmd;

                            ----------------------------------------------------------------
                            -- Siguiente estado
                            ----------------------------------------------------------------
                            state <= ST_LATCH;

                        ----------------------------------------------------------------
                        -- Si el comando vuelve a neutro ("0000"),
                        -- se reinicia el comparador de cambios
                        ----------------------------------------------------------------
                        elsif cmd = "0000" then

                            last_cmd_reg <= "0000";
                        end if;

                    ----------------------------------------------------------------
                    -- ST_LATCH
                    -- Estabiliza el ID del mensaje hacia el driver
                    ----------------------------------------------------------------
                    when ST_LATCH =>

                        msg_id <= msg_id_reg;

                        state <= ST_TRIGGER;

                    ----------------------------------------------------------------
                    -- ST_TRIGGER
                    -- Genera el pulso de inicio para FSM_LCD
                    ----------------------------------------------------------------
                    when ST_TRIGGER =>

                        start_drv <= '1';

                        ----------------------------------------------------------------
                        -- Espera confirmación de ocupado del driver
                        ----------------------------------------------------------------
                        if busy_drv = '1' then

                            state <= ST_WAIT;
                        end if;

                    ----------------------------------------------------------------
                    -- ST_WAIT
                    -- Espera a que FSM_LCD termine la escritura física
                    ----------------------------------------------------------------
                    when ST_WAIT =>

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
            -- Si el LCD aún no está listo,
            -- la FSM permanece en reposo
            ----------------------------------------------------------------------------
            else

                state <= ST_IDLE;
            end if;
        end if;
    end process;

end Behavioral;
