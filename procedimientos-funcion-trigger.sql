/*
Apartado A)
Crea un procedimiento que reciba como par�metro el nombre de una marca de coche 
y la elimine. Debemos contemplar la siguiente casu�stica:
    - La marca no existe
    - Existen coches de esa marca
    - La marca existe y no existen coches de la misma
*/

CREATE OR REPLACE PROCEDURE procedimientoA (v_MarcaCoche marca.nombre%TYPE) AS
    --Declaramos unas variables donde almacenar lo que nos devuelven los cursores impl�citos
    v_cifm marca.cifm%TYPE;
    v_countCoches NUMBER;
    --Declaramos las excepciones definidas por el usuario
    tiene_coches_relacionados EXCEPTION;

BEGIN
    --Comprobamos si la marca de coches existe
        SELECT cifm INTO v_cifm FROM marca WHERE nombre=v_MarcaCoche;
    --Si no encuentra datos es porque la marca no existe y saltar� una excepci�n
      
    /*Comprobamos si hay coches asociados a esa marca usando el c�digo de la marca
    que hab�amos guardado en una variable*/
    SELECT COUNT(*) INTO v_countCoches FROM coche WHERE cifm = v_cifm;
    --Si el n�mero de coches es mayor que cero entonces
    IF v_countCoches > 0 THEN
        RAISE tiene_coches_relacionados;
    ELSE
        --En cualquier otro caso, eliminamos la marca de la base de datos porque no tiene coches asociados
        DELETE FROM marca WHERE nombre=v_MarcaCoche;
        DBMS_OUTPUT.PUT_LINE('La MARCA ' || v_MarcaCoche || ' SE HA ELIMINADO');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20023, 'ERROR: La MARCA ' || v_MarcaCoche || ' NO EXISTE');
    WHEN tiene_coches_relacionados THEN
        RAISE_APPLICATION_ERROR(-20022, 'La marca ' || v_MarcaCoche || ' no se puede borrar porque est� relacionada con alg�n coche.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 'Error no esperado');
END;
/


--Habilitamos la salida por consola con la siguiente sentencia
SET SERVEROUTPUT ON;

BEGIN
    procedimientoA('SEAT');
END;
/

BEGIN
    procedimientoA('BMW');
END;
/

BEGIN
    procedimientoA('AUDI');
END;
/

/*
Apartado B)
Crear un procedimientoB que reciba como par�metro el c�digo de un concesionario
y muestres por pantalla el porcentaje que distribuye respecto al total de coches
distribuidos y nos visualice, por cada concesionario, la cantidad de coches que
ha distribuido
*/

CREATE OR REPLACE PROCEDURE procedimientoB (v_CodConcesionario concesionario.cifc%TYPE) AS
    v_TotalDistribuido NUMBER;
    v_DistribuidoConcesionario NUMBER;
    v_PorcentajeDistribuido NUMBER;
    v_NombreConcesionario concesionario.nombre%TYPE;
    
    --Declaramos un cursor para obtener la cantidad de coches distribuidos por cada concesionario
    CURSOR c_distribuido IS 
        SELECT distribucion.cifc, concesionario.nombre, COUNT (*)AS cantidad 
        FROM distribucion 
        JOIN concesionario ON distribucion.cifc = concesionario.cifc
        GROUP BY distribucion.cifc, concesionario.nombre;

BEGIN
    -- Calcular el total de coches distribuidos por todos los concesionarios
    SELECT COUNT(*) INTO v_TotalDistribuido FROM distribucion;

    -- Calcular el total de coches distribuidos por el concesionario especificado
    SELECT COUNT(*) INTO v_DistribuidoConcesionario 
    FROM distribucion 
    WHERE cifc = v_CodConcesionario;
    
    --Guardamos el nombre del concesionario cuyo c�digo nos pasan como par�metro
    SELECT nombre INTO v_NombreConcesionario
    FROM concesionario
    WHERE cifc = v_codConcesionario;

    -- Calculamos el porcentaje de distribuci�n del concesionario respecto al total
    IF v_TotalDistribuido > 0 THEN
        v_PorcentajeDistribuido := (v_DistribuidoConcesionario / v_TotalDistribuido) * 100;
    ELSE
        v_PorcentajeDistribuido := 0;
    END IF;

    --Vamos a contar cuantos coches ha distribuido cada concesionario
    DBMS_OUTPUT.PUT_LINE(RPAD('Concesionario', 15, ' ') || RPAD('Cantidad', 15, ' '));
    /* Mostramos la cantidad de coches distribuidos por cada concesionario. Vamos 
    a usar un bucle especial para cursores.
    cConcesionario se declara impl�citamente al usar el for para cursores y ser�
    de tipo %ROWTYPE y por tanto almacena los campos de la fila cursor   
    */

    FOR cConcesionario IN c_distribuido LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(cConcesionario.nombre, 15, ' ') || LPAD(cConcesionario.cantidad, 5, ' '));
    END LOOP;
    --Mostramos el total de coches distribuidos en todos los concesionarios
    DBMS_OUTPUT.PUT_LINE('Total:');
    DBMS_OUTPUT.PUT_LINE(v_TotalDistribuido);
     
    -- Mostrar los datos del concesionario pasado como par�metro
    DBMS_OUTPUT.PUT_LINE('Concesionario: ' || v_NombreConcesionario);
    DBMS_OUTPUT.PUT_LINE('Coches distribuidos: ' || v_DistribuidoConcesionario);
    DBMS_OUTPUT.PUT_LINE('Porcentaje sobre el total: ' || ROUND(v_PorcentajeDistribuido, 2));
   
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021, 'El concesionario con c�digo ' || v_CodConcesionario || ' no existe.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 'Error no esperado');
END;
/

