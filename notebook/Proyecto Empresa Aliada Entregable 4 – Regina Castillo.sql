
/* ========================================================================
   PROYECTO: Análisis de Ventas - Empresa Aliada
   Programa: Profesión Científico de Datos v2 — EBAC
   Autora:   Regina Castillo
   Fecha:    Junio 2026
   ========================================================================
   Descripción del modelo dimensional:
     DIM_CATEGORY → catálogo de categorías de producto
     DIM_CALENDAR → dimensión de tiempo
     DIM_PRODUCT  → catálogo de productos
     DIM_SEGMENT  → segmentos por categoría/atributos/formato
     FACT_SALES   → tabla de hechos con ventas semanales por ítem y región
   ======================================================================== */


-- ========================================================================
-- PASO 1: CREAR Y SELECCIONAR LA BASE DE DATOS
-- ========================================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DB_VENTAS_EBAC')
BEGIN
CREATE DATABASE DB_VENTAS_EBAC;
END
GO
USE DB_VENTAS_EBAC;
GO

-- ========================================================================
-- PASO 2: CREAR TABLAS DIMENSIONALES
-- ========================================================================

-- ---------------------------------------------------------------
-- 2.1 DIM_CATEGORY
-- ---------------------------------------------------------------

CREATE TABLE dbo.DIM_CATEGORY (
ID_CATEGORY INT NOT NULL,
CATEGORY NVARCHAR(100) NOT NULL,
CONSTRAINT PK_DIM_CATEGORY PRIMARY KEY (ID_CATEGORY)
)

-- ---------------------------------------------------------------
-- 2.2 DIM_CALENDAR
-- ---------------------------------------------------------------
CREATE TABLE dbo.DIM_CALENDAR (
WEEK NVARCHAR(10) NOT NULL, -- formato 'WW-YY'
YEAR INT NOT NULL,
MONTH INT NOT NULL,
WEEK_NUMBER INT NOT NULL,
DATE DATE NOT NULL,
CONSTRAINT PK_DIM_CALENDAR PRIMARY KEY (WEEK)
)

-- ---------------------------------------------------------------
-- 2.3 DIM_PRODUCT
-- ---------------------------------------------------------------

CREATE TABLE dbo.DIM_PRODUCT (
ID_PRODUCT INT NOT NULL IDENTITY(1,1),
MANUFACTURER NVARCHAR(100) NULL,
BRAND NVARCHAR(100) NULL,
ITEM NVARCHAR(100) NOT NULL,
ITEM_DESCRIPTION NVARCHAR(255) NULL,
CATEGORY INT NULL,
FORMAT NVARCHAR(100) NULL,
ATTR1 NVARCHAR(100) NULL,
ATTR2 NVARCHAR(100) NULL,
ATTR3 NVARCHAR(100) NULL,
CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (ID_PRODUCT),
CONSTRAINT FK_PRODUCT_CATEGORY
FOREIGN KEY (CATEGORY) REFERENCES dbo.DIM_CATEGORY(ID_CATEGORY)
)

-- ---------------------------------------------------------------
-- 2.4 DIM_SEGMENT
-- ---------------------------------------------------------------

CREATE TABLE dbo.DIM_SEGMENT (
ID_SEGMENT INT NOT NULL IDENTITY(1,1),
CATEGORY INT NULL,
ATTR1 NVARCHAR(100) NULL,
ATTR2 NVARCHAR(100) NULL,
ATTR3 NVARCHAR(100) NULL,
FORMAT NVARCHAR(100) NULL,
SEGMENT NVARCHAR(100) NULL,
CONSTRAINT PK_DIM_SEGMENT PRIMARY KEY (ID_SEGMENT),
CONSTRAINT FK_SEGMENT_CATEGORY
FOREIGN KEY (CATEGORY) REFERENCES dbo.DIM_CATEGORY(ID_CATEGORY)
)

-- ---------------------------------------------------------------
-- 2.5 FACT_SALES
-- ---------------------------------------------------------------

