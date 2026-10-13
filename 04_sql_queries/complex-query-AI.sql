WITH devoluciones_agg AS (
    SELECT 
        ticket_venta_origen,
        linea_venta_origen,
        SUM(monto_devolucion) AS total_devolucion
    FROM dm_ventas.FACT_DEVOLUCIONES
    GROUP BY 1, 2
),

ventas_base AS (
    SELECT 
        ds.region,
        dc.canal,
        dp.producto_id,
        dp.nombre_producto,
        dt.trimestre,
        fv.margen_neto_real,
        fv.monto_neto_venta,
        COALESCE(fd.total_devolucion, 0) AS total_devolucion
    FROM dm_ventas.FACT_VENTAS fv
    INNER JOIN dm_ventas.DIM_TIEMPO dt 
            ON fv.tiempo_sk = dt.tiempo_sk
    INNER JOIN dm_ventas.DIM_SUCURSAL ds 
            ON fv.sucursal_sk = ds.sucursal_sk
    INNER JOIN dm_ventas.DIM_CANAL dc 
            ON fv.canal_sk = dc.canal_sk
    INNER JOIN dm_ventas.DIM_PRODUCTO dp 
            ON fv.producto_sk = dp.producto_sk
    LEFT JOIN devoluciones_agg fd 
           ON fv.num_ticket = fd.ticket_venta_origen 
          AND fv.num_linea = fd.linea_venta_origen
    WHERE dt.anio = 2026 AND dt.trimestre IN (1, 2)
),

metricas_producto AS (
    SELECT 
        region,
        canal,
        producto_id,
        nombre_producto,
        -- Bloque Q1
        SUM(CASE WHEN trimestre = 1 THEN (margen_neto_real - total_devolucion) ELSE 0 END) AS rentabilidad_q1_2026,
        COUNT(CASE WHEN trimestre = 1 THEN 1 END) AS lineas_facturadas_q1,
        -- Bloque Q2
        SUM(CASE WHEN trimestre = 2 THEN (margen_neto_real - total_devolucion) ELSE 0 END) AS rentabilidad_q2_2026,
        SUM(CASE WHEN trimestre = 2 THEN monto_neto_venta ELSE 0 END) AS monto_neto_venta_q2
    FROM ventas_base
    GROUP BY 1, 2, 3, 4
),

calculo_variaciones AS (
    SELECT 
        region,
        canal,
        producto_id,
        nombre_producto,
        rentabilidad_q2_2026,
        rentabilidad_q1_2026,
        
        -- Variaciones matemáticas
        (rentabilidad_q2_2026 - rentabilidad_q1_2026) AS variacion_absoluta,
        
        ((rentabilidad_q2_2026 - rentabilidad_q1_2026) / NULLIF(rentabilidad_q1_2026, 0)) * 100 AS variacion_porcentual,
        
        (rentabilidad_q2_2026 / NULLIF(monto_neto_venta_q2, 0)) * 100 AS margen_porcentual_q2,
        
        -- Regla de apoyo visual: Identificación de productos de reciente ingreso
        CASE 
            WHEN lineas_facturadas_q1 = 0 THEN 'Sí'
            ELSE 'No'
        END AS flag_sin_ventas_q1,
        
        -- Función de ventana particionada
        ROW_NUMBER() OVER(PARTITION BY region, canal ORDER BY rentabilidad_q2_2026 DESC) AS posicion
        
    FROM metricas_producto
    -- Aseguramos rankear únicamente productos que sí tuvieron participación real en Q2
    WHERE monto_neto_venta_q2 > 0 
)

SELECT 
    region,
    canal,
    posicion,
    producto_id,
    nombre_producto,
    rentabilidad_q2_2026,
    rentabilidad_q1_2026,
    variacion_absoluta,
    variacion_porcentual,
    margen_porcentual_q2,
    flag_sin_ventas_q1
FROM calculo_variaciones
WHERE posicion <= 5
ORDER BY 
    region ASC, 
    canal ASC, 
    posicion ASC;