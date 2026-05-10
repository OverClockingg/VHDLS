--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    Exergame "BUM BAM BIRI" - Tarea 1 DLP
-- Descripción: Package que centraliza el diccionario de caracteres, constantes
--              de mensajes y funciones de acceso seguro para el display LCD.
--              Diseñado para síntesis robusta en FPGAs (Tipo Fijo/Safe Boundary).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package lcd_pkg is

    -- 1. DEFINICIÓN DE TIPOS
    -- Se define un rango fijo de 32 (16x2 caracteres) para asegurar que el 
    -- sintetizador reserve bloques de memoria constantes y evitar errores de indexación.
    type lcd_string is array (0 to 31) of std_logic_vector(7 downto 0);

    -- 2. DICCIONARIO DE CARACTERES (Codificación ASCII/HD44780)
    -- Definición manual de constantes para facilitar la legibilidad del código.
    constant ESP   : std_logic_vector(7 downto 0) := x"20"; -- Espacio
    constant ADM   : std_logic_vector(7 downto 0) := x"21"; -- !
    constant COMA  : std_logic_vector(7 downto 0) := x"2C"; -- ,
    constant DOSP  : std_logic_vector(7 downto 0) := x"3A"; -- :
    constant SLASH : std_logic_vector(7 downto 0) := x"2F"; -- /
    
    -- Caracteres numéricos
    constant CERO  : std_logic_vector(7 downto 0) := x"30";
    constant UNO   : std_logic_vector(7 downto 0) := x"31";
    constant DOS   : std_logic_vector(7 downto 0) := x"32";
    constant TRES  : std_logic_vector(7 downto 0) := x"33";

    -- Alfabeto (Mayúsculas seleccionadas)
    constant A: std_logic_vector(7 downto 0) := x"41"; constant B: std_logic_vector(7 downto 0) := x"42";
    constant C: std_logic_vector(7 downto 0) := x"43"; constant D: std_logic_vector(7 downto 0) := x"44";
    constant E: std_logic_vector(7 downto 0) := x"45"; constant F: std_logic_vector(7 downto 0) := x"46";
    constant G: std_logic_vector(7 downto 0) := x"47"; constant H: std_logic_vector(7 downto 0) := x"48";
    constant I: std_logic_vector(7 downto 0) := x"49"; constant J: std_logic_vector(7 downto 0) := x"4A";
    constant L: std_logic_vector(7 downto 0) := x"4C"; constant M: std_logic_vector(7 downto 0) := x"4D";
    constant N: std_logic_vector(7 downto 0) := x"4E"; constant O: std_logic_vector(7 downto 0) := x"4F";
    constant P: std_logic_vector(7 downto 0) := x"50"; constant R: std_logic_vector(7 downto 0) := x"52";
    constant S: std_logic_vector(7 downto 0) := x"53"; constant T: std_logic_vector(7 downto 0) := x"54";
    constant U: std_logic_vector(7 downto 0) := x"55"; constant V: std_logic_vector(7 downto 0) := x"56";
	 constant Q: std_logic_vector(7 downto 0) := x"51";

    ----------------------------------------------------------------------------
    -- 3. CONSTANTES DE MENSAJES (Estructura de ROM)
    -- Cada mensaje utiliza 'others => ESP' para garantizar el tamaño de 32 bytes.
    ----------------------------------------------------------------------------
	 -- Mensaje Neutro / Vacío (ID: 0000)
    constant MSG_BLANCO      : lcd_string := (others => ESP);
    -- Mensaje de bienvenida (ID: 0001)
    constant MSG_BIENVENIDOS : lcd_string := (ESP,ESP,B,I,E,N,V,E,N,I,D,O,S,ESP,A,ESP,ESP,ESP,B,U,M,ESP,B,A,M,ESP,B,I,R,I,ESP,ESP);
    -- Mensaje de cortesía (ID: 0010)
    constant MSG_DIVIERTANSE : lcd_string := (D,I,V,I,E,R,T,A,N,S,E,ADM, others => ESP);
    
    -- Instrucción de selección (ID: 0011)
    constant MSG_SELECCIONE  : lcd_string := (S,E,L,E,C,C,I,O,N,E,ESP,E,L,ESP,J,U,E,G,O, others => ESP);
    
    -- Modos de operación (IDs: 0100 a 0111)
    constant MSG_TEST        : lcd_string := (T,E,S,T, others => ESP);
    constant MSG_DEMO        : lcd_string := (D,E,M,O, others => ESP);
    constant MSG_JUEGO1      : lcd_string := (J,U,E,G,O,ESP,UNO, others => ESP);
    constant MSG_JUEGO2      : lcd_string := (J,U,E,G,O,ESP,DOS, others => ESP);
    
    -- Mensajes de error y control (IDs: 1000 a 1101)
    constant MSG_ERROR_MODO  : lcd_string := (S,E,L,E,C,C,I,O,N,E,ESP,S,O,L,O,ESP,U,N,ESP,M,O,D,O,ESP,D,E,ESP,J,U,E,G,O, others => ESP);
    constant MSG_COUNT_3     : lcd_string := (0 => TRES, others => ESP);
    constant MSG_COUNT_2     : lcd_string := (0 => DOS,  others => ESP);
    constant MSG_COUNT_1     : lcd_string := (0 => UNO,  others => ESP);
    constant MSG_GO          : lcd_string := (ADM,ADM,ADM,G,O,ADM,ADM,ADM, others => ESP);
    constant MSG_FIN         : lcd_string := (F,I,N,ESP,D,E,L,ESP,J,U,E,G,O, others => ESP);
    
    -- Mensaje de victoria (ID: 1110)
    constant MSG_GANASTE     : lcd_string := (ADM,F,E,L,I,C,I,D,A,D,E,S,ESP,G,A,N,A,S,T,E,ADM, others => ESP);
	 
	 constant MSG_EQUIPO_SOL : lcd_string := (
        ESP,ESP,ESP,E,Q,U,I,P,O,DOSP,S,O,L,ESP,ESP,ESP, -- Fila 1
        ESP,ESP,ESP,ESP,ESP,ESP,D,L,P,S,ESP,ESP,ESP,ESP,ESP,ESP -- Fila 2
    );

    ----------------------------------------------------------------------------
    -- 4. PROTOTIPOS DE FUNCIONES
    ----------------------------------------------------------------------------
    -- get_lcd_char: Retorna un byte específico de un mensaje basado en ID e índice.
    function get_lcd_char(id : std_logic_vector(3 downto 0); idx : integer) return std_logic_vector;
    
    -- get_msg_len: Retorna la longitud útil (número de caracteres a imprimir) del mensaje.
    function get_msg_len(id : std_logic_vector(3 downto 0)) return integer;

