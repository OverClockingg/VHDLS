library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_FSM is
end tb_FSM;

architecture sim of tb_FSM is

    -- Señales de entrada
    signal clk                : std_logic := '0';
    signal clk_encoder_fisico : std_logic := '0';
    signal dt_encoder_fisico  : std_logic := '0';
    signal rst                : std_logic := '0';
    signal stop1              : std_logic := '0'; -- Sensor 1
    signal stop2              : std_logic := '0'; -- Sensor 2

    -- Señales de salida
    signal coil             : std_logic_vector(3 downto 0);
    signal leds_indicadores : std_logic_vector(3 downto 0);

begin

    -----------------------------------
    -- INSTANCIA DEL TOP (UUT)
    -----------------------------------
    UUT: entity work.StepMotor
    port map(
        clk                => clk,
        clk_encoder_fisico => clk_encoder_fisico,
        dt_encoder_fisico  => dt_encoder_fisico,
        rst                => rst,
        stop1              => stop1,
        stop2              => stop2,
        coil               => coil,
        leds_indicadores   => leds_indicadores
    );

    -----------------------------------
    -- RELOJ (50 MHz = periodo de 20ns)
    -----------------------------------
    clk <= not clk after 10 ns;

    -----------------------------------
    -- PROCESO DE ESTÍMULOS
    -----------------------------------
    process
    begin
        -- 1. Reset inicial
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- 2. SIMULAR GIRO HORARIO (Hacia Sensor 1)
        -- Simulamos 4 clics del encoder
        report "Iniciando giro horario...";
        for i in 0 to 3 loop
            clk_encoder_fisico <= '0'; dt_encoder_fisico <= '0'; wait for 100 ns;
            clk_encoder_fisico <= '0'; dt_encoder_fisico <= '1'; wait for 100 ns;
            clk_encoder_fisico <= '1'; dt_encoder_fisico <= '1'; wait for 100 ns;
            clk_encoder_fisico <= '1'; dt_encoder_fisico <= '0'; wait for 100 ns;
        end loop;

        -- 3. SIMULAR CHOQUE CON SENSOR 1
        report "Choque con Sensor 1 detectado";
        stop1 <= '1'; 
        wait for 1 ms; -- Esperamos un tiempo para ver que se detiene

        -- 4. INTENTAR SEGUIR HACIA S1 (Debe seguir en HOLD)
        report "Intentando seguir hacia S1 (debe fallar)";
        clk_encoder_fisico <= '0'; dt_encoder_fisico <= '0'; wait for 100 ns;
        clk_encoder_fisico <= '0'; dt_encoder_fisico <= '1'; wait for 100 ns;
        clk_encoder_fisico <= '1'; dt_encoder_fisico <= '1'; wait for 100 ns;
        clk_encoder_fisico <= '1'; dt_encoder_fisico <= '0'; wait for 100 ns;
        wait for 500 us;

        -- 5. GIRAR EN SENTIDO OPUESTO PARA SALIR DEL SENSOR
        report "Girando sentido antihorario para escapar del sensor";
        for i in 0 to 3 loop
            clk_encoder_fisico <= '0'; dt_encoder_fisico <= '0'; wait for 100 ns;
            clk_encoder_fisico <= '1'; dt_encoder_fisico <= '0'; wait for 100 ns;
            clk_encoder_fisico <= '1'; dt_encoder_fisico <= '1'; wait for 100 ns;
            clk_encoder_fisico <= '0'; dt_encoder_fisico <= '1'; wait for 100 ns;
        end loop;
        
        stop1 <= '0'; -- El motor ya se alejó del sensor
        wait for 1 ms;

        report "Simulacion finalizada con exito";
        wait;
    end process;

end sim;