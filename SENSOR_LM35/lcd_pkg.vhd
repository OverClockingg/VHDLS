--------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    PRACTICA 4
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
    constant CUATRO: std_logic_vector(7 downto 0) := x"34";
    constant CINCO : std_logic_vector(7 downto 0) := x"35";
    constant SEIS  : std_logic_vector(7 downto 0) := x"36";
    constant SIETE : std_logic_vector(7 downto 0) := x"37";
    constant OCHO  : std_logic_vector(7 downto 0) := x"38";
    constant NUEVE : std_logic_vector(7 downto 0) := x"39";
	 constant GRADO : std_logic_vector(7 downto 0) := x"DF"; -- Símbolo °

    -- Alfabeto Completo (Mayúsculas)
    constant A: std_logic_vector(7 downto 0) := x"41"; constant B: std_logic_vector(7 downto 0) := x"42";
    constant C: std_logic_vector(7 downto 0) := x"43"; constant D: std_logic_vector(7 downto 0) := x"44";
    constant E: std_logic_vector(7 downto 0) := x"45"; constant F: std_logic_vector(7 downto 0) := x"46";
    constant G: std_logic_vector(7 downto 0) := x"47"; constant H: std_logic_vector(7 downto 0) := x"48";
    constant I: std_logic_vector(7 downto 0) := x"49"; constant J: std_logic_vector(7 downto 0) := x"4A";
    constant K: std_logic_vector(7 downto 0) := x"4B"; constant L: std_logic_vector(7 downto 0) := x"4C";
    constant M: std_logic_vector(7 downto 0) := x"4D"; constant N: std_logic_vector(7 downto 0) := x"4E";
    constant O: std_logic_vector(7 downto 0) := x"4F"; constant P: std_logic_vector(7 downto 0) := x"50";
    constant Q: std_logic_vector(7 downto 0) := x"51"; constant R: std_logic_vector(7 downto 0) := x"52";
    constant S: std_logic_vector(7 downto 0) := x"53"; constant T: std_logic_vector(7 downto 0) := x"54";
    constant U: std_logic_vector(7 downto 0) := x"55"; constant V: std_logic_vector(7 downto 0) := x"56";
    constant W: std_logic_vector(7 downto 0) := x"57"; constant X: std_logic_vector(7 downto 0) := x"58";
    constant Y: std_logic_vector(7 downto 0) := x"59"; constant Z: std_logic_vector(7 downto 0) := x"5A";
	 

    ----------------------------------------------------------------------------
    -- 3. CONSTANTES DE MENSAJES (Estructura de ROM)
    -- Cada mensaje utiliza 'others => ESP' para garantizar el tamaño de 32 bytes.
    ----------------------------------------------------------------------------
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
	 -- MARQUESINA
    constant MSG_EQUIPO : lcd_string := (ESP,ESP,ESP,ESP,ESP,E,Q,U,I,P,O,ESP,ESP,ESP,ESP,ESP,S,O,L,U,C,I,O,N,E,S,D,L,P,S,ESP,ESP); -- Agregué un ESP al final -- (i) Mensaje fijo
    -- En lugar de usar str_to_lcd, usa los identificadores del diccionario:
	 constant MSG_L1 : lcd_string := (M,E,ESP,C,A,I,G,O,ESP,Y,ESP,M,E,ESP,L,E,V,A,N,T,O, others => ESP);
	 constant MSG_L2 : lcd_string := (J,U,L,I,O,ESP,C,O,R,T,A,Z,A,R, others => ESP);
	 constant MSG_TEMP : lcd_string := (T,E,M,P,E,R,A,T,U,R,A,DOSP,ESP,ESP,ESP,C, others => ESP);
	 constant MSG_POT  : lcd_string := (A,N,G,U,L,O,DOSP,ESP,ESP,ESP,GRADO, others => ESP);
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
			   when "0000" => return MSG_L1(idx);
            when "0001" => return MSG_BIENVENIDOS(idx);
            when "0010" => return MSG_DIVIERTANSE(idx);
            when "0011" => return MSG_SELECCIONE(idx);
            when "0100" => return MSG_TEMP(idx);  -- ID 4 exclusivo para Temperatura
            when "0101" => return MSG_POT(idx);   -- ID 5 exclusivo para Potenciómetro
            when "0110" => return MSG_JUEGO1(idx);
            when "0111" => return MSG_JUEGO2(idx);
            when "1000" => return MSG_ERROR_MODO(idx);
            when "1001" => return MSG_COUNT_3(idx);
            when "1010" => return MSG_COUNT_2(idx);
            when "1011" => return MSG_COUNT_1(idx);
            when "1100" => return MSG_GO(idx);
            when "1101" => return MSG_FIN(idx);
            when "1110" => return MSG_L2(idx);
            when "1111" => return MSG_EQUIPO(idx);
            when others => return ESP;
       end case;
    end function;

    -- Implementación de selector de longitud útil
    function get_msg_len(id : std_logic_vector(3 downto 0)) return integer is
    begin
        case id is
            when "0001" => return 32; 
            when "0100" => return 16; -- "TEMPERATURA: XX C"
            when "0101" => return 11; -- "ANGULO: XXX °"
            when "0010" => return 12;
            when "0011" => return 19;
            when "0110" => return 7;
            when "0111" => return 7;
            when "1000" => return 32; 
            when "1001" => return 1;
            when "1010" => return 1;
            when "1011" => return 1;
            when "1100" => return 8;
            when "1101" => return 13;
            when "1110" => return 21;
            when others => return 0;
        end case;
    end function;

end package body;