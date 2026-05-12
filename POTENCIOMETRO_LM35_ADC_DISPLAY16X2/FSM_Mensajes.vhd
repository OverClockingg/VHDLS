--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Módulo:      FSM_Mensajes (Versión Optimizada para Sensores)
-- Descripción: Gestiona el disparo de mensajes al LCD. Incluye refresco 
--              automático para datos dinámicos y sistema de Handshake.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_pkg.all;

entity FSM_Mensajes is
    port(
        clk        : in  std_logic; 
        rst        : in  std_logic; 
        ce_refresh : in  std_logic; -- Pulso de 1ms
        
        -- Interfaz de Control
        cmd        : in  std_logic_vector(3 downto 0); 
        ready      : in  std_logic; -- LCD inicializado
        
        -- Interfaz con el Driver (FSM_LCD)
        busy_drv   : in  std_logic; 
        start_drv  : out std_logic; 
        msg_id     : out std_logic_vector(3 downto 0) 
    );
end FSM_Mensajes;

architecture Behavioral of FSM_Mensajes is

    type state_t is (ST_IDLE, ST_LATCH, ST_TRIGGER, ST_WAIT);
    signal state : state_t;
    
    signal msg_id_reg   : std_logic_vector(3 downto 0);
    signal last_cmd_reg : std_logic_vector(3 downto 0); 

    -- Contador de refresco
    signal ms_counter    : integer range 0 to 500;
    signal refresh_tick  : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- PROCESO: Generador de tick de refresco (500ms)
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            ms_counter <= 0;
            refresh_tick <= '0';
        elsif rising_edge(clk) then
            refresh_tick <= '0'; 
            if ce_refresh = '1' then
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
    -- MÁQUINA DE ESTADOS: Gestión de Handshake
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    -- MÁQUINA DE ESTADOS CORREGIDA
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state        <= ST_IDLE;
            start_drv    <= '0';
            msg_id_reg   <= (others => '0');
            msg_id       <= (others => '0');
            last_cmd_reg <= (others => '1');
            
        elsif rising_edge(clk) then
            start_drv <= '0'; 

            if ready = '1' then
                case state is
                    
                    when ST_IDLE =>
                        -- CASO 1: Cambiaron el switch/botón de modo (Prioridad alta)
                        if cmd /= last_cmd_reg then
                            msg_id_reg   <= cmd;
                            last_cmd_reg <= cmd;
                            state        <= ST_LATCH;
                        
                        -- CASO 2: Es temperatura y toca actualizar el dato dinámico
                        elsif (cmd = "0100" or cmd = "0101") and refresh_tick = '1' then
                            msg_id_reg   <= cmd;
                            state        <= ST_LATCH;
                        end if;

                    when ST_LATCH =>
                        msg_id <= msg_id_reg;
                        state  <= ST_TRIGGER;

                    when ST_TRIGGER =>
                        -- Verificamos que el driver no esté ocupado antes de lanzar
                        if busy_drv = '0' then
                            start_drv <= '1';
                            state     <= ST_WAIT;
                        end if;

                    when ST_WAIT =>
                        -- HANDSHAKE: Esperamos a que el driver termine
                        if busy_drv = '0' then
                            state <= ST_IDLE;
                        end if;

                    when others => 
                        state <= ST_IDLE;
                end case;
            else
                state <= ST_IDLE;
            end if;
        end if;
    end process;

end Behavioral;