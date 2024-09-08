# PREGUNTA 1
¿Cuáles son los cinco principales clientes en términos de participación y volumen de pedidos de maíz de grado uno y grado dos durante los últimos cuatro trimestres?

SELECT TOP 5
    c.nombre_contacto_clientes, 
    p.calidad_producto, 
    SUM(e.volumen_pedidos) AS total_volumen
FROM 
    grupo02.Pedidos e
JOIN 
    grupo02.Clientes c ON e.clientes_id = c.clientes_id
JOIN 
    grupo02.Producto p ON e.producto_id = p.producto_id
WHERE 
    YEAR(e.fecha_pedidos) = 2024
    AND p.calidad_producto IN ('GRADO 1', 'GRADO 2')
GROUP BY 
    c.nombre_contacto_clientes, p.calidad_producto
ORDER BY 
    total_volumen DESC;

# PREGUNTA 2
	
¿Cuál es el volumen total de importación de maíz, tanto de grado uno como de grado dos, en cada trimestre por año?

SELECT 
    t.anio,
    t.trimestre,
    SUM(CASE WHEN i.producto_id = 3 THEN i.volumen_importacion ELSE 0 END) AS "Grado 1",
    SUM(CASE WHEN i.producto_id IN (1, 2) THEN i.volumen_importacion ELSE 0 END) AS "Grado 2"
FROM 
    grupo02.Importacion i
JOIN 
    grupo02.TIEMPO t ON i.fecha_importacion = t.fecha
GROUP BY 
    t.anio,
    t.trimestre
ORDER BY 
    t.anio,
    t.trimestre;

# PREGUNTA 3
	
¿Cuales son los 3 principales puertos de los cuales tenemos mayor volumen de importación del producto grado 1 en el 2024?

declare @sum_importa int
set @sum_importa =
(
        select sum(volumen_importacion) as sum_importa  
        from grupo02.Puertos p
        inner join grupo02.Importacion i on
        i.puertos_id = p.puertos_id 
        inner join grupo02.Producto p2 on
        p2.producto_id = i.producto_id 
        where YEAR(fecha_llegada_importacion) = 2024
        and p2.calidad_producto = 'GRADO 1'
        --group by p.puertos_id, p.nombre_puertos,p2.calidad_producto 
)

select top 3 
                        p.puertos_id, 
                        p.nombre_puertos,
                        p2.calidad_producto , 
                        sum(volumen_importacion) as sum_importa,
                        convert(decimal(10,2), sum(volumen_importacion)/ @sum_importa) as porcentaje_participacion
from grupo02.Puertos p
inner join grupo02.Importacion i on
i.puertos_id = p.puertos_id 
inner join grupo02.Producto p2 on
p2.producto_id = i.producto_id 
where YEAR(fecha_llegada_importacion) = 2024
and p2.calidad_producto = 'GRADO 1'
group by p.puertos_id, p.nombre_puertos,p2.calidad_producto 
order by sum_importa desc;



# PREGUNTA 4
	
¿Cuál es el porcentaje de pedidos de maíz (tanto de grado uno y dos) de cada trimestre por año?


SELECT C.Anio, C.Trimestre, D.calidad_producto,SUM (B.volumen_pedidos) AS Volumen_importacion, CAST (100 * (SUM (B.volumen_pedidos)/SUM(SUM (B.volumen_pedidos)) OVER (PARTITION BY ANIO, TRIMESTRE)) AS decimal (14,2)) AS Participacion
FROM grupo02.Clientes A
INNER JOIN grupo02.Pedidos B
ON A.clientes_id =B.clientes_id
INNER JOIN grupo02.TIEMPO C
ON B.fecha_pedidos =C.Fecha
INNER JOIN grupo02.Producto D
ON B.producto_id =D.producto_id
WHERE C.Fecha between '20230101' and '20231231'
GROUP BY C.Anio, C.Trimestre, D.calidad_producto
ORDER BY C.Anio, C.Trimestre

# PREGUNTA 5
	
¿Cómo varió el porcentaje de participación en el mercado de la empresa ABC en el primer trimestre de 2023 en comparación con el primer trimestre de 2024?