end package;

package body lcd_pkg is

    -- Implementación de selector de caracteres con protección de fronteras (Safe Access)
    function get_lcd_char(id : std_logic_vector(3 downto 0); idx : integer) return std_logic_vector is
    begin
        -- Validación de rango: Evita accesos fuera de los 32 bytes reservados en hardware.
        if idx < 0 or idx > 31 then
            return ESP;
        end if;

        case id is
            when "0000" => return MSG_BLANCO(idx);
				when "0001" => return MSG_BIENVENIDOS(idx);
            when "0010" => return MSG_DIVIERTANSE(idx);
            when "0011" => return MSG_SELECCIONE(idx);
            when "0100" => return MSG_TEST(idx);
            when "0101" => return MSG_DEMO(idx);
            when "0110" => return MSG_JUEGO1(idx);
            when "0111" => return MSG_JUEGO2(idx);
            when "1000" => return MSG_ERROR_MODO(idx);
            when "1001" => return MSG_COUNT_3(idx);
            when "1010" => return MSG_COUNT_2(idx);
            when "1011" => return MSG_COUNT_1(idx);
            when "1100" => return MSG_GO(idx);
            when "1101" => return MSG_FIN(idx);
            when "1110" => return MSG_GANASTE(idx);
				when "1111" => return MSG_EQUIPO_SOL(idx);
            when others => return ESP;
        end case;
    end function;

    -- Implementación de selector de longitud útil
    function get_msg_len(id : std_logic_vector(3 downto 0)) return integer is
    begin
        case id is
            when "0000" => return 0;
				when "0001" => return 32; 
            when "0010" => return 12;
            when "0011" => return 19;
            when "0100" => return 4;
            when "0101" => return 4;
            when "0110" => return 7;
            when "0111" => return 7;
            when "1000" => return 32; 
            when "1001" => return 1;
            when "1010" => return 1;
            when "1011" => return 1;
            when "1100" => return 8;
            when "1101" => return 13;
            when "1110" => return 21;
				when "1111" => return 32;
            when others => return 0;
        end case;
    end function;

end package body;