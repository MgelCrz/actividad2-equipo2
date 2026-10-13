-- El error de agrupación estricta (42803 en PostgreSQL / 1055 en MySQL) ocurre porque las bases de datos relacionales modernas
-- no permiten la ambigüedad en proyecciones agregadas. Al usar una función agregada como SUM(monto_neto_venta) y agrupar solo por 
-- ds.region, el motor comprime múltiples filas en una sola cubeta por región. Sin embargo, en la cláusula SELECT se solicita también 
-- la columna dp.nombre_producto. Como hay múltiples productos distintos dentro de una misma región, el motor no sabe qué producto elegir 
-- para representarlos a todos en esa única fila devuelta, por lo que aborta la consulta por seguridad.

SELECT 
    ds.region, 
    dp.nombre_producto, 
    SUM(fv.monto_neto_venta) AS ventas_totales
FROM dm_ventas.FACT_VENTAS fv
INNER JOIN dm_ventas.DIM_SUCURSAL ds ON fv.sucursal_sk = ds.sucursal_sk
INNER JOIN dm_ventas.DIM_PRODUCTO dp ON fv.producto_sk = dp.producto_sk
GROUP BY 
    ds.region;