WITH ParticipacionMercado AS (
    SELECT
        YEAR(e.fecha_importacion) AS anio,
        DATEPART(QUARTER, e.fecha_importacion) AS trimestre,
        SUM(e.volumen_importacion) AS volumen_empresa,
        (SUM(e.volumen_importacion) / SUM(g.volumen_mercado)) * 100 AS participacion_empresa
    FROM
        grupo02.Importacion e
    JOIN
        grupo02.Importacion_mercado g ON e.fecha_importacion = g.fecha_mercado
    WHERE
        YEAR(e.fecha_importacion) IN (2023, 2024)
    GROUP BY
        YEAR(e.fecha_importacion), DATEPART(QUARTER, e.fecha_importacion)
),
VariacionPorcentual AS (
    SELECT
        p2023.trimestre,
        p2024.participacion_empresa AS participacion_2024,
        p2023.participacion_empresa AS participacion_2023,
        ((p2024.participacion_empresa - p2023.participacion_empresa) / p2023.participacion_empresa) * 100 AS variacion_porcentual
    FROM
        ParticipacionMercado p2023
    JOIN
        ParticipacionMercado p2024 ON p2023.trimestre = p2024.trimestre AND p2023.anio = 2023 AND p2024.anio = 2024
)
SELECT 
    trimestre,
    participacion_2023,
    participacion_2024,
    variacion_porcentual
FROM 
    VariacionPorcentual;

#PREGUNTA 6
	
¿Cuáles son los 2 proveedores más importantes en términos de volumen de maíz importado en el año 2024 para el maíz grado 01 y maíz grado 02?

SELECT proveedores_id, razon_social, calidad_producto,
volumen_total FROM ( SELECT p.proveedores_id, d.razon_social, pr.calidad_producto,
SUM(i.volumen_importacion) AS volumen_total,
ROW_NUMBER() OVER (PARTITION BY pr.calidad_producto ORDER BY SUM(i.volumen_importacion) DESC) AS rn
FROM [grupo02].[Importacion] i JOIN [grupo02].[Proveedores] p ON i.proveedores_id = p.proveedores_id JOIN [grupo02].[Documento] d ON p.documento_id = d.documento_id
JOIN [grupo02].[Producto] pr ON i.producto_id = pr.producto_id
WHERE pr.calidad_producto IN ('GRADO 1', 'GRADO 2')
AND YEAR(i.fecha_importacion) = 2024
GROUP BY p.proveedores_id, d.razon_social, pr.calidad_producto) AS RankedProveedores
WHERE rn <= 2
ORDER BY calidad_producto, rn;


#PREGUNTA 7 
	
¿Cuál es el porcentaje de participación trimestral de cada producto por el país de origen?
	
WITH VolumenTotalTrimestre AS (
    -- Volumen total de importación por trimestre
    SELECT 
        t.anio,
        t.trimestre,
        SUM(i.volumen_importacion) AS volumen_total_trimestre
    FROM 
        grupo02.Importacion i
    JOIN 
        grupo02.TIEMPO t ON i.fecha_importacion = t.fecha
    GROUP BY 
        t.anio,
        t.trimestre
),
VolumenPorPais AS (
    -- Volumen de importación por país (segun productos)
    SELECT 
        t.anio,
        t.trimestre,
        CASE 
            WHEN i.producto_id = 1 THEN 1  -- Producto 1 pertenece al país 1 (Argentina)
            WHEN i.producto_id IN (2, 3) THEN 2  -- Productos 2 y 3 pertenecen al país 2 (Estados Unidos)
        END AS pais_id,
        SUM(i.volumen_importacion) AS volumen_pais
    FROM 
        grupo02.Importacion i
    JOIN 
        grupo02.TIEMPO t ON i.fecha_importacion = t.fecha
    GROUP BY 
        t.anio,
        t.trimestre,
        CASE 
            WHEN i.producto_id = 1 THEN 1 
            WHEN i.producto_id IN (2, 3) THEN 2 
        END
)
-- Porcentaje de participación de cada país por trimestre
SELECT 
    vpp.anio,
    vpp.trimestre,
    p.nombre_pais,
    vpp.volumen_pais,
    vtt.volumen_total_trimestre,
    (vpp.volumen_pais * 100.0 / vtt.volumen_total_trimestre) AS porcentaje_participacion
FROM 
    VolumenPorPais vpp
JOIN 
    VolumenTotalTrimestre vtt 
    ON vpp.anio = vtt.anio 
    AND vpp.trimestre = vtt.trimestre
