# # <img src="https://img.icons8.com/?size=50&id=81093&format=png&color=000000" align="center"/> SQL Retail Sales Analysis
### Esquema Dimensional y Análisis Avanzado de Ventas en SQL Server

> **EN** · SQL Server project for retail sales analysis of cleaning products (Cloralex, Vanish, Clorox, Blancatel, OxiClean and others) across 6 Mexican regions. Covers full DDL design with FK/PK constraints, SSMS data loading via Import Wizard, 8 data quality validations, and 16 analytical queries using window functions, CTEs, YoY growth, ABC/Pareto classification and product lifecycle status.
>
> **ES** · Proyecto en SQL Server para análisis de ventas retail de productos de limpieza (Cloralex, Vanish, Clorox, Blancatel, OxiClean y otros) en 6 regiones de México. Incluye DDL completo con restricciones FK/PK, carga de datos por SSMS Import Wizard, 8 validaciones de calidad de datos y 16 consultas analíticas con window functions, CTEs, crecimiento YoY, clasificación ABC/Pareto y estatus del ciclo de vida de productos.

---

## <img src="https://img.icons8.com/?size=40&id=80717&format=png&color=000000" align="center"/> Dimensional Model / Modelo Dimensional

Hibrid dimensional relational model with 1 fact table and 4 dimension tables, implementing partial star and snowflake patterns.

Modelo relacional dimensional híbrido con 1 tabla de hechos y 4 tablas de dimensión, implementando patrones parciales de esquema estrella y copo de nieve.

### Tables / Tablas

| Table | Type | Rows | PK | Description |
|---|---|---|---|---|
| `DIM_CATEGORY` | Dimension | 5 | `ID_CATEGORY` | Product category catalog |
| `DIM_CALENDAR` | Dimension | 156 | `WEEK` (WW-YY format) | Time dimension: weekly granularity |
| `DIM_PRODUCT` | Dimension | 505 | `ID_PRODUCT` (IDENTITY) | Product master with brand, format, attributes |
| `DIM_SEGMENT` | Dimension | 53 | `ID_SEGMENT` (IDENTITY) | Market segments by category, format and attributes |
| `FACT_SALES` | Fact | 122,002 | `ID_SALE` (IDENTITY) | Weekly sales by item and region |

### Defined FK Constraints / Restricciones FK Definidas

| Constraint | From | To | Type |
|---|---|---|---|
| `FK_SALES_CALENDAR` | `FACT_SALES.WEEK` | `DIM_CALENDAR.WEEK` | Enforced FK |
| `FK_PRODUCT_CATEGORY` | `DIM_PRODUCT.CATEGORY` | `DIM_CATEGORY.ID_CATEGORY` | Enforced FK |
| `FK_SEGMENT_CATEGORY` | `DIM_SEGMENT.CATEGORY` | `DIM_CATEGORY.ID_CATEGORY` | Enforced FK |
| `FACT_SALES → DIM_PRODUCT` | `FACT_SALES.ITEM_CODE` | `DIM_PRODUCT.ITEM` | Query JOIN only |
| `FACT_SALES → DIM_SEGMENT` | Multi-column match | `DIM_SEGMENT` attrs | Query JOIN only |

### Data Load Order / Orden de Carga
```
Respects FK constraints:
DIM_CATEGORY → DIM_CALENDAR → DIM_PRODUCT → DIM_SEGMENT → FACT_SALES
```

### Entity Relationship Diagram / Diagrama de Relaciones

```
                DIM_CATEGORY
          │                      │
          │ FK_PRODUCT_CATEGORY  │ FK_SEGMENT_CATEGORY
          │                      │
     DIM_PRODUCT             DIM_SEGMENT
          │                      │
          │──── multi-column attr match (no FK)
          │ 
          │ JOIN via ITEM = ITEM_CODE (no FK)
          │                     
     FACT_SALES ── FK_SALES_CALENDAR ──> DIM_CALENDAR
```

---

## <img src="https://img.icons8.com/?size=40&id=Ihw7rsNxtanQ&format=png&color=000000" align="center"/> Query Index / Índice de Consultas

