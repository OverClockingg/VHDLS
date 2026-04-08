library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Activar_sistema is
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        stop1          : in  std_logic;
        stop2          : in  std_logic;
        paso_bus       : in  std_logic; -- Pulso del sensor seleccionado
        dir_bus        : in  std_logic; -- Dirección del sensor seleccionado
        
        motor_enable   : out std_logic;
        dir_registrada : out std_logic
    );
end Activar_sistema;

architecture Behavioral of Activar_sistema is
    signal enable_int : std_logic := '0';
    signal dir_int    : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- PRIORIDAD MÁXIMA: Reset y Choques
            if rst = '1' then
                enable_int <= '0';
                dir_int    <= '0';
            
            -- Si el motor está activo, lo apagamos inmediatamente si toca un límite
            elsif enable_int = '1' and ((stop1 = '1' and dir_int = '0') or (stop2 = '1' and dir_int = '1')) then
                enable_int <= '0';
                
            -- ACTIVACIÓN: Si detectamos movimiento del encoder
            elsif paso_bus = '1' then
                -- Solo encendemos si no estamos intentando girar hacia un límite ya presionado
                if not ((stop1 = '1' and dir_bus = '0') or (stop2 = '1' and dir_bus = '1')) then
                    enable_int <= '1'; -- Enclavamiento
                    dir_int    <= dir_bus;
                else
                    enable_int <= '0'; -- Bloqueo de seguridad
                end if;
            
            -- Si no hay pulsos ni choques, mantiene su estado anterior automáticamente
            end if;
        end if;
    end process;

    -- Salida continua de las señales registradas
    motor_enable   <= enable_int;
    dir_registrada <= dir_int;

end Behavioral;