CREATE TABLE dbo.FACT_SALES (
ID_SALE INT NOT NULL IDENTITY(1,1),
WEEK NVARCHAR(10) NOT NULL,
ITEM_CODE NVARCHAR(50) NOT NULL,
TOTAL_UNIT_SALES DECIMAL(18,3) NULL,
TOTAL_VALUE_SALES DECIMAL(18,3) NULL,
TOTAL_UNIT_AVG_WEEKLY_SALES DECIMAL(18,3) NULL,
REGION NVARCHAR(100) NULL,
CONSTRAINT PK_FACT_SALES PRIMARY KEY (ID_SALE),
CONSTRAINT FK_SALES_CALENDAR
FOREIGN KEY (WEEK) REFERENCES dbo.DIM_CALENDAR(WEEK)
)

-- ========================================================================
-- PASO 3: CARGA DE DATOS (Import Wizard / BULK INSERT)
-- ========================================================================

--  3.1 Clic derecho sobre DB_VENTAS_EBAC → Tasks → Import Data
--  3.2 Para archivos .xlsx: usar origen "Microsoft Excel"
--  3.3 Para archivos .csv:  usar origen "Flat File Source"
--  3.4 Mapear columnas a las tablas creadas arriba
--  3.5 Orden de carga para no violar las FK: 
--      DIM_CATEGORY → DIM_CALENDAR → DIM_PRODUCT → DIM_SEGMENT → FACT_SALES

-- ========================================================================
-- PASO 4: CONSULTAS BÁSICAS — VERIFICACIÓN DE CARGA
-- ========================================================================

-- 4.1 Conteo de registros por tabla
SELECT 'DIM_CATEGORY' AS TABLA, COUNT(*) AS TOTAL_REGISTROS FROM dbo.DIM_CATEGORY
UNION ALL
SELECT 'DIM_CALENDAR', COUNT(*) FROM dbo.DIM_CALENDAR
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM dbo.DIM_PRODUCT
UNION ALL
SELECT 'DIM_SEGMENT', COUNT(*) FROM dbo.DIM_SEGMENT
UNION ALL
SELECT 'FACT_SALES', COUNT(*) FROM dbo.FACT_SALES

-- 4.2 Vista de las primeras 5 filas de cada tabla
SELECT TOP 5 * FROM dbo.DIM_CATEGORY
SELECT TOP 5 * FROM dbo.DIM_CALENDAR
SELECT TOP 5 * FROM dbo.DIM_PRODUCT
SELECT TOP 5 * FROM dbo.DIM_SEGMENT
SELECT TOP 5 * FROM dbo.FACT_SALES

-- 4.3 Rango temporal de los datos en calendario
SELECT MIN(DATE) AS PRIMERA_FECHA,
       MAX(DATE) AS ULTIMA_FECHA,
       COUNT(DISTINCT YEAR) AS AÑOS_DISTINTOS
FROM dbo.DIM_CALENDAR

-- 4.4 Última fecha con venta
SELECT MAX(cal.DATE) AS ULTIMA_VENTA
FROM dbo.FACT_SALES fs
    JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
WHERE fs.TOTAL_UNIT_SALES > 0

-- 4.5 Nulos en FACT_SALES
SELECT
    SUM(CASE WHEN TOTAL_UNIT_SALES IS NULL THEN 1 ELSE 0 END) AS NULL_UNITS,
    SUM(CASE WHEN TOTAL_VALUE_SALES IS NULL THEN 1 ELSE 0 END) AS NULL_VALUE,
    SUM(CASE WHEN TOTAL_UNIT_AVG_WEEKLY_SALES IS NULL THEN 1 ELSE 0 END) AS NULL_AVG
FROM dbo.FACT_SALES

-- 4.6 Verificar que no hayan espacios en ITEM de DIM_PRODUCT
SELECT ITEM,
LEN(ITEM) AS LEN_ORIGINAL,
LEN(TRIM(ITEM)) AS LEN_TRIM,
CASE WHEN LEN(ITEM) = LEN(TRIM(ITEM))
THEN 'OK' ELSE 'TIENE ESPACIOS' END AS STATUS
FROM dbo.DIM_PRODUCT

-- 4.7 Mostrar si hay espacios en ITEM_CODE de FACT_SALES
SELECT
    ITEM_CODE,
    LEN(ITEM_CODE) AS LEN_ORIGINAL,
    LEN(TRIM(ITEM_CODE)) AS LEN_TRIM
FROM dbo.FACT_SALES
WHERE LEN(ITEM_CODE) <> LEN(TRIM(ITEM_CODE))

