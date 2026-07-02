%% CONFIGURACIÓN GENERAL DEL PROYECTO

clc;
clear;
close all;

addpath('fases');
addpath('funciones');

cfg = config_rubik();


%% FASE 1: Lectura y análisis inicial RGB / HSV / Histogramas

datos = fase1_analisis_hsv(cfg);

%% FASE 2: Preprocesamiento y corrección de iluminación

datos = fase2_preprocesamiento(datos, cfg);

%% FASE 3: Extracción de ROI del cubo

datos = fase3_roi_cubo(datos, cfg);

%% FASE 4: Segmentación preliminar de stickers

datos = fase4_segmentacion_stickers(datos, cfg);

%% FASE 5: Extracción de candidatos con regionprops y K-means

datos = fase5_regionprops_kmeans(datos, cfg);

%% FASE 6: Agrupamiento de stickers por caras visibles

datos = fase6_agrupacion_caras(datos, cfg);

%% FASE 7: Construcción de matrices 3x3 por cara visible

datos = fase7_matrices_caras(datos, cfg);

%% FASE 8: Integración de las seis caras del cubo

datos = fase8_integracion_cubo(datos, cfg);

%% FASE 9: Evaluación cuantitativa del cubo reconstruido

datos = fase9_evaluacion_cubo(datos, cfg);

%% FASE 10: Validación integral y reporte final

datos = fase10_reporte_final(datos, cfg);