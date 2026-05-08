library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_MARQUESINA is
end tb_MARQUESINA;

architecture sim of tb_MARQUESINA is

    -- Configura el periodo segun tu reloj de 50MHz
    constant CLK_PERIOD : time := 20 ns; 
    
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '0';
    signal LCD_RS : std_logic;
    signal LCD_RW : std_logic;
    signal LCD_E  : std_logic;
    signal LCD_D  : std_logic_vector(3 downto 0);

begin

    -- Instancia de la unidad bajo prueba
    UUT: entity work.MARQUESINA
        generic map ( 
            CLK_FREQ => 50000000 
        )
        port map (
            clk    => clk,
            rst    => rst,
            LCD_RS => LCD_RS,
            LCD_RW => LCD_RW,
            LCD_E  => LCD_E,
            LCD_D  => LCD_D
        );

    -- Generador de reloj
    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Monitor de Bus
    process
        variable v_byte : std_logic_vector(7 downto 0);
    begin
        loop
            -- Capturar primer nibble (MSB)
            wait until falling_edge(LCD_E);
            wait for 2 ns;
            v_byte(7 downto 4) := LCD_D;
            
            -- Capturar segundo nibble (LSB)
            wait until falling_edge(LCD_E);
            wait for 2 ns;
            v_byte(3 downto 0) := LCD_D;

            if LCD_RS = '0' then
                report "COMANDO Hex: " & to_hstring(v_byte);
            else
                -- Solo reportar si es ASCII imprimible
                if v_byte >= x"20" and v_byte <= x"7E" then
                    report "      DATO ASCII: " & character'val(to_integer(unsigned(v_byte)));
                else
                    report "      DATO HEX: " & to_hstring(v_byte);
                end if;
            end if;
        end loop;
    end process;

    -- Proceso de estimulos
    stim_proc: process
    begin
        report "START SIMULATION";
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        
        -- Espera a que RS cambie a datos
        wait until rising_edge(LCD_RS) for 100 ms;
        
        if LCD_RS = '1' then
            report "FSM INITIALIZED - CAPTURING DATA";
        else
            report "TIMEOUT - FSM DID NOT START" severity failure;
        end if;

        wait for 200 ms; 
        
        report "END SIMULATION";
        assert false report "Simulation Finished" severity note;
        wait;
    end process;

end sim;