-- 4.8 Productos en DIM_PRODUCT sin ventas en FACT_SALES
SELECT p.ITEM
FROM DIM_PRODUCT p
WHERE NOT EXISTS (
    SELECT 1
    FROM FACT_SALES fs
    WHERE fs.ITEM_CODE = p.ITEM
)

-- ========================================================================
-- PASO 5: CONSULTAS AVANZADAS — ANÁLISIS DE VENTAS
-- ========================================================================

-- ---------------------------------------------------------------
-- 5.1 VENTAS TOTALES POR REGIÓN
--     Insight: qué región genera mayor valor y volumen de ventas
-- ---------------------------------------------------------------
SELECT
    fs.REGION,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL,
    CAST(ROUND(SUM(fs.TOTAL_UNIT_SALES) / COUNT(DISTINCT fs.WEEK), 2) AS DECIMAL(10,2)) AS UNIDADES_PROM_SEMANAL,
    CAST(ROUND(SUM(fs.TOTAL_VALUE_SALES) / COUNT(DISTINCT fs.WEEK), 2) AS DECIMAL(10,2)) AS VALOR_PROM_SEMANAL
FROM dbo.FACT_SALES fs
GROUP BY fs.REGION
ORDER BY VALOR_TOTAL DESC;

-- ---------------------------------------------------------------
-- 5.2 VENTAS POR AÑO Y MES (TENDENCIA TEMPORAL)
--     Insight: evolución de ventas a lo largo del tiempo
-- ---------------------------------------------------------------
SELECT
    cal.YEAR AS AÑO,
    cal.MONTH AS MES,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES fs
    JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
GROUP BY cal.YEAR, cal.MONTH
ORDER BY cal.YEAR, cal.MONTH;

-- ---------------------------------------------------------------
-- 5.3 VENTAS POR SEMANA (GRANULARIDAD SEMANAL)
--     Insight: semanas pico de ventas
-- ---------------------------------------------------------------
SELECT
    fs.WEEK,
    cal.DATE,
    cal.YEAR,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES   fs
    JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
GROUP BY fs.WEEK, cal.DATE, cal.YEAR
ORDER BY cal.DATE;

-- ---------------------------------------------------------------
-- 5.4 TOP 10 PRODUCTOS MÁS VENDIDOS (POR VALOR)
--     Insight: items con mayor contribución al revenue
-- ---------------------------------------------------------------

SELECT TOP 10
    fs.ITEM_CODE,
    p.BRAND,
    p.ITEM_DESCRIPTION,
    SUM(fs.TOTAL_UNIT_SALES)  AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES   fs
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
GROUP BY fs.ITEM_CODE, p.BRAND, p.ITEM_DESCRIPTION
ORDER BY VALOR_TOTAL DESC;

-- ---------------------------------------------------------------
-- 5.5 VENTAS POR CATEGORÍA
--     Insight: qué categoría de producto domina las ventas
-- ---------------------------------------------------------------

SELECT
    cat.ID_CATEGORY,
    cat.CATEGORY,
    COUNT(DISTINCT fs.ITEM_CODE) AS PRODUCTOS_DISTINTOS,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES fs
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    LEFT JOIN dbo.DIM_CATEGORY cat ON p.CATEGORY = cat.ID_CATEGORY
GROUP BY cat.ID_CATEGORY, cat.CATEGORY
ORDER BY VALOR_TOTAL DESC;

-- ---------------------------------------------------------------
-- 5.6 VENTAS POR SEGMENTO
--     Insight: segmentos con mayor contribución de ventas
-- ---------------------------------------------------------------

SELECT
    seg.SEGMENT,
    seg.FORMAT,
    SUM(fs.TOTAL_UNIT_SALES)  AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES fs
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    LEFT JOIN dbo.DIM_SEGMENT seg ON p.CATEGORY = seg.CATEGORY
        AND ISNULL(p.ATTR1,'') = ISNULL(seg.ATTR1,'')
        AND ISNULL(p.ATTR2,'') = ISNULL(seg.ATTR2,'')
        AND ISNULL(p.FORMAT,'') = ISNULL(seg.FORMAT,'')
GROUP BY seg.SEGMENT, seg.FORMAT
ORDER BY VALOR_TOTAL DESC;

-- ---------------------------------------------------------------
-- 5.7 RANKING DE MARCAS POR VALOR DE VENTAS
--     Insight: marcas más valiosas del portafolio
-- ---------------------------------------------------------------

