%% ============================================================
% MAIN_FASE12_RESULTADOS
% Consolidacion de resultados globales del dataset
% ============================================================

clc;
clear;
close all;

addpath('fases');
addpath('funciones');

cfg = config_rubik();

resultados_fase12 = fase12_resultados_dataset(cfg);