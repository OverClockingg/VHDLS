

-- ============================================================================
-- ENTIDAD: marquesina_ctrl
-- ============================================================================
-- DESCRIPCIÓN:
--  Controlador de marquesina para LCD 16x2.
--  Genera scroll independiente para dos líneas de texto almacenadas en buffers
--  de 40 caracteres (DDRAM extendida lógica).
--
--  Este módulo NO controla el LCD directamente.
--  Solo genera:
--      - carácter a mostrar
--      - columna actual
--      - selección de línea
--      - señal de validación para el driver LCD
--
-- ARQUITECTURA:
--  - FSM de control de flujo
--  - Scroll independiente por punteros (ptr1 / ptr2)
--  - Render de ventana de 16 caracteres
--  - Temporización de frame (~50 ms)
--
-- USO:
--  Se conecta a un driver LCD 4-bit (HD44780U compatible)
-- ============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity marquesina_ctrl is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        ce_1us     : in  std_logic;
        start      : in  std_logic;
        init_done  : in  std_logic;
        busy       : in  std_logic;

        -- SALIDAS AL DRIVER
        char_out   : out std_logic_vector(7 downto 0); 
        line_sel   : out std_logic; -- IMPORTANTE: Conectar al pin RS del LCD (0=CMD, 1=DATA)
        valid      : out std_logic; 
        df_trigger : out std_logic;
        LINEA1     : in std_logic_vector(319 downto 0);
        LINEA2     : in std_logic_vector(319 downto 0)
    );
end entity;

architecture RTL of marquesina_ctrl is
    -- LISTA DE ESTADOS CORREGIDA (Sin nombres huerfanos)
    type state_type is (
        IDLE, 
        TRIGGER_PLAYER,  -- Ahora sigue después de IDLE
        SET_ADDR1, WAIT_BUSY_ADDR1, CHECK_DONE_ADDR1, 
        SEND_L1, WAIT_BUSY_L1, CHECK_DONE_L1, 
        SET_ADDR2, WAIT_BUSY_ADDR2, CHECK_DONE_ADDR2, 
        WAIT_L2, 
        SEND_L2, WAIT_BUSY_L2, CHECK_DONE_L2, 
        WAIT_FRAME
    );

    signal state : state_type := IDLE;
    signal col_i : integer range 0 to 15 := 0;
    signal timer : integer := 0;
    
    signal ptr1 : integer range 0 to 39 := 0;
    signal ptr2 : integer range 0 to 39 := 0; 
    signal scroll_tick1 : integer := 0;
    signal scroll_tick2 : integer := 0;

begin
    process(clk)
        variable char_idx : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                valid <= '0';
                col_i <= 0;
					 df_trigger <= '0';
                timer <= 0;
            elsif init_done = '1' then
                
                case state is
                    when IDLE =>
						      df_trigger <= '0';
                        valid <= '0';
                        if start = '1' then 
								    timer <= 0;
                            state <= TRIGGER_PLAYER; 
                        end if;
								
						 when TRIGGER_PLAYER =>
								  df_trigger <= '1'; -- Activamos base del transistor (satura a GND)
								  -- Generamos un pulso de 100ms (5,000,000 ciclos a 50MHz)
								  if timer < 5000000 then 
										timer <= timer + 1;
								  else
										timer <= 0;
										df_trigger <= '0'; -- Apagamos el pulso
										state <= SET_ADDR1; -- Ahora sí, iniciamos la marquesina
								  end if;		
                    -- ========================================================
                    -- LÍNEA 1: POSICIONAMIENTO
                    -- ========================================================
						  
                    when SET_ADDR1 =>
                        char_out <= x"80"; -- Comando: Inicio L1
                        line_sel <= '0';   -- RS = 0 (Comando)
                        valid    <= '1';   -- Pulso de inicio
                        state    <= WAIT_BUSY_ADDR1;

                    when WAIT_BUSY_ADDR1 =>
                        valid <= '0';      -- Bajamos valid inmediatamente (1 ciclo)
                        if busy = '1' then 
                            state <= CHECK_DONE_ADDR1; 
                        end if;

                    when CHECK_DONE_ADDR1 =>
                        if busy = '0' then 
                            state <= SEND_L1; 
                        end if;

                    when SEND_L1 =>
                        line_sel <= '1'; -- RS = 1 (Dato)
                        char_idx := ((col_i + ptr1) mod 40);
                        char_out <= LINEA1(319 - (char_idx * 8) downto 312 - (char_idx * 8));
                        valid    <= '1';
                        state    <= WAIT_BUSY_L1;

                    when WAIT_BUSY_L1 =>
                        valid <= '0';
                        if busy = '1' then 
                            state <= CHECK_DONE_L1; 
                        end if;

                    when CHECK_DONE_L1 =>
                        if busy = '0' then
                            if col_i = 15 then
                                col_i <= 0;
                                state <= SET_ADDR2;
                            else
                                col_i <= col_i + 1;
                                state <= SEND_L1;
                            end if;
                        end if;

                    -- ========================================================
                    -- LÍNEA 2: POSICIONAMIENTO (Paso crítico corregido)
                    -- ========================================================
                    when SET_ADDR2 =>
                        char_out <= x"C0"; -- Comando: Inicio L2
                        line_sel <= '0';   -- RS = 0
                        valid    <= '1';
                        state    <= WAIT_BUSY_ADDR2;

                    when WAIT_BUSY_ADDR2 =>
                        valid <= '0';
                        if busy = '1' then 
                            state <= CHECK_DONE_ADDR2; 
                        end if;

                    when CHECK_DONE_ADDR2 =>
                        if busy = '0' then
                            timer <= 0;
                            state <= WAIT_L2; -- Pausa de seguridad
                        end if;

                    when WAIT_L2 =>
                        if timer < 100000 then -- 2ms pausa técnica
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= SEND_L2; 
                        end if;

                    when SEND_L2 =>
                        line_sel <= '1'; -- RS = 1 (Dato)
                        char_idx := ((col_i + ptr2) mod 40); 
                        char_out <= LINEA2(319 - (char_idx * 8) downto 312 - (char_idx * 8));
                        valid    <= '1';
                        state    <= WAIT_BUSY_L2;

                    when WAIT_BUSY_L2 =>
                        valid <= '0';
                        if busy = '1' then 
                            state <= CHECK_DONE_L2; 
                        end if;

                    when CHECK_DONE_L2 =>
                        if busy = '0' then
                            if col_i = 15 then
                                col_i <= 0;
                                state <= WAIT_FRAME;
                            else
                                col_i <= col_i + 1;
                                state <= SEND_L2;
                            end if;
                        end if;

                    when WAIT_FRAME =>
                        valid <= '0';
                        if timer < 1250000 then -- 10ms refresco
                            timer <= timer + 1;
                        else
                            timer <= 0;
                            state <= SET_ADDR1; 
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- CONTROL DE VELOCIDAD DEL SCROLL (Igual que antes)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ptr1 <= 0; ptr2 <= 0;
                scroll_tick1 <= 0; scroll_tick2 <= 0;
            elsif init_done = '1' then
                if scroll_tick1 < 15000000 then scroll_tick1 <= scroll_tick1 + 1;
                else scroll_tick1 <= 0; ptr1 <= (ptr1 + 1) mod 40; end if;

                if scroll_tick2 < 15000000 then scroll_tick2 <= scroll_tick2 + 1;
                else scroll_tick2 <= 0; ptr2 <= (ptr2 + 1) mod 40; end if;
            end if;
        end if;
    end process;
    
end architecture;