SELECT
    p.BRAND AS MARCA,
    COUNT(DISTINCT fs.ITEM_CODE) AS PRODUCTOS_DISTINTOS,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL,
    DENSE_RANK() OVER (ORDER BY SUM(fs.TOTAL_VALUE_SALES) DESC) AS RANKING_VALOR_MARCA
FROM dbo.FACT_SALES fs
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
WHERE p.BRAND IS NOT NULL
GROUP BY p.BRAND
ORDER BY VALOR_TOTAL DESC

-- ---------------------------------------------------------------
-- 5.8 PROMEDIO SEMANAL DE VENTAS POR MARCA Y AÑO
--     Insight: estacionalidad y tendencias por marca
-- ---------------------------------------------------------------

SELECT
    cal.YEAR AS AÑO,
    p.BRAND AS MARCA,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL,
    CAST(ROUND(AVG(fs.TOTAL_UNIT_SALES), 2) AS DECIMAL(10,2)) AS PROM_UNIDADES_SEMANA,
    CAST(ROUND(AVG(fs.TOTAL_VALUE_SALES), 2) AS DECIMAL(10,2)) AS PROM_VALOR_SEMANA,
    COUNT(DISTINCT fs.WEEK) AS SEMANAS_CON_VENTA
FROM dbo.FACT_SALES fs
    JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
GROUP BY cal.YEAR, p.BRAND
ORDER BY cal.YEAR, PROM_VALOR_SEMANA DESC

-- ---------------------------------------------------------------
-- 5.9 VENTAS POR AÑO Y REGIÓN
--     Insight: crecimiento regional año sobre año (YoY)
-- ---------------------------------------------------------------

SELECT
    cal.YEAR AS AÑO,
    fs.REGION,
    SUM(fs.TOTAL_UNIT_SALES) AS UNIDADES_TOTALES,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
FROM dbo.FACT_SALES   fs
    JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
GROUP BY cal.YEAR, fs.REGION
ORDER BY cal.YEAR, VALOR_TOTAL DESC;

-- ---------------------------------------------------------------
-- 5.10 VENTAS POR MARCA (PARTICIPACIÓN GLOBAL)
--     Insight: qué marcas concentran mayor % de revenue
-- ---------------------------------------------------------------

SELECT
    p.BRAND AS MARCA,
    SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL,
    SUM(SUM(fs.TOTAL_VALUE_SALES)) OVER () AS REVENUE_GLOBAL,
    CAST(100.0 * SUM(fs.TOTAL_VALUE_SALES) / SUM(SUM(fs.TOTAL_VALUE_SALES)) OVER () AS DECIMAL(5,2)) AS PCT_PARTICIPACION
FROM dbo.FACT_SALES fs
    LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
WHERE p.BRAND IS NOT NULL
GROUP BY p.BRAND
ORDER BY PCT_PARTICIPACION DESC;

-- ---------------------------------------------------------------
-- 5.11 CRECIMIENTO MENSUAL POR MARCA
--     Insight: comparación mes a mes contra el año anterior (YoY)
-- ---------------------------------------------------------------
WITH ventas_mensuales AS ( -- Common Table Expression: calcula ventas por marca, año y mes
    SELECT
        p.BRAND AS MARCA,
        cal.YEAR AS AÑO,
        cal.MONTH AS MES,
        SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
    FROM dbo.FACT_SALES fs
        JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
        LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    WHERE p.BRAND IS NOT NULL
    GROUP BY p.BRAND, cal.YEAR, cal.MONTH
)
SELECT *
FROM (
    SELECT
        MARCA, AÑO, MES, VALOR_TOTAL,
        LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA, MES ORDER BY AÑO) AS VALOR_AÑO_ANTERIOR,
        CAST(100.0 * (VALOR_TOTAL - LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA, MES ORDER BY AÑO)) /
            NULLIF(LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA, MES ORDER BY AÑO), 0) AS DECIMAL(6,2)) AS CRECIMIENTO_PCT
    FROM ventas_mensuales
) c
WHERE AÑO = 2023 AND MES BETWEEN 1 AND 6
ORDER BY AÑO, MES, CRECIMIENTO_PCT DESC;

