# Proyecto: Depressive symptoms and cognitive function in older adults (NHANES 2011–2014)

## Quién soy
Dr. Abraham Valles, médico mexicano, principiante en R. Este repositorio es mi portafolio
para demostrar a investigadores en EE. UU. que sé usar R. Debo poder explicar cada línea.

## Roles
- Yo: investigador principal. Apruebo cada paso.
- Claude (en otra conversación): arquitecto. Revisa tus planes y resúmenes.
- Codex: escribe y prueba el código. No cambies el alcance ni la arquitectura sin aprobación.

## Pregunta
¿Se asocian los síntomas depresivos (PHQ-9) con peor desempeño cognitivo en adultos
de 60 años o más? Estudio transversal: NO usar lenguaje causal.

## Datos (descargar con el paquete nhanesA; verificar nombres en la documentación oficial de NHANES)
- Ciclos 2011–2012 (sufijo _G) y 2013–2014 (sufijo _H). Son los ciclos públicos más
  recientes con pruebas cognitivas (2019–2020 solo está disponible vía RDC).
- DEMO: edad (RIDAGEYR), sexo (RIAGENDR), escolaridad (DMDEDUC2), raza/etnia (RIDRETH3),
  diseño muestral (SDMVPSU, SDMVSTRA, WTMEC2YR).
- DPQ: PHQ-9 = suma de DPQ010–DPQ090; 7 y 9 = rechazó / no sabe → NA.
- CFQ: CERAD aprendizaje y recuerdo diferido, fluidez de animales, DSST.
- Unir por SEQN. Al combinar 2 ciclos, peso = WTMEC2YR / 2.

## Análisis
1. Tabla 1 ponderada por categorías de PHQ-9 (<5, 5–9, ≥10) con gtsummary.
2. Figuras con ggplot2: puntaje cognitivo por categoría de PHQ-9.
3. Regresión lineal ponderada (paquete survey, svyglm) de cada prueba cognitiva sobre PHQ-9,
   ajustando por edad, sexo, escolaridad y raza/etnia.
4. Reportar n inicial, exclusiones y n final (diagrama de flujo en texto).
5. En `R/02_clean.R`, conservar a todos los participantes en el dataset final y crear
   indicadores de edad de 60 años o más y de muestra analítica. En la Sesión 2,
   construir primero el objeto `svydesign` con la muestra del examen y usar
   `subset()` sobre ese objeto para el análisis de adultos de 60 años o más
   y de casos completos por prueba, sin aplicar `filter()` a los datos para
   seleccionar esos subgrupos. Así se preserva el diseño para estimar los errores estándar.

## Estructura
R/01_download.R, R/02_clean.R, R/03_analysis.R, R/04_figures.R,
report/report.qmd (render a HTML), figures/, data/ (excluida de git), renv.lock, README.md.

## Reglas
- Estilo tidyverse, comentarios en inglés, claros, explicando el PORQUÉ.
- Todo reproducible desde cero corriendo los scripts en orden.
- No subir datos crudos a git (el script los descarga).
- Al terminar cada tarea, entrega un resumen: qué hiciste, archivos, decisiones y dudas.
- README y reporte en inglés. El README incluye una nota: "Code developed with AI
  assistance; study design and analytic decisions by the author."