### Step 4 · Data Quality / Calidad de Datos

| # | Query | Technique | Finding |
|---|---|---|---|
| 4.1 | Record count per table | `UNION ALL + COUNT(*)` | 122,002 fact rows confirmed |
| 4.2 | Top 5 rows per table | `SELECT TOP 5` | Structure validated |
| 4.3 | Calendar date range | `MIN / MAX / COUNT DISTINCT` | 2021-01-10 to 2024-01-01 · 3 years |
| 4.4 | Last date with sales | `JOIN + MAX(DATE) + WHERE > 0` | Last sale: 2023-07-17 |
| 4.5 | NULLs in FACT_SALES | `SUM(CASE WHEN IS NULL)` | 0 nulls in all metric columns |
| 4.6 | Spaces in ITEM (DIM_PRODUCT) | `LEN vs LEN(TRIM)` | All 505 items clean |
| 4.7 | Spaces in ITEM_CODE (FACT_SALES) | `LEN <> LEN(TRIM)` | No spaces detected |
| 4.8 | Products without sales | `NOT EXISTS subquery` | 155 orphan products |

### Step 5 · Advanced Analysis / Análisis Avanzado

| # | Query | Technique | Key Insight |
|---|---|---|---|
| 5.1 | Sales by region | `GROUP BY + CAST + ROUND` | México = $5.5M (50% del total) |
| 5.2 | Monthly trend | `JOIN DIM_CALENDAR + GROUP BY year/month` | 19 months of data visualized |
| 5.3 | Weekly granularity | `JOIN DIM_CALENDAR + GROUP BY week` | 80 weeks, peak detection |
| 5.4 | Top 10 products by value | `TOP 10 + LEFT JOIN + ORDER BY` | Cloralex 3.75L leads at $1.14M |
| 5.5 | Sales by category | `Multi-table JOIN + GROUP BY` | FABRIC TREATMENT is the only category with registered products |
| 5.6 | Sales by segment | `JOIN with multi-column ISNULL match` | BLEACH LIQUIDO = $48.4M |
| 5.7 | Brand ranking | `DENSE_RANK() OVER (ORDER BY SUM)` | Cloralex #1, Vanish #2 |
| 5.8 | Weekly avg by brand & year | `AVG + COUNT DISTINCT WEEK` | Blancatel highest avg/week in 2022 |
| 5.9 | YoY by region | `GROUP BY year + region` | All regions 2022 vs 2023 comparison |
| 5.10 | Brand market share | `SUM() OVER () window` | Cloralex, Vanish and Clorox = 70.9% |
| 5.11 | Monthly YoY growth | `CTE + LAG() OVER (PARTITION BY brand, month)` | Puro Sol +50.57% in Feb 2023 |
| 5.12 | Semester YoY | `CTE + LAG() + NULLIF` | Dr.Beckmann +29.05% Jan–Jun 2023 |
| 5.13 | Product lifecycle status | `2 nested CTEs + CASE` | 3 statuses: active / inactive / never sold |
| 5.14 | Top 3 brands per region | `CTE + RANK() OVER (PARTITION BY region)` | Cloralex #1 in all 7 regions |
| 5.15 | ABC classification | `2 CTEs + SUM() acumulado + CASE` | Pareto: top items = 80% of revenue |
| 5.16 | YoY + ABC by brand | `DECLARE + 3 CTEs + RANK()` | Vanish: A-Crítico, +12.57% growth |

---

## <img src="https://img.icons8.com/?size=40&id=PhymLYNNjf3I&format=png&color=000000" align="center"/> Repository Structure / Estructura del Repositorio

```
sql-retail-sales-analysis/
├── sql/
│   └── sql_retail_sales_analysis.sql    ← DDL + 16 queries
├── README.md
└── requirements.txt
```

---

*Project developed as part of the Data Scientist Certificate · 
Proyecto desarrollado como parte del certificado Científico de Datos — EBAC (2026)* <img src="https://img.icons8.com/?size=35&id=FgMs84V9yrMV&format=png&color=000000" align="center"/>
