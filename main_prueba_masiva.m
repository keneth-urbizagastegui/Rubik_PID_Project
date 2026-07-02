%% ============================================================
% MAIN_PRUEBA_MASIVA
% Evaluación masiva del pipeline Rubik sobre dataset/caso_001...caso_020
% ============================================================

clc;
clear;
close all;

addpath('fases');
addpath('funciones');

cfg = config_rubik();

resultados_masivos = fase11_prueba_masiva(cfg);