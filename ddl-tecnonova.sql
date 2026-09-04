{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fnil\fcharset0 Menlo-Regular;}
{\colortbl;\red255\green255\blue255;\red98\green98\blue98;\red16\green16\blue16;\red255\green255\blue255;
\red132\green134\blue255;\red254\green214\blue17;\red83\green209\blue96;}
{\*\expandedcolortbl;;\cssrgb\c45882\c45882\c45882;\cssrgb\c7843\c7843\c7843;\cssrgb\c100000\c100000\c100000;
\cssrgb\c58824\c61569\c100000;\cssrgb\c100000\c85882\c5882;\cssrgb\c37647\c83922\c45098;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\deftab720
\pard\pardeftab720\partightenfactor0

\f0\fs28 \cf2 \cb3 \expnd0\expndtw0\kerning0
-- =============================================================================\cf4 \cb1 \
\cf2 \cb3 -- PROYECTO: DATA MART DE VENTAS Y RENTABILIDAD \'b7 TECNONOVA RETAIL\cf4 \cb1 \
\cf2 \cb3 -- CASO: Caso 2 - Retail TecnoNova (U2)\cf4 \cb1 \
\cf2 \cb3 -- MOTOR OBJETIVO: PostgreSQL 14+ / ANSI SQL\cf4 \cb1 \
\cf2 \cb3 -- Implementaci\'f3n F\'edsica DDL del Esquema Dimensional\cf4 \cb1 \
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\cf2 \cb3 --\cf4 \cb1 \
\cf2 \cb3 -- MEMORIA DE ARQUITECTURA Y DELIMITACI\'d3N DE ALCANCE:\cf4 \cb1 \
\cf2 \cb3 --\cf4 \cb1 \
\cf2 \cb3 -- 1. DELIMITACI\'d3N ESTRICTA DEL ALCANCE (OLAP vs. OLTP):\cf4 \cb1 \
\cf2 \cb3 --    Este script implementa EXCLUSIVAMENTE la capa dimensional (tablas DIM_ y FACT_).\cf4 \cb1 \
\cf2 \cb3 --    Las entidades 'PAGO_VENTA' y 'METODO_PAGO' pertenecen funcionalmente al modelo\cf4 \cb1 \
\cf2 \cb3 --    relacional operacional/transaccional en 3NF (Entregable 2), donde resuelven la \cf4 \cb1 \
\cf2 \cb3 --    Primera Forma Normal (1NF) para apartados y anticipos (Regla #3).\cf4 \cb1 \
\cf2 \cb3 --    En este Data Mart se omiten deliberadamente para prevenir la trampa de abanico \cf4 \cb1 \
\cf2 \cb3 --    (Fan Trap) en el grano de l\'ednea de producto; el seguimiento de saldos y abonos \cf4 \cb1 \
\cf2 \cb3 --    se delega a un Data Mart sat\'e9lite de Tesorer\'eda.\cf4 \cb1 \
\cf2 \cb3 --\cf4 \cb1 \
\cf2 \cb3 -- 2. POL\'cdTICA DE INTEGRIDAD Y CERO NULOS (Zero-NULL Foreign Key Policy):\cf4 \cb1 \
\cf2 \cb3 --    En apego a la metodolog\'eda de Ralph Kimball, se proh\'edbe el uso de NULL en llaves \cf4 \cb1 \
\cf2 \cb3 --    for\'e1neas dentro de las tablas de hechos. Cada una de las 7 dimensiones conformadas \cf4 \cb1 \
\cf2 \cb3 --    incluye un registro centinela con clave sustituta SK = -1 ('No aplica / Desconocido').\cf4 \cb1 \
\cf2 \cb3 --    Esto previene la exclusi\'f3n silenciosa de m\'e9tricas al ejecutar INNER JOINs en \cf4 \cb1 \
\cf2 \cb3 --    herramientas de Business Intelligence (Power BI, Tableau) y resuelve escenarios \cf4 \cb1 \
\cf2 \cb3 --    como ventas de autoservicio digital (sin asesor) o ventas de servicios puros (sin hardware).\cf4 \cb1 \
\cf2 \cb3 --\cf4 \cb1 \
\cf2 \cb3 -- 3. RESOLUCI\'d3N DE REGLAS DE NEGOCIO EN CAPA ETL:\cf4 \cb1 \
\cf2 \cb3 --    - Regla #5 (Precios seg\'fan m\'e9todo de pago y promociones): Las variaciones monetarias \cf4 \cb1 \
\cf2 \cb3 --      por instrumento de cobro (descuentos en efectivo o recargos por tarjeta) se \cf4 \cb1 \
\cf2 \cb3 --      absorben y liquidan durante el pipeline de extracci\'f3n/transformaci\'f3n (ETL) a nivel \cf4 \cb1 \
\cf2 \cb3 --      at\'f3mico dentro de 'precio_unitario' y 'monto_descuento'.\cf4 \cb1 \
\cf2 \cb3 --    - Hito contable de apartados: La tabla FACT_VENTAS \'fanicamente captura ventas \cf4 \cb1 \
\cf2 \cb3 --      liquidadas y formalmente entregadas. Los productos en proceso de abono se auditan \cf4 \cb1 \
\cf2 \cb3 --      en la m\'e9trica 'cantidad_apartada' de FACT_STOCK.\cf4 \cb1 \
\cf2 \cb3 --\cf4 \cb1 \
\cf2 \cb3 -- 4. PREPARACI\'d3N ARQUITECT\'d3NICA DE INVENTARIO:\cf4 \cb1 \
\cf2 \cb3 --    La tabla FACT_STOCK se incluye formalmente bajo el patr\'f3n 'Periodic Snapshot' \cf4 \cb1 \
\cf2 \cb3 --    para viabilizar el c\'e1lculo de rotaci\'f3n financiera requerido por la direcci\'f3n, \cf4 \cb1 \
\cf2 \cb3 --    documentando que recibir\'e1 cargas cuando se integre el sistema de almacenes (WMS).\cf4 \cb1 \
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\
\cf2 \cb3 -- Creaci\'f3n y configuraci\'f3n del esquema l\'f3gico anal\'edtico\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 SCHEMA\cf4  \cf5 IF\cf4  NOT EXISTS dm_ventas\cf2 ;\cf4 \cb1 \
\cf5 \cb3 SET\cf4  search_path \cf5 TO\cf4  dm_ventas\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Limpieza preventiva en orden inverso de dependencias\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS FACT_STOCK \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS FACT_DEVOLUCIONES \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS FACT_VENTAS \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_SERVICIO \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_ASESOR \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_CANAL \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_SUCURSAL \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_CLIENTE \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_PRODUCTO \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\cf5 \cb3 DROP\cf4  \cf5 TABLE\cf4  \cf5 IF\cf4  EXISTS DIM_TIEMPO \cf5 CASCADE\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\cf2 \cb3 -- SECCI\'d3N 1: DIMENSIONES CONFORMADAS (Conformed Dimensions)\cf4 \cb1 \
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.1 DIM_TIEMPO\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un d\'eda calendario.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Desacopla la marca temporal en jerarqu\'edas anal\'edticas para evaluar \cf4 \cb1 \
\cf2 \cb3 -- estacionalidad, comportamiento en fines de semana y festivos.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_TIEMPO \cf2 (\cf4 \cb1 \
\cb3     tiempo_sk       \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     fecha           \cf5 DATE\cf4         NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     dia             \cf5 SMALLINT\cf4     NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     dia_semana      \cf5 VARCHAR\cf2 (\cf6 15\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     mes             \cf5 SMALLINT\cf4     NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     nombre_mes      \cf5 VARCHAR\cf2 (\cf6 15\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     trimestre       \cf5 SMALLINT\cf4     NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     anio            \cf5 SMALLINT\cf4     NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     es_fin_semana   BOOLEAN     NOT NULL \cf5 DEFAULT\cf4  \cf5 FALSE\cf2 ,\cf4 \cb1 \
\cb3     es_festivo      BOOLEAN     NOT NULL \cf5 DEFAULT\cf4  \cf5 FALSE\cf2 ,\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_tiempo_fecha \cf5 UNIQUE\cf4  \cf2 (\cf4 fecha\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_TIEMPO IS \cb1 \
\cb3     \cf7 'Dimensi\'f3n de tiempo conformada. Generada algor\'edtmicamente para an\'e1lisis de series hist\'f3ricas y estacionalidad.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_TIEMPO\cf2 .\cf4 tiempo_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key del calendario. -1 = Fecha no definida o en tr\'e1mite.'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para blindaje ante fechas no identificadas\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_TIEMPO \cf2 (\cf4 tiempo_sk\cf2 ,\cf4  fecha\cf2 ,\cf4  dia\cf2 ,\cf4  dia_semana\cf2 ,\cf4  mes\cf2 ,\cf4  nombre_mes\cf2 ,\cf4  trimestre\cf2 ,\cf4  anio\cf2 ,\cf4  es_fin_semana\cf2 ,\cf4  es_festivo\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf5 DATE\cf4  \cf7 '1900-01-01'\cf2 ,\cf4  \cf6 1\cf2 ,\cf4  \cf7 'No Definido'\cf2 ,\cf4  \cf6 1\cf2 ,\cf4  \cf7 'No Definido'\cf2 ,\cf4  \cf6 1\cf2 ,\cf4  \cf6 1900\cf2 ,\cf4  \cf5 FALSE\cf2 ,\cf4  \cf5 FALSE\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.2 DIM_PRODUCTO\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un art\'edculo o SKU del cat\'e1logo de hardware.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Permite analizar la rentabilidad por marca, modelo y categor\'eda. \cf4 \cb1 \
\cf2 \cb3 -- El atributo 'requiere_serie' implementa formalmente la Regla de Negocio #2.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_PRODUCTO \cf2 (\cf4 \cb1 \
\cb3     producto_sk     \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     producto_id     \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4   NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural en sistema transaccional\cf4 \cb1 \
\cb3     sku             \cf5 VARCHAR\cf2 (\cf6 30\cf2 )\cf4   NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     nombre_producto \cf5 VARCHAR\cf2 (\cf6 150\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     marca           \cf5 VARCHAR\cf2 (\cf6 60\cf2 ),\cf4 \cb1 \
\cb3     categoria       \cf5 VARCHAR\cf2 (\cf6 60\cf2 ),\cf4 \cb1 \
\cb3     modelo          \cf5 VARCHAR\cf2 (\cf6 60\cf2 ),\cf4 \cb1 \
\cb3     costo_estandar  \cf5 NUMERIC\cf2 (\cf6 12\cf2 ,\cf6 2\cf2 )\cf4  \cf5 CHECK\cf4  \cf2 (\cf4 costo_estandar >= \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     requiere_serie  BOOLEAN      NOT NULL \cf5 DEFAULT\cf4  \cf5 FALSE\cf2 ,\cf4  \cf2 -- Regla #2: Control de series\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_producto_id \cf5 UNIQUE\cf4  \cf2 (\cf4 producto_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_PRODUCTO IS \cb1 \
\cb3     \cf7 'Cat\'e1logo maestro de hardware. Responde a ventas, m\'e1rgenes brutos y mermas por marca, modelo y categor\'eda.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_PRODUCTO\cf2 .\cf4 producto_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Transacci\'f3n de servicio puro o p\'f3liza sin hardware.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_PRODUCTO\cf2 .\cf4 requiere_serie IS \cb1 \
\cb3     \cf7 'Bandera operativa para hardware delicado que exige n\'famero de serie unitario (Regla #2).'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para ventas exclusivas de servicios intangibles\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_PRODUCTO \cf2 (\cf4 producto_sk\cf2 ,\cf4  producto_id\cf2 ,\cf4  sku\cf2 ,\cf4  nombre_producto\cf2 ,\cf4  marca\cf2 ,\cf4  categoria\cf2 ,\cf4  modelo\cf2 ,\cf4  costo_estandar\cf2 ,\cf4  requiere_serie\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'Sin Producto (Rengl\'f3n de Servicio Puro)'\cf2 ,\cf4  \cf7 'No Aplica'\cf2 ,\cf4  \cf7 'Servicios'\cf2 ,\cf4  \cf7 'No Aplica'\cf2 ,\cf4  \cf6 0.00\cf2 ,\cf4  \cf5 FALSE\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.3 DIM_CLIENTE\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un cliente registrado o persona jur\'eddica.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Segmenta el mercado entre consumidor final y empresas. \cf4 \cb1 \
\cf2 \cb3 -- El atributo 'condiciones_credito' modela el supuesto de la Regla #8 (B2B).\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_CLIENTE \cf2 (\cf4 \cb1 \
\cb3     cliente_sk          \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     cliente_id          \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4   NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural\cf4 \cb1 \
\cb3     nombre_cliente      \cf5 VARCHAR\cf2 (\cf6 150\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     tipo_cliente        \cf5 VARCHAR\cf2 (\cf6 30\cf2 ),\cf4            \cf2 -- Consumidor Final, Estudiante, Empresa\cf4 \cb1 \
\cb3     ciudad              \cf5 VARCHAR\cf2 (\cf6 80\cf2 ),\cf4 \cb1 \
\cb3     segmento            \cf5 VARCHAR\cf2 (\cf6 40\cf2 ),\cf4            \cf2 -- Retail, Corporativo, Gobierno\cf4 \cb1 \
\cb3     condiciones_credito \cf5 VARCHAR\cf2 (\cf6 100\cf2 ),\cf4           \cf2 -- Regla #8: T\'e9rminos comerciales B2B\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_cliente_id \cf5 UNIQUE\cf4  \cf2 (\cf4 cliente_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_CLIENTE IS \cb1 \
\cb3     \cf7 'Dimensi\'f3n de clientes. Permite contrastar compras minoristas contra pedidos empresariales B2B.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_CLIENTE\cf2 .\cf4 cliente_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Venta de mostrador a consumidor an\'f3nimo / no identificado.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_CLIENTE\cf2 .\cf4 condiciones_credito IS \cb1 \
\cb3     \cf7 'Supuesto de dise\'f1o documentado para soportar plazos y cr\'e9ditos comerciales (Regla #8).'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para clientes gen\'e9ricos de mostrador\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_CLIENTE \cf2 (\cf4 cliente_sk\cf2 ,\cf4  cliente_id\cf2 ,\cf4  nombre_cliente\cf2 ,\cf4  tipo_cliente\cf2 ,\cf4  ciudad\cf2 ,\cf4  segmento\cf2 ,\cf4  condiciones_credito\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'Consumidor Gen\'e9rico / No Identificado'\cf2 ,\cf4  \cf7 'Consumidor Final'\cf2 ,\cf4  \cf7 'Desconocida'\cf2 ,\cf4  \cf7 'Retail'\cf2 ,\cf4  \cf7 'Contado'\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.4 DIM_SUCURSAL\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un punto de venta f\'edsico, almac\'e9n regional o nodo log\'edstico.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Responde a la rotaci\'f3n geogr\'e1fica y compara tiendas vs. centros \cf4 \cb1 \
\cf2 \cb3 -- de distribuci\'f3n (12 tiendas f\'edsicas + 1 Centro de Distribuci\'f3n).\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_SUCURSAL \cf2 (\cf4 \cb1 \
\cb3     sucursal_sk     \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     sucursal_id     \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4   NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural\cf4 \cb1 \
\cb3     nombre_sucursal \cf5 VARCHAR\cf2 (\cf6 100\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     ciudad          \cf5 VARCHAR\cf2 (\cf6 80\cf2 ),\cf4 \cb1 \
\cb3     region          \cf5 VARCHAR\cf2 (\cf6 60\cf2 ),\cf4 \cb1 \
\cb3     tipo_nodo       \cf5 VARCHAR\cf2 (\cf6 30\cf2 ),\cf4            \cf2 -- Tienda F\'edsica, Hub Log\'edstico, Digital\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_sucursal_id \cf5 UNIQUE\cf4  \cf2 (\cf4 sucursal_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_SUCURSAL IS \cb1 \
\cb3     \cf7 'Nodos operativos de TecnoNova. Clasifica puntos de venta f\'edsicos y centros log\'edsticos de despacho.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_SUCURSAL\cf2 .\cf4 sucursal_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Venta digital remota sin adscripci\'f3n a tienda f\'edsica.'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para ventas puramente digitales\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_SUCURSAL \cf2 (\cf4 sucursal_sk\cf2 ,\cf4  sucursal_id\cf2 ,\cf4  nombre_sucursal\cf2 ,\cf4  ciudad\cf2 ,\cf4  region\cf2 ,\cf4  tipo_nodo\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'Sin Sucursal Asignada / Despacho Central Digital'\cf2 ,\cf4  \cf7 'No Aplica'\cf2 ,\cf4  \cf7 'Nacional'\cf2 ,\cf4  \cf7 'Digital'\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.5 DIM_CANAL\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un canal comercial o plataforma de venta.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Habilita el c\'e1lculo y contraste de comisiones de intermediarios \cf4 \cb1 \
\cf2 \cb3 -- digitales (Amazon, MercadoLibre) frente al canal web propio y piso de venta.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_CANAL \cf2 (\cf4 \cb1 \
\cb3     canal_sk              \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     canal_id              \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4  NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural\cf4 \cb1 \
\cb3     canal                 \cf5 VARCHAR\cf2 (\cf6 40\cf2 )\cf4  NOT NULL\cf2 ,\cf4  \cf2 -- Tienda f\'edsica, E-commerce, Marketplace\cf4 \cb1 \
\cb3     plataforma_origen     \cf5 VARCHAR\cf2 (\cf6 60\cf2 ),\cf4           \cf2 -- Amazon, MercadoLibre, Portal Web, Mostrador\cf4 \cb1 \
\cb3     comision_pactada_pct  \cf5 NUMERIC\cf2 (\cf6 5\cf2 ,\cf6 2\cf2 )\cf4  \cf5 CHECK\cf4  \cf2 (\cf4 comision_pactada_pct >= \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_canal_id \cf5 UNIQUE\cf4  \cf2 (\cf4 canal_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_CANAL IS \cb1 \
\cb3     \cf7 'Clasificaci\'f3n omnicanal de TecnoNova y parametrizaci\'f3n de comisiones de intermediarios.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_CANAL\cf2 .\cf4 canal_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Canal de venta no clasificado o desconocido.'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_CANAL \cf2 (\cf4 canal_sk\cf2 ,\cf4  canal_id\cf2 ,\cf4  canal\cf2 ,\cf4  plataforma_origen\cf2 ,\cf4  comision_pactada_pct\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'Canal No Identificado'\cf2 ,\cf4  \cf7 'Desconocido'\cf2 ,\cf4  \cf6 0.00\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.6 DIM_ASESOR\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un ejecutivo de venta o asesor de piso.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: Permite evaluar la productividad y ticket promedio de la fuerza \cf4 \cb1 \
\cf2 \cb3 -- de ventas asistida frente a ventas de autoservicio en plataformas web.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_ASESOR \cf2 (\cf4 \cb1 \
\cb3     asesor_sk     \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     asesor_id     \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4   NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural (n\'f3mina)\cf4 \cb1 \
\cb3     nombre_asesor \cf5 VARCHAR\cf2 (\cf6 150\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     nivel         \cf5 VARCHAR\cf2 (\cf6 30\cf2 ),\cf4            \cf2 -- Junior, Senior, Especialista\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_asesor_id \cf5 UNIQUE\cf4  \cf2 (\cf4 asesor_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_ASESOR IS \cb1 \
\cb3     \cf7 'Fuerza comercial interna. Habilita an\'e1lisis de desempe\'f1o individual y comisiones por venta asistida.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_ASESOR\cf2 .\cf4 asesor_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Venta no asistida / Autoservicio web / Marketplace.'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para ventas sin vendedor\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_ASESOR \cf2 (\cf4 asesor_sk\cf2 ,\cf4  asesor_id\cf2 ,\cf4  nombre_asesor\cf2 ,\cf4  nivel\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'Sin Asesor (Venta Autoservicio / Digital)'\cf2 ,\cf4  \cf7 'No Aplica'\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 1.7 DIM_SERVICIO\cf4 \cb1 \
\cf2 \cb3 -- Grano: Una p\'f3liza de servicio, mantenimiento o extensi\'f3n de garant\'eda.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: A\'edsla el cat\'e1logo de intangibles para calcular el \'edndice de \cf4 \cb1 \
\cf2 \cb3 -- penetraci\'f3n cruzada (Attach Rate) sobre las ventas de hardware.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  DIM_SERVICIO \cf2 (\cf4 \cb1 \
\cb3     servicio_sk     \cf5 INTEGER\cf4  \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\cb3     servicio_id     \cf5 VARCHAR\cf2 (\cf6 20\cf2 )\cf4   NOT NULL\cf2 ,\cf4  \cf2 -- Llave natural\cf4 \cb1 \
\cb3     tipo_servicio   \cf5 VARCHAR\cf2 (\cf6 40\cf2 ),\cf4            \cf2 -- Garant\'eda Extendida, Mantenimiento, Configuraci\'f3n\cf4 \cb1 \
\cb3     nombre_servicio \cf5 VARCHAR\cf2 (\cf6 100\cf2 ),\cf4 \cb1 \
\cb3     tarifa_base     \cf5 NUMERIC\cf2 (\cf6 12\cf2 ,\cf6 2\cf2 )\cf4  \cf5 CHECK\cf4  \cf2 (\cf4 tarifa_base >= \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_dim_servicio_id \cf5 UNIQUE\cf4  \cf2 (\cf4 servicio_id\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  DIM_SERVICIO IS \cb1 \
\cb3     \cf7 'Cat\'e1logo de p\'f3lizas y servicios. Utilizada para monitorear ingresos por garant\'edas extendidas.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  DIM_SERVICIO\cf2 .\cf4 servicio_sk IS \cb1 \
\cb3     \cf7 'Surrogate Key. -1 = Rengl\'f3n de venta de producto f\'edsico puro (sin p\'f3liza de servicio).'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- Registro centinela para ventas de hardware sin servicio\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 INSERT\cf4  \cf5 INTO\cf4  DIM_SERVICIO \cf2 (\cf4 servicio_sk\cf2 ,\cf4  servicio_id\cf2 ,\cf4  tipo_servicio\cf2 ,\cf4  nombre_servicio\cf2 ,\cf4  tarifa_base\cf2 )\cf4 \cb1 \
\cf5 \cb3 VALUES\cf4  \cf2 (\cf4 -\cf6 1\cf2 ,\cf4  \cf7 'N/A'\cf2 ,\cf4  \cf7 'No Aplica'\cf2 ,\cf4  \cf7 'Sin Servicio (Venta de Hardware Puro)'\cf2 ,\cf4  \cf6 0.00\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\cf2 \cb3 -- SECCI\'d3N 2: TABLAS DE HECHOS (Fact Tables)\cf4 \cb1 \
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 2.1 FACT_VENTAS\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un rengl\'f3n o \'edtem individual facturado dentro de una transacci\'f3n liquidada.\cf4 \cb1 \
\cf2 \cb3 -- Llaves de Grano: venta_sk (PK t\'e9cnica) y la pareja (num_ticket, num_linea) UNIQUE.\cf4 \cb1 \
\cf2 \cb3 -- Hito de Realizaci\'f3n: Se carga \'fanicamente cuando la venta ha sido liquidada y entregada.\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  FACT_VENTAS \cf2 (\cf4 \cb1 \
\cb3     \cf2 -- Surrogate key f\'edsica del hecho (optimizaci\'f3n de direccionamiento e indexaci\'f3n en PG)\cf4 \cb1 \
\cb3     venta_sk                    BIGINT \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\
\cb3     \cf2 -- Llaves for\'e1neas a dimensiones conformadas (Garant\'eda de Cero Nulos)\cf4 \cb1 \
\cb3     tiempo_sk                   \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_TIEMPO\cf2 (\cf4 tiempo_sk\cf2 ),\cf4 \cb1 \
\cb3     producto_sk                 \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_PRODUCTO\cf2 (\cf4 producto_sk\cf2 ),\cf4 \cb1 \
\cb3     servicio_sk                 \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_SERVICIO\cf2 (\cf4 servicio_sk\cf2 ),\cf4 \cb1 \
\cb3     cliente_sk                  \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_CLIENTE\cf2 (\cf4 cliente_sk\cf2 ),\cf4 \cb1 \
\cb3     sucursal_sk                 \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_SUCURSAL\cf2 (\cf4 sucursal_sk\cf2 ),\cf4 \cb1 \
\cb3     canal_sk                    \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_CANAL\cf2 (\cf4 canal_sk\cf2 ),\cf4 \cb1 \
\cb3     asesor_sk                   \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_ASESOR\cf2 (\cf4 asesor_sk\cf2 ),\cf4 \cb1 \
\
\cb3     \cf2 -- Dimensiones degeneradas (Atributos de auditor\'eda sin tabla sat\'e9lite)\cf4 \cb1 \
\cb3     num_ticket                  \cf5 VARCHAR\cf2 (\cf6 30\cf2 )\cf4   NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     num_linea                   \cf5 SMALLINT\cf4      NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     numero_serie                \cf5 VARCHAR\cf2 (\cf6 50\cf2 ),\cf4  \cf2 -- Capturado si DIM_PRODUCTO.requiere_serie = TRUE\cf4 \cb1 \
\cb3     lote_compra                 \cf5 VARCHAR\cf2 (\cf6 30\cf2 ),\cf4  \cf2 -- Regla #7: Trazabilidad de costos por lote de compra\cf4 \cb1 \
\cb3     tiene_garantia_extendida    BOOLEAN      NOT NULL \cf5 DEFAULT\cf4  \cf5 FALSE\cf2 ,\cf4  \cf2 -- Flag para c\'e1lculo instant\'e1neo de Attach Rate\cf4 \cb1 \
\
\cb3     \cf2 -- M\'e9tricas cuantitativas almacenadas\cf4 \cb1 \
\cb3     cantidad                    \cf5 SMALLINT\cf4       NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 cantidad > \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     precio_unitario             \cf5 NUMERIC\cf2 (\cf6 12\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 precio_unitario >= \cf6 0\cf2 ),\cf4    \cf2 -- No aditiva\cf4 \cb1 \
\cb3     costo_unitario_real         \cf5 NUMERIC\cf2 (\cf6 12\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 costo_unitario_real >= \cf6 0\cf2 ),\cf4  \cf2 -- No aditiva (Costo real de lote)\cf4 \cb1 \
\cb3     monto_bruto                 \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL\cf2 ,\cf4    \cf2 -- Aditiva: cantidad * precio_unitario\cf4 \cb1 \
\cb3     monto_descuento             \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 DEFAULT\cf4  \cf6 0\cf4  \cf5 CHECK\cf4  \cf2 (\cf4 monto_descuento >= \cf6 0\cf2 ),\cf4  \cf2 -- Aditiva\cf4 \cb1 \
\cb3     monto_neto_venta            \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL\cf2 ,\cf4    \cf2 -- Aditiva: monto_bruto - monto_descuento\cf4 \cb1 \
\cb3     costo_total_real            \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL\cf2 ,\cf4    \cf2 -- Aditiva: cantidad * costo_unitario_real\cf4 \cb1 \
\cb3     margen_bruto                \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL\cf2 ,\cf4    \cf2 -- Aditiva: monto_neto_venta - costo_total_real\cf4 \cb1 \
\cb3     monto_comision_marketplace  \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 DEFAULT\cf4  \cf6 0\cf2 ,\cf4  \cf2 -- Aditiva: Deducci\'f3n contractual de intermediario\cf4 \cb1 \
\cb3     margen_neto_real            \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL\cf2 ,\cf4    \cf2 -- Aditiva: margen_bruto - monto_comision_marketplace\cf4 \cb1 \
\
\cb3     \cf2 -- Restricciones de integridad relacional y consistencia matem\'e1tica\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  uq_fact_ventas_ticket_linea \cf5 UNIQUE\cf4  \cf2 (\cf4 num_ticket\cf2 ,\cf4  num_linea\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  chk_monto_bruto  \cf5 CHECK\cf4  \cf2 (\cf4 monto_bruto = cantidad * precio_unitario\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  chk_monto_neto   \cf5 CHECK\cf4  \cf2 (\cf4 monto_neto_venta = monto_bruto - monto_descuento\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  chk_costo_total  \cf5 CHECK\cf4  \cf2 (\cf4 costo_total_real = cantidad * costo_unitario_real\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  chk_margen_bruto \cf5 CHECK\cf4  \cf2 (\cf4 margen_bruto = monto_neto_venta - costo_total_real\cf2 ),\cf4 \cb1 \
\cb3     \cf5 CONSTRAINT\cf4  chk_margen_neto  \cf5 CHECK\cf4  \cf2 (\cf4 margen_neto_real = margen_bruto - monto_comision_marketplace\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  FACT_VENTAS IS \cb1 \
\cb3     \cf7 'Hecho transaccional principal. Grano at\'f3mico a nivel de rengl\'f3n facturado de venta liquidada y entregada.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_VENTAS\cf2 .\cf4 tiene_garantia_extendida IS \cb1 \
\cb3     \cf7 'Bandera anal\'edtica desnormalizada. Evita auto-joins reflexivos para computar el Attach Rate.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_VENTAS\cf2 .\cf4 costo_unitario_real IS \cb1 \
\cb3     \cf7 'Costo real de adquisici\'f3n del lote vendido (Regla #7), superando costos est\'e1ndar te\'f3ricos.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_VENTAS\cf2 .\cf4 monto_comision_marketplace IS \cb1 \
\cb3     \cf7 'Monto monetario de comisi\'f3n retenido por plataformas digitales de intermediaci\'f3n (Amazon, ML).'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- \'cdndices B-Tree dedicados sobre llaves for\'e1neas para evitar escaneos secuenciales (Full Table Scans)\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_tiempo   \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 tiempo_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_producto \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 producto_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_servicio \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 servicio_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_cliente  \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 cliente_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_sucursal \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 sucursal_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_canal    \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 canal_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_asesor   \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 asesor_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_ventas_garantia \cf5 ON\cf4  FACT_VENTAS \cf5 USING\cf4  BTREE \cf2 (\cf4 tiene_garantia_extendida\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 2.2 FACT_DEVOLUCIONES\cf4 \cb1 \
\cf2 \cb3 -- Grano: Un evento de reclamo, retorno f\'edsico o reembolso procesado para un \'edtem.\cf4 \cb1 \
\cf2 \cb3 -- Trazabilidad: Mantiene acoplamiento at\'f3mico exacto 1:1 con la PK compuesta de \cf4 \cb1 \
\cf2 \cb3 -- FACT_VENTAS a trav\'e9s de (ticket_venta_origen, linea_venta_origen).\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  FACT_DEVOLUCIONES \cf2 (\cf4 \cb1 \
\cb3     devolucion_sk       BIGINT \cf5 GENERATED\cf4  \cf5 BY\cf4  \cf5 DEFAULT\cf4  \cf5 AS\cf4  IDENTITY \cf5 PRIMARY\cf4  \cf5 KEY\cf2 ,\cf4 \cb1 \
\
\cb3     \cf2 -- Llaves for\'e1neas a dimensiones conformadas\cf4 \cb1 \
\cb3     tiempo_sk           \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_TIEMPO\cf2 (\cf4 tiempo_sk\cf2 ),\cf4 \cb1 \
\cb3     producto_sk         \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_PRODUCTO\cf2 (\cf4 producto_sk\cf2 ),\cf4 \cb1 \
\cb3     cliente_sk          \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_CLIENTE\cf2 (\cf4 cliente_sk\cf2 ),\cf4 \cb1 \
\cb3     sucursal_sk         \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_SUCURSAL\cf2 (\cf4 sucursal_sk\cf2 ),\cf4  \cf2 -- Sucursal receptora del reclamo\cf4 \cb1 \
\
\cb3     \cf2 -- Dimensiones degeneradas de control y enlace at\'f3mico\cf4 \cb1 \
\cb3     num_devolucion      \cf5 VARCHAR\cf2 (\cf6 30\cf2 )\cf4   NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     ticket_venta_origen \cf5 VARCHAR\cf2 (\cf6 30\cf2 )\cf4   NOT NULL\cf2 ,\cf4 \cb1 \
\cb3     linea_venta_origen  \cf5 SMALLINT\cf4      NOT NULL \cf5 DEFAULT\cf4  \cf6 1\cf2 ,\cf4  \cf2 -- Cruce exacto con FACT_VENTAS.num_linea\cf4 \cb1 \
\cb3     numero_serie        \cf5 VARCHAR\cf2 (\cf6 50\cf2 ),\cf4 \cb1 \
\cb3     motivo_devolucion   \cf5 VARCHAR\cf2 (\cf6 100\cf2 )\cf4  NOT NULL\cf2 ,\cf4 \cb1 \
\
\cb3     \cf2 -- M\'e9tricas cuantitativas\cf4 \cb1 \
\cb3     cantidad_devuelta   \cf5 SMALLINT\cf4      NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 cantidad_devuelta > \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     monto_devolucion    \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 monto_devolucion >= \cf6 0\cf2 ),\cf4 \cb1 \
\
\cb3     \cf5 CONSTRAINT\cf4  uq_fact_devoluciones_num \cf5 UNIQUE\cf4  \cf2 (\cf4 num_devolucion\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  FACT_DEVOLUCIONES IS \cb1 \
\cb3     \cf7 'Hecho transaccional de posventa. Monitorea retornos f\'edsicos, causas de falla y notas de cr\'e9dito generadas.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_DEVOLUCIONES\cf2 .\cf4 linea_venta_origen IS \cb1 \
\cb3     \cf7 'Identificador del rengl\'f3n original facturado. Garantiza acoplamiento un\'edvoco con FACT_VENTAS(num_ticket, num_linea).'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_DEVOLUCIONES\cf2 .\cf4 sucursal_sk IS \cb1 \
\cb3     \cf7 'Supuesto ETL: Sucursal receptora del hardware devuelto (capturada por POS o heredada de la venta).'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- \'cdndices B-Tree para optimizaci\'f3n de agregaciones de posventa y auditor\'eda cruzada\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_devol_tiempo   \cf5 ON\cf4  FACT_DEVOLUCIONES \cf5 USING\cf4  BTREE \cf2 (\cf4 tiempo_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_devol_producto \cf5 ON\cf4  FACT_DEVOLUCIONES \cf5 USING\cf4  BTREE \cf2 (\cf4 producto_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_devol_cliente  \cf5 ON\cf4  FACT_DEVOLUCIONES \cf5 USING\cf4  BTREE \cf2 (\cf4 cliente_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_devol_sucursal \cf5 ON\cf4  FACT_DEVOLUCIONES \cf5 USING\cf4  BTREE \cf2 (\cf4 sucursal_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_devol_origen   \cf5 ON\cf4  FACT_DEVOLUCIONES \cf5 USING\cf4  BTREE \cf2 (\cf4 ticket_venta_origen\cf2 ,\cf4  linea_venta_origen\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\cf2 \cb3 -- 2.3 FACT_STOCK\cf4 \cb1 \
\cf2 \cb3 -- Grano: Instant\'e1nea peri\'f3dica (Periodic Snapshot) mensual/diaria por tiempo, sucursal y producto.\cf4 \cb1 \
\cf2 \cb3 -- Justificaci\'f3n: PREPARACI\'d3N ARQUITECT\'d3NICA. En el caso oficial no se entreg\'f3 fuente de \cf4 \cb1 \
\cf2 \cb3 -- almac\'e9n, pero se incluye formalmente para sustentar la f\'f3rmula de rotaci\'f3n financiera:\cf4 \cb1 \
\cf2 \cb3 -- Rotaci\'f3n = SUM(FACT_VENTAS[costo_total_real]) / PROMEDIO(FACT_STOCK[costo_inventario_total]).\cf4 \cb1 \
\cf2 \cb3 -- -----------------------------------------------------------------------------\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 TABLE\cf4  FACT_STOCK \cf2 (\cf4 \cb1 \
\cb3     tiempo_sk               \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_TIEMPO\cf2 (\cf4 tiempo_sk\cf2 ),\cf4 \cb1 \
\cb3     sucursal_sk             \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_SUCURSAL\cf2 (\cf4 sucursal_sk\cf2 ),\cf4 \cb1 \
\cb3     producto_sk             \cf5 INTEGER\cf4  NOT NULL \cf5 REFERENCES\cf4  DIM_PRODUCTO\cf2 (\cf4 producto_sk\cf2 ),\cf4 \cb1 \
\
\cb3     \cf2 -- M\'e9tricas semi-aditivas (sumables en productos y tiendas, no sumables en el tiempo)\cf4 \cb1 \
\cb3     cantidad_disponible     \cf5 INTEGER\cf4  NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 cantidad_disponible >= \cf6 0\cf2 ),\cf4 \cb1 \
\cb3     cantidad_apartada       \cf5 INTEGER\cf4  NOT NULL \cf5 DEFAULT\cf4  \cf6 0\cf4  \cf5 CHECK\cf4  \cf2 (\cf4 cantidad_apartada >= \cf6 0\cf2 ),\cf4  \cf2 -- Mercanc\'eda comprometida por apartados (Regla #3)\cf4 \cb1 \
\cb3     costo_inventario_total  \cf5 NUMERIC\cf2 (\cf6 14\cf2 ,\cf6 2\cf2 )\cf4  NOT NULL \cf5 CHECK\cf4  \cf2 (\cf4 costo_inventario_total >= \cf6 0\cf2 ),\cf4  \cf2 -- Existencias valorizadas\cf4 \cb1 \
\
\cb3     \cf5 PRIMARY\cf4  \cf5 KEY\cf4  \cf2 (\cf4 tiempo_sk\cf2 ,\cf4  sucursal_sk\cf2 ,\cf4  producto_sk\cf2 )\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf4 \cb3 COMMENT \cf5 ON\cf4  \cf5 TABLE\cf4  FACT_STOCK IS \cb1 \
\cb3     \cf7 'Estructura preparatoria de Periodic Snapshot. Suministra el inventario promedio indispensable para la rotaci\'f3n.'\cf2 ;\cf4 \cb1 \
\cb3 COMMENT \cf5 ON\cf4  \cf5 COLUMN\cf4  FACT_STOCK\cf2 .\cf4 cantidad_apartada IS \cb1 \
\cb3     \cf7 'Monitorea el inventario retenido por \'f3rdenes con abonos pendientes antes de su entrega definitiva.'\cf2 ;\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- \'cdndices secundarios para acelerar consultas anal\'edticas filtradas por producto o sucursal\cf4 \cb1 \
\pard\pardeftab720\partightenfactor0
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_stock_producto \cf5 ON\cf4  FACT_STOCK \cf5 USING\cf4  BTREE \cf2 (\cf4 producto_sk\cf2 );\cf4 \cb1 \
\cf5 \cb3 CREATE\cf4  \cf5 INDEX\cf4  ix_fact_stock_sucursal \cf5 ON\cf4  FACT_STOCK \cf5 USING\cf4  BTREE \cf2 (\cf4 sucursal_sk\cf2 );\cf4 \cb1 \
\
\pard\pardeftab720\partightenfactor0
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
\cf2 \cb3 -- FIN DEL SCRIPT DDL \'b7 TECNONOVA RETAIL\cf4 \cb1 \
\cf2 \cb3 -- =============================================================================\cf4 \cb1 \
}