--Habilitamos la salida por consola con la siguiente sentencia
SET SERVEROUTPUT ON;

BEGIN
    procedimientoB(2);
END;
/

BEGIN
    procedimientoB(6);
END;
/

/*
Apartado C)
Crea una funcionC que realice la venta de un coche.
La funcion debe comprobar los siguientes supuestos y mostrar los diferentes errores
en cada uno de los casos:
    - El concesionario no existe
    - El coche no existe
    - El cliente no existe
    - El coche ya ha sido vendido
Se entiende que hay stock del coche que queremos vender.
*/
CREATE OR REPLACE FUNCTION funcionC (
    v_cifc concesionario.cifc%TYPE, v_codcoche coche.codcoche%TYPE, 
    v_dni cliente.dni%TYPE, v_pvp venta.pvp%TYPE)
RETURN VARCHAR2 --Devolvemos un valor de tipo cadena de texto
AS mensaje_venta VARCHAR2(100);

--Establecemos la fecha de venta con la fecha del sistema
v_fechaventa DATE := SYSDATE;

--Declaramos las variables necesarias
v_count_cifc NUMBER;
v_count_codcoche NUMBER;
v_count_cliente NUMBER;
v_coche_vendido NUMBER;

BEGIN
    --Inicializamos la variable que vamos a devolver con un valor inicial de cadena vac�a
    mensaje_venta := '';
    
    --Vamos a verificar si el concesionario existe
    SELECT COUNT (*) INTO v_count_cifc FROM concesionario WHERE cifc = v_cifc;
    --Si el count no devuelve 0 existe el concesionario y se sigue con el c�digo sin entrar en el IF
    --Si el count devuelve 0 es que no existe el concesionario
    IF v_count_cifc = 0 THEN
        mensaje_venta := 'No se ha producido la venta porque el concesionario con el c�digo ' || v_cifc || ' no existe';
        RETURN mensaje_venta;
    END IF;
    
    --Vamos a verificar si el coche existe
    SELECT COUNT (*) INTO v_count_codcoche FROM coche WHERE codcoche = v_codcoche;
    --Si el count no devuelve 0 existe el coche y se sigue con el c�digo sin entrar en el IF
    --Si el count devuelve 0 es que no existe el coche
    IF v_count_codcoche = 0 THEN
        mensaje_venta := 'No se ha producido la venta porque el coche con el c�digo ' || v_codcoche || ' no existe';
        RETURN mensaje_venta;
    END IF;
    
    --Vamos a verificar si el cliente existe
    SELECT COUNT (*) INTO v_count_cliente FROM cliente WHERE dni = v_dni;
    --Si el count no devuelve 0 existe el cliente y se sigue con el c�digo sin entrar en el IF
    --Si el count devuelve 0 es que no existe el cliente
    IF v_count_cliente = 0 THEN
        mensaje_venta := 'No se ha producido la venta porque el cliente con el dni ' || v_dni || ' no existe';
        RETURN mensaje_venta;
    END IF;
    
    --Vamos a verificar si el coche ha sido ya vendido
    SELECT COUNT (*) INTO v_coche_vendido FROM venta WHERE codcoche = v_codcoche;
    --Si el count devuelve 0 el coche no se ha vendido y se sigue con el c�digo sin entrar en el IF
    --Si el count devuelve 0 es que el coche ya se ha vendido
    IF v_coche_vendido != 0 THEN
        mensaje_venta := 'No se ha producido la venta porque el coche con el c�digo ' || v_codcoche || ' ya ha sido vendido';
        RETURN mensaje_venta;
    END IF;
    
    --Si llegamos hasta aqu� es porque se puede vender el coche
    INSERT INTO venta (cifc, codcoche, dni, fechaventa, pvp) 
    VALUES (v_cifc, v_codcoche, v_dni, v_fechaventa, v_pvp);
    
    --Actualizamos el mensaje de salida y lo devolvemos
    mensaje_venta := 'Venta realizada con �xito';
    RETURN mensaje_venta;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        mensaje_venta := 'Error: Datos no encontrados';
        RETURN mensaje_venta;
    WHEN OTHERS THEN
        mensaje_venta := 'Error no esperado';
        RETURN mensaje_venta;
        
