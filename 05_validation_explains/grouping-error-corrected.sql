SELECT 
    ds.region, 
    dp.nombre_producto, 
    SUM(fv.monto_neto_venta) AS ventas_totales
FROM dm_ventas.FACT_VENTAS fv
INNER JOIN dm_ventas.DIM_SUCURSAL ds ON fv.sucursal_sk = ds.sucursal_sk
INNER JOIN dm_ventas.DIM_PRODUCTO dp ON fv.producto_sk = dp.producto_sk
GROUP BY 
    ds.region,
    dp.nombre_producto -- Corrige la ambigüedad
ORDER BY 
    ds.region, 
    ventas_totales DESC;