-- ---------------------------------------------------------------
-- 5.12 VENTAS SEMESTRALES POR MARCA
--     Insight: crecimiento acumulado enero–junio vs año anterior
-- ---------------------------------------------------------------
WITH ventas_semestre AS (
    SELECT
        p.BRAND AS MARCA,
        cal.YEAR AS AÑO,
        SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
    FROM dbo.FACT_SALES fs
        JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
        LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    WHERE p.BRAND IS NOT NULL
        AND cal.MONTH BETWEEN 1 AND 6
    GROUP BY p.BRAND, cal.YEAR
)
SELECT *
FROM (
    SELECT
        MARCA, AÑO, VALOR_TOTAL,
        LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA ORDER BY AÑO) AS VALOR_AÑO_ANTERIOR,
        CAST(100.0 * (VALOR_TOTAL - LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA ORDER BY AÑO)) /
            NULLIF(LAG(VALOR_TOTAL) OVER (PARTITION BY MARCA ORDER BY AÑO), 0) AS DECIMAL(6,2)) AS CRECIMIENTO_PCT
    FROM ventas_semestre
) c
WHERE AÑO = 2023
ORDER BY CRECIMIENTO_PCT DESC;

-- ---------------------------------------------------------------
-- 5.13 STATUS DE PRODUCTOS (ÚLTIMAS 8 SEMANAS)
--     Insight: identificar productos activos, inactivos o sin venta
-- ---------------------------------------------------------------
WITH ultimas_semanas AS (
    SELECT WEEK
    FROM dbo.DIM_CALENDAR
    WHERE DATE >= DATEADD(WEEK, -8,
        (SELECT MAX(cal.DATE)
         FROM dbo.FACT_SALES fs
         JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
         WHERE fs.TOTAL_UNIT_SALES > 0))
),
ultima_venta AS (
    SELECT
        p.ITEM,
        MAX(cal.WEEK) AS ULTIMA_SEMANA_CON_VENTA
    FROM dbo.FACT_SALES fs
        JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
        JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    WHERE fs.TOTAL_UNIT_SALES > 0
    GROUP BY p.ITEM
)
SELECT
    p.ITEM,
    p.BRAND,
    p.ITEM_DESCRIPTION,
    p.FORMAT,
    u.ULTIMA_SEMANA_CON_VENTA,
    CASE 
        WHEN u.ULTIMA_SEMANA_CON_VENTA IS NULL 
            THEN 'NUNCA HA TENIDO VENTA'
        WHEN u.ULTIMA_SEMANA_CON_VENTA IN (SELECT WEEK FROM ultimas_semanas)
            THEN 'CON VENTA RECIENTE'
        ELSE 'SIN VENTA ULTIMAS 8 SEMANAS'
    END AS STATUS
FROM dbo.DIM_PRODUCT p
    LEFT JOIN ultima_venta u ON p.ITEM = u.ITEM
ORDER BY STATUS, p.BRAND, p.ITEM;

-- ---------------------------------------------------------------
-- 5.14 TOP 3 MARCAS POR REGIÓN
--     Insight: líderes regionales en participación de ventas
-- ---------------------------------------------------------------

WITH ranking_regional AS (
    SELECT
        fs.REGION,
        p.BRAND AS MARCA,
        SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL,
        RANK() OVER (PARTITION BY fs.REGION ORDER BY SUM(fs.TOTAL_VALUE_SALES) DESC) AS RANKING_EN_REGION
    FROM dbo.FACT_SALES fs
        LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    WHERE p.BRAND IS NOT NULL
    GROUP BY fs.REGION, p.BRAND
)
SELECT REGION, RANKING_EN_REGION, MARCA, VALOR_TOTAL
FROM ranking_regional
WHERE RANKING_EN_REGION <= 3
ORDER BY REGION, RANKING_EN_REGION;