END;
/

--Habilitamos la salida por consola con la siguiente sentencia
SET SERVEROUTPUT ON;
--Probamos la funci�n
DECLARE
mensaje_salida VARCHAR2(100);
cifc concesionario.cifc%TYPE;
codcoche coche.codcoche%TYPE;
dni cliente.dni%TYPE;
pvp venta.pvp%TYPE;

BEGIN
    cifc := 2; 
    codcoche := 10;
    dni := '33245654T';
    pvp := 9000;
    mensaje_salida := funcionc(cifc, codcoche, dni, pvp);
    DBMS_OUTPUT.PUT_LINE(mensaje_salida);
END;
/

--Concesionario no existe
DECLARE
mensaje_salida VARCHAR2(100);
cifc concesionario.cifc%TYPE;
codcoche coche.codcoche%TYPE;
dni cliente.dni%TYPE;
pvp venta.pvp%TYPE;

BEGIN
    cifc := 10; 
    codcoche := 9;
    dni := '33245654T';
    pvp := 9000;
    mensaje_salida := funcionc(cifc, codcoche, dni, pvp);
    DBMS_OUTPUT.PUT_LINE(mensaje_salida);
END;
/

--Coche no existe
DECLARE
mensaje_salida VARCHAR2(100);
cifc concesionario.cifc%TYPE;
codcoche coche.codcoche%TYPE;
dni cliente.dni%TYPE;
pvp venta.pvp%TYPE;

BEGIN
    cifc := 2; 
    codcoche := 15;
    dni := '33245654T';
    pvp := 9000;
    mensaje_salida := funcionc(cifc, codcoche, dni, pvp);
    DBMS_OUTPUT.PUT_LINE(mensaje_salida);
END;
/

--Cliente no existe
DECLARE
mensaje_salida VARCHAR2(100);
cifc concesionario.cifc%TYPE;
codcoche coche.codcoche%TYPE;
dni cliente.dni%TYPE;
pvp venta.pvp%TYPE;

