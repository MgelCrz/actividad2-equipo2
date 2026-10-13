USE dm_ventas;

DELIMITER //

CREATE PROCEDURE sp_reporte_rentabilidad_top5(
    IN p_anio INT,
    IN p_trimestre_actual INT,
    IN p_trimestre_anterior INT
)
BEGIN
    WITH devoluciones_agg AS (
        -- 1. Pre-agregación optimizada (Predicate Pushdown) para aislar devoluciones del periodo
        SELECT 
            fd.ticket_venta_origen,
            fd.linea_venta_origen,
            SUM(fd.monto_devolucion) AS total_devolucion
        FROM FACT_DEVOLUCIONES fd
        INNER JOIN DIM_TIEMPO dt ON fd.tiempo_sk = dt.tiempo_sk
        WHERE dt.anio = p_anio 
          AND dt.trimestre IN (p_trimestre_anterior, p_trimestre_actual)
        GROUP BY fd.ticket_venta_origen, fd.linea_venta_origen
    ),
    
    ventas_base AS (
        -- 2. Enlace de la estrella dimensional y filtrado por periodos evaluados
        SELECT 
            ds.region,
            dc.canal,
            dp.producto_id,
            dp.nombre_producto,
            dt.trimestre,
            fv.margen_neto_real,
            fv.monto_neto_venta,
            COALESCE(fd.total_devolucion, 0) AS total_devolucion
        FROM FACT_VENTAS fv
        INNER JOIN DIM_TIEMPO dt   ON fv.tiempo_sk = dt.tiempo_sk
        INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_sk = ds.sucursal_sk
        INNER JOIN DIM_CANAL dc    ON fv.canal_sk = dc.canal_sk
        INNER JOIN DIM_PRODUCTO dp ON fv.producto_sk = dp.producto_sk
        LEFT JOIN devoluciones_agg fd 
               ON fv.num_ticket = fd.ticket_venta_origen 
              AND fv.num_linea = fd.linea_venta_origen
        WHERE dt.anio = p_anio 
          AND dt.trimestre IN (p_trimestre_anterior, p_trimestre_actual)
    ),
    
    metricas_producto AS (
        -- 3. Agregación condicional por Región, Canal y Producto
        SELECT 
            vb.region,
            vb.canal,
            vb.producto_id,
            vb.nombre_producto,
            SUM(CASE WHEN vb.trimestre = p_trimestre_anterior THEN (vb.margen_neto_real - vb.total_devolucion) ELSE 0 END) AS rentabilidad_q1,
            COUNT(CASE WHEN vb.trimestre = p_trimestre_anterior THEN 1 END) AS lineas_facturadas_q1,
            SUM(CASE WHEN vb.trimestre = p_trimestre_actual THEN (vb.margen_neto_real - vb.total_devolucion) ELSE 0 END) AS rentabilidad_q2,
            SUM(CASE WHEN vb.trimestre = p_trimestre_actual THEN vb.monto_neto_venta ELSE 0 END) AS monto_neto_venta_q2
        FROM ventas_base vb
        GROUP BY vb.region, vb.canal, vb.producto_id, vb.nombre_producto
    ),
    
    calculo_variaciones AS (
        -- 4. Métricas de variación, seguridad ante división por cero y ranking por ventana
        SELECT 
            mp.region,
            mp.canal,
            mp.producto_id,
            mp.nombre_producto,
            mp.rentabilidad_q2,
            mp.rentabilidad_q1,
            (mp.rentabilidad_q2 - mp.rentabilidad_q1) AS variacion_abs,
            ((mp.rentabilidad_q2 - mp.rentabilidad_q1) / NULLIF(mp.rentabilidad_q1, 0)) * 100 AS variacion_pct,
            (mp.rentabilidad_q2 / NULLIF(mp.monto_neto_venta_q2, 0)) * 100 AS margen_pct_q2,
            CASE 
                WHEN mp.lineas_facturadas_q1 = 0 THEN 'Sí'
                ELSE 'No'
            END AS flag_sin_ventas_q1,
            ROW_NUMBER() OVER(PARTITION BY mp.region, mp.canal ORDER BY mp.rentabilidad_q2 DESC) AS pos
        FROM metricas_producto mp
        WHERE mp.monto_neto_venta_q2 > 0 
    )
    
    -- 5. Proyección filtrada al Top 5 estricto por combinación de Región y Canal
    SELECT 
        cv.region,
        cv.canal,
        cv.pos AS posicion,
        cv.producto_id,
        cv.nombre_producto,
        cv.rentabilidad_q2 AS rentabilidad_periodo_actual,
        cv.rentabilidad_q1 AS rentabilidad_periodo_anterior,
        cv.variacion_abs AS variacion_absoluta,
        cv.variacion_pct AS variacion_porcentual,
        cv.margen_pct_q2 AS margen_porcentual_actual,
        cv.flag_sin_ventas_q1 AS flag_sin_ventas_periodo_anterior
    FROM calculo_variaciones cv
    WHERE cv.pos <= 5
    ORDER BY 
        cv.region ASC, 
        cv.canal ASC, 
        cv.pos ASC;
END //

DELIMITER ;

-- Ejemplo de llamada en MySQL:
-- CALL sp_reporte_rentabilidad_top5(2026, 2, 1);
