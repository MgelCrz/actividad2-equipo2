# Conclusiones de Negocio y Aprendizaje Técnico

## 1. Hallazgos de Negocio (TecnoNova Retail)
* **Rentabilidad Bruta vs. Rentabilidad Neta Real**: Al evaluar el Top 5 descontando comisiones logísticas, de marketplace y devoluciones (`margen_neto_real - monto_devolucion`), se identificó que varios productos líderes en tiendas físicas reducen significativamente su margen al venderse en canales digitales.
* **Estrategia por Canal**: Se recomienda establecer precios o políticas de inventario diferenciadas para plataformas de marketplace, evitando comercializar ítems de bajo margen neto por estos canales.

## 2. Limitaciones del Análisis
* **Falta de datos de Inventario (`FACT_STOCK`)**: El modelo actual calcula la rentabilidad por venta, pero no cruza los costos de almacenamiento o la rotación de inventarios en anaquel por falta de datos reales del almacén.

## 3. Aprendizaje sobre el uso de la Inteligencia Artificial
* La IA (Gemini Pro 3.1) demostró ser una herramienta eficaz para acelerar la escritura de código SQL estructurado (CTEs, funciones de ventana y generación de DML masivo).
* **Validación Humana Obligatoria**: La IA no identifica por sí sola los problemas de precisión en punto flotante ni los errores conceptuales de multiplicidad (*fan-out*). La supervisión del analista de datos fue imprescindible para estructurar la preagregación y garantizar la integridad matemática del reporte.
