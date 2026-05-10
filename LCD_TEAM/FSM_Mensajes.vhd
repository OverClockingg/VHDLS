--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    Exergame "BUM BAM BIRI" - Tarea 1 DLP
-- Módulo:      FSM_Mensajes
-- Descripción: Máquina de estados de alto nivel que gestiona la selección y
--              el disparo (trigger) de mensajes hacia el driver del LCD.
--              Implementa un protocolo de comunicación robusto (Handshake)
--              para asegurar la correcta transferencia de datos.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_pkg.all; -- Importa el almacén de mensajes y tipos

entity FSM_Mensajes is
    port(
        clk       : in  std_logic; -- Reloj de sistema (ej. 50MHz)
        rst       : in  std_logic; -- Reset asíncrono
        
        -- Interfaz de Control
        cmd       : in  std_logic_vector(3 downto 0); -- Código del mensaje a mostrar
        ready     : in  std_logic; -- Indica que el LCD ha terminado su inicialización
        
        -- Interfaz con el Driver (FSM_LCD)
        busy_drv  : in  std_logic; -- Señal de ocupado proveniente del driver
        start_drv : out std_logic; -- Pulso de inicio para el driver
        msg_id    : out std_logic_vector(3 downto 0) -- ID del mensaje estabilizado
    );
end FSM_Mensajes;

architecture Behavioral of FSM_Mensajes is

    type state_t is (ST_IDLE, ST_LATCH, ST_TRIGGER, ST_WAIT, ST_HOLD_OFF);
    signal state : state_t;
    
    signal msg_id_reg : std_logic_vector(3 downto 0);
    -- Registro para detectar si el comando cambió respecto al último enviado
    signal last_cmd_reg : std_logic_vector(3 downto 0); 

begin

    process(clk, rst)
    begin
        if rst = '1' then
            state        <= ST_IDLE;
            start_drv    <= '0';
            msg_id_reg   <= "0000";
            msg_id       <= "0000";
            last_cmd_reg <= "0000";
            
        elsif rising_edge(clk) then
            start_drv <= '0'; -- Pulso por defecto

            if ready = '1' then
                case state is
                    
                    when ST_IDLE =>
                        -- Solo dispara si el comando es nuevo Y no es neutro
                        if cmd /= "0000" and cmd /= last_cmd_reg and busy_drv = '0' then
                            msg_id_reg   <= cmd;
                            last_cmd_reg <= cmd; -- Bloqueamos re-disparos del mismo mensaje
                            state        <= ST_LATCH;
                        elsif cmd = "0000" then
                            last_cmd_reg <= "0000"; -- Reset del comparador si vuelve a neutro
                        end if;

                    when ST_LATCH =>
                        msg_id <= msg_id_reg;
                        state  <= ST_TRIGGER;

                    when ST_TRIGGER =>
                        start_drv <= '1';
                        if busy_drv = '1' then
                            state <= ST_WAIT;
                        end if;

                    when ST_WAIT =>
                        -- Esperamos a que el driver termine la escritura física
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