JOIN 
    grupo02.Pais p 
    ON vpp.pais_id = p.pais_id  -- Unión para obtener el nombre del país
ORDER BY 
    vpp.anio,
    vpp.trimestre,
    p.nombre_pais;

#PREGUNTA 8
	
¿Cómo ha sido la evolución de los pedidos tipo contado y pedidos tipo crédito en relación al total de pedidos por trimestres a partir del 2024?

SELECT YEAR(p.fecha_pedidos) AS anio, DATEPART(QUARTER, p.fecha_pedidos) AS trimestre,
    CASE
        WHEN cp.tipo_de_pago_id = 1 THEN 'CONTADO'
        WHEN cp.tipo_de_pago_id = 2 THEN 'CREDITO'
        ELSE 'ND'  
    END AS tipo_de_pago,
    COUNT(p.pedidos_id) AS total_pedidos
FROM
    [grupo02].[Pedidos] p JOIN [grupo02].[Clientes] c ON p.clientes_id = c.clientes_id JOIN [grupo02].[Condiciones_De_Pago] cp ON c.condiciones_de_pago_id = cp.condiciones_de_pago_id
WHERE
    p.fecha_pedidos >= '2024-01-01'
GROUP BY YEAR(p.fecha_pedidos),
    DATEPART(QUARTER, p.fecha_pedidos),
    CASE
       WHEN cp.tipo_de_pago_id = 1 THEN 'CONTADO'
        WHEN cp.tipo_de_pago_id = 2 THEN 'CREDITO'
        ELSE 'ND' 
    END
ORDER BY anio, trimestre, tipo_de_pago;

#PREGUNTA 9
	
¿Cuál es la evaluación entre el volumen de importación y el volumen de pedidos de la empresa ABC durante los trimestres del 2023 y 2024?

DROP TABLE IF EXISTS #tmp
select	Anio = isnull(a.Anio,b.Anio),
		Trimestre = isnull(a.Trimestre,b.Trimestre),
		a.volumen_importacion,
		b.volumen_pedidos
into #tmp
from (select C.Anio, C.Trimestre, volumen_importacion=sum(A.volumen_importacion)
		from grupo02.Importacion A
		inner join grupo02.TIEMPO C
		on A.fecha_importacion = C.Fecha
		where C.Anio between 2023 and 2024
		Group by C.Anio, C.Trimestre) A
	full join
	(select C.Anio, C.Trimestre, volumen_pedidos=sum (B.volumen_pedidos)
		from grupo02.Pedidos B
		inner join grupo02.TIEMPO C
		on B.fecha_pedidos = C.Fecha
		where C.Anio between 2023 and 2024
		Group by C.Anio, C.Trimestre) B
	ON A.Anio = B.Anio AND A.Trimestre = B.Trimestre

SELECT (COUNT(*) * SUM(Volumen_importacion * Volumen_pedidos) - SUM(Volumen_importacion) * SUM(volumen_pedidos)) / 
       SQRT((COUNT(*) * SUM(Volumen_importacion * Volumen_importacion) - SUM(Volumen_importacion) * SUM(Volumen_importacion)) * 
       (COUNT(*) * SUM(Volumen_pedidos * volumen_pedidos) - SUM(volumen_pedidos) * SUM(volumen_pedidos))) AS Correlacion
FROM #tmp

#PREGUNTA 10 
	
¿Cuál es la fluctuación de los ingresos y los costos que incurren en la importación del maíz durante los trimestres del 2023 y 2024?
	
select        Anio = isnull(a.Anio,b.Anio),
                Trimestre = isnull(a.Trimestre,b.Trimestre),
                a.ingresos,
                b.precio_pedidos

from (select C.Anio, C.Trimestre, ingresos=sum(A.precio_importacion)
                from grupo02.Importacion A
                inner join grupo02.TIEMPO C
                on A.fecha_importacion = C.Fecha
                where C.Anio between 2022 and 2024
                Group by C.Anio, C.Trimestre) A
        full join
        (select C.Anio, C.Trimestre, precio_pedidos=sum (B.precio_pedidos)
                from grupo02.Pedidos B
                inner join grupo02.TIEMPO C
                on B.fecha_pedidos = C.Fecha
                where C.Anio between 2022 and 2024
                Group by C.Anio, C.Trimestre) B
        ON A.Anio = B.Anio AND A.Trimestre = B.Trimestre