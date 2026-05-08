library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_pkg.all; 

entity FSM_Mensajes is
    port(
        clk       : in  std_logic; 
        rst       : in  std_logic; 
        -- Interfaz de Control
        cmd       : in  std_logic_vector(3 downto 0); 
        ready     : in  std_logic; 
        -- Interfaz con el Driver (FSM_LCD)
        busy_drv  : in  std_logic; 
        done_drv  : in  std_logic; -- SE AÑADIÓ: Pulso de finalización del driver
        start_drv : out std_logic; 
        msg_id    : out std_logic_vector(3 downto 0); 
        offset    : out integer range 0 to 31
    );
end FSM_Mensajes;

architecture Behavioral of FSM_Mensajes is

    -- ESTADOS DE LA FSM
    type state_t is (ST_IDLE, ST_REQ_L1, ST_REQ_L2, ST_TRIGGER, ST_WAIT);
    signal state : state_t;
    
    -- CONTROL DE VELOCIDAD DE LA MARQUESINA (200ms @ 50MHz)
    signal clk_count : integer range 0 to 10_000_000 := 0; 
    signal r_offset  : integer range 0 to 31 := 0;        
    signal r_msg_id  : std_logic_vector(3 downto 0); 

begin

    process(clk, rst)
    begin
        if rst = '1' then
            state      <= ST_IDLE;
            start_drv  <= '0';
            r_msg_id   <= "1111";
            r_offset   <= 0;
            clk_count  <= 0;
            
        elsif rising_edge(clk) then
            start_drv <= '0'; -- Pulso por defecto para evitar disparos falsos

            if ready = '1' then
                
                -- LÓGICA DEL CONTADOR DE VELOCIDAD
                if clk_count < 10_000_000 then 
                    clk_count <= clk_count + 1;
                else
                    clk_count <= 0;
                    r_offset <= (r_offset + 1) mod 32; 
                end if;

                case state is
                    
                    when ST_IDLE =>
                        -- Esperamos a que el driver no esté ocupado para iniciar la secuencia
                        if busy_drv = '0' then
                            state <= ST_REQ_L1; 
                        end if;

                    when ST_REQ_L1 =>
                        r_msg_id <= "0000"; -- Mensaje L1 (Marquesina)
                        state    <= ST_TRIGGER;

                    when ST_TRIGGER =>
                        -- Generamos un pulso de inicio de un solo ciclo
                        start_drv <= '1';
                        state     <= ST_WAIT; -- Saltamos directamente a esperar confirmación

                    when ST_WAIT =>
                        -- CRÍTICO: Solo avanzamos si detectamos el pulso 'done' del driver
                        if done_drv = '1' then
                            if r_msg_id = "0000" then
                                state <= ST_REQ_L2; -- Pasamos al renglón 2
                            else
                                state <= ST_IDLE; -- Ciclo completo, volver a esperar
                            end if;
                        end if;

                    when ST_REQ_L2 =>
                        r_msg_id <= "1110"; -- Mensaje L2 (Autor/Fijo)[cite: 16]
                        state    <= ST_TRIGGER;

                    when others => 
                        state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- Asignación de salidas
    msg_id <= r_msg_id; 
    offset <= r_offset;

end Behavioral;