-- ---------------------------------------------------------------
-- 5.15 CLASIFICACIÓN ABC DE PRODUCTOS
--     Insight: concentración de ventas y criticidad por ítem (analisis de Pareto)
-- ---------------------------------------------------------------
WITH ventas_item AS ( -- Calcula ventas totales por producto
    SELECT
        fs.ITEM_CODE,
        p.BRAND,
        p.ITEM_DESCRIPTION,
        SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
    FROM dbo.FACT_SALES fs
        LEFT JOIN dbo.DIM_PRODUCT p ON p.ITEM = fs.ITEM_CODE
    GROUP BY fs.ITEM_CODE, p.BRAND, p.ITEM_DESCRIPTION
),
con_acumulado AS ( -- Calcula porcentaje acumulado de ventas ordenado
    SELECT
        ITEM_CODE, BRAND, ITEM_DESCRIPTION, VALOR_TOTAL,
    CAST(100.0 * SUM(VALOR_TOTAL)
    OVER (ORDER BY VALOR_TOTAL DESC ROWS UNBOUNDED PRECEDING) / SUM(VALOR_TOTAL) OVER () AS DECIMAL(6,2)) AS PCT_ACUMULADO
    FROM ventas_item
)
SELECT -- Aplica la clasificación ABC
    ITEM_CODE, BRAND, ITEM_DESCRIPTION, VALOR_TOTAL, PCT_ACUMULADO,
    CASE
        WHEN PCT_ACUMULADO <= 80 THEN 'A - CRITICO'
        WHEN PCT_ACUMULADO <= 95 THEN 'B - IMPORTANTE'
        ELSE 'C - MENOR IMPACTO'
    END AS CLASIFICACION_ABC
FROM con_acumulado;

-- ---------------------------------------------------------------
-- 5.16 CRECIMIENTO YOY + CLASIFICACIÓN ABC POR MARCA
--     Insight: desempeño semestral, participación acumulada y ranking
-- ---------------------------------------------------------------
DECLARE @AñoActual INT = 2023;
DECLARE @AñoAnterior INT = 2022;
DECLARE @MesInicio INT = 1;   -- Enero
DECLARE @MesFin INT = 6;      -- Junio

WITH ventas_marca AS ( -- Calcula ventas por marca en ambos años, filtrando el semestre con DECLARE
    SELECT
        p.BRAND, cal.YEAR,
        SUM(fs.TOTAL_VALUE_SALES) AS VALOR_TOTAL
    FROM dbo.FACT_SALES fs
        JOIN dbo.DIM_CALENDAR cal ON fs.WEEK = cal.WEEK
        JOIN dbo.DIM_PRODUCT p ON fs.ITEM_CODE = p.ITEM
    WHERE cal.YEAR IN (@AñoActual, @AñoAnterior)
      AND cal.MONTH BETWEEN @MesInicio AND @MesFin
    GROUP BY p.BRAND, cal.YEAR
),
ventas_yoy AS ( -- Consolida ventas actuales vs anteriores
    SELECT
        BRAND,
        SUM(CASE WHEN YEAR = @AñoActual THEN VALOR_TOTAL END) AS VENTAS_ACTUAL,
        SUM(CASE WHEN YEAR = @AñoAnterior THEN VALOR_TOTAL END) AS VENTAS_ANTERIOR
    FROM ventas_marca
    GROUP BY BRAND
),
con_acumulado AS ( -- Calcula crecimiento YoY acumulado por marca y % acumulado de participación en ventas
    SELECT
        BRAND, VENTAS_ACTUAL, VENTAS_ANTERIOR,
        CAST(100.0 * (VENTAS_ACTUAL - VENTAS_ANTERIOR) / NULLIF(VENTAS_ANTERIOR,0) AS DECIMAL(6,2)) AS CRECIMIENTO_YOY_PCT,
        CAST(100.0 * SUM(VENTAS_ACTUAL) OVER (ORDER BY VENTAS_ACTUAL DESC ROWS UNBOUNDED PRECEDING) /
             SUM(VENTAS_ACTUAL) OVER () AS DECIMAL(6,2)) AS PCT_ACUMULADO
    FROM ventas_yoy
)
SELECT -- Aplica la clasificación ABC
    BRAND, VENTAS_ACTUAL, VENTAS_ANTERIOR, CRECIMIENTO_YOY_PCT, PCT_ACUMULADO,
    CASE
        WHEN PCT_ACUMULADO <= 80 THEN 'A - CRITICO'
        WHEN PCT_ACUMULADO <= 95 THEN 'B - IMPORTANTE'
        ELSE 'C - MENOR IMPACTO'
    END AS CLASIFICACION_ABC,
    RANK() OVER (ORDER BY CRECIMIENTO_YOY_PCT DESC) AS RANK_CRECIMIENTO
FROM con_acumulado
ORDER BY CLASIFICACION_ABC, RANK_CRECIMIENTO;