BEGIN
    cifc := 2; 
    codcoche := 10;
    dni := '33245655T';
    pvp := 9000;
    mensaje_salida := funcionc(cifc, codcoche, dni, pvp);
    DBMS_OUTPUT.PUT_LINE(mensaje_salida);
END;
/

--Coche ya vendido
DECLARE
mensaje_salida VARCHAR2(100);
cifc concesionario.cifc%TYPE;
codcoche coche.codcoche%TYPE;
dni cliente.dni%TYPE;
pvp venta.pvp%TYPE;

BEGIN
    cifc := 2; 
    codcoche := 10;
    dni := '33245654T';
    pvp := 9000;
    mensaje_salida := funcionc(cifc, codcoche, dni, pvp);
    DBMS_OUTPUT.PUT_LINE(mensaje_salida);
END;
/


/*
Apartado D)
Crea un trigger denominado compruebacon que impida que un concesionario distribuya
m�s de tres marcas de coches distintas. Si se intenta incumplir esta condici�n,
el trigger se ejecutar� y mostrar� el aviso correspondiente, evitando que se 
produzca la acci�n. El trigger se debe ejecutar en cualquier condici�n que incumpla
la condici�n anterior, ya sea en inserci�n, borrado o actualizaci�n, que el
alumnado considere necesaria.
*/

CREATE OR REPLACE TRIGGER compruebacon
/*El trigger solo funciona con la inserci�n porque la actualizaci�n implicar�a
trabajar con una tabla mutante y el borrado no har� que se imcumpla el m�ximo de
marcas distribuidas*/
BEFORE INSERT ON distribucion
FOR EACH ROW

DECLARE
v_numeroMarcas NUMBER;
v_marcaNueva coche.cifm%TYPE;
v_marcaDistribuida NUMBER;

BEGIN
    --Este mensaje nos ayuda a ver que hemos entrado al trigger
    DBMS_OUTPUT.PUT_LINE('Insertando registro');
    --Contamos el n�mero de marcas que ya distribuye el concesionario
    SELECT COUNT (DISTINCT coche.cifm)
    into v_numeroMarcas
    FROM coche
    INNER JOIN distribucion on distribucion.codcoche = coche.codcoche
    WHERE distribucion.cifc = :new.cifc;
    --Almacenamos la marca de coche que vamos a insertar o actualizar
    SELECT coche.cifm
    into v_marcaNueva
    from coche
    where coche.codcoche = :new.codcoche;
    --Contamos si distribuye la marca nueva
    SELECT COUNT (*)
    INTO v_marcaDistribuida
    FROM coche
    INNER JOIN distribucion on distribucion.codcoche = coche.codcoche
    WHERE distribucion.cifc = :new.cifc
    AND coche.cifm = v_marcanueva;
    /*Si el numero de marcas que ya distribuye el concesionario que vamos a insertar
    ya es tres, que es el m�ximo, tendremos el cuenta si la marca del nuevo coche
    est� ya siendo distribuida por ese concesionario*/
    IF v_numeroMarcas = 3 THEN
        /*Si el conteo es cero es porque la marca del coche nuevo no est� siendo
        distribuida por el concesionario, por tanto har�a que las marcas distribuidas
        fueran m�s de tres y tendr�a que saltar un error en la aplicaci�n que
        impide que se inserte el registro nuevo*/
        IF v_marcaDistribuida = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Se va a superar el n�mero de marcas que puede distribuir el concesionario');
        END IF;
    END IF;
END;
/

SET SERVEROUTPUT ON;
--Probamos el Trigger
BEGIN
INSERT INTO distribucion (cifc, codcoche,fecha) VALUES (1, 5, SYSDATE);
END;
/

BEGIN
INSERT INTO distribucion (cifc, codcoche,fecha) VALUES (1, 7, SYSDATE);
END;
/

BEGIN
INSERT INTO distribucion (cifc, codcoche,fecha) VALUES (2, 2, SYSDATE);
END;
/