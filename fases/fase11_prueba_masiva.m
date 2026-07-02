function resultados_masivos = fase11_prueba_masiva(cfg)
% ================================================================
% FASE 11: Prueba masiva con dataset
%
% Objetivo:
%   - Evaluar el pipeline completo en varios casos del dataset.
%   - Ejecutar Fase 1 a Fase 9 para cada caso.
%   - Guardar métricas individuales y resumen global.
%
% Entrada:
%   cfg.casos_masivos
%
% Salida:
%   resultados_masivos.tabla_resultados
%   resultados_masivos.resumen_global
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 11: Prueba masiva con dataset\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase11(cfg);

    casos = cfg.casos_masivos;
    num_casos = numel(casos);

    %% ------------------------------------------------------------
    % 1. Inicializar tabla de resultados
    % ------------------------------------------------------------

    caso = strings(num_casos, 1);
    estado = strings(num_casos, 1);
    accuracy_global = nan(num_casos, 1);
    total_stickers = nan(num_casos, 1);
    correctos = nan(num_casos, 1);
    incorrectos = nan(num_casos, 1);
    tiempo_segundos = nan(num_casos, 1);
    mensaje_error = strings(num_casos, 1);
    ruta_resultados = strings(num_casos, 1);

    tabla_resultados = table( ...
        caso, ...
        estado, ...
        accuracy_global, ...
        total_stickers, ...
        correctos, ...
        incorrectos, ...
        tiempo_segundos, ...
        mensaje_error, ...
        ruta_resultados);

    %% ------------------------------------------------------------
    % 2. Recorrer casos
    % ------------------------------------------------------------

    for i = 1:num_casos

        caso_actual = casos{i};

        fprintf('\n-------------------------------------------------\n');
        fprintf('Procesando %s (%d de %d)\n', caso_actual, i, num_casos);
        fprintf('-------------------------------------------------\n');

        t_inicio = tic;

        tabla_resultados.caso(i) = string(caso_actual);

        try

            %% Preparar configuración específica del caso

            cfg_caso = preparar_cfg_caso(cfg, caso_actual);

            verificar_archivos_caso(cfg_caso);

            %% Ejecutar pipeline individual

            datos_caso = ejecutar_pipeline_caso(cfg_caso);

            %% Extraer métricas

            metricas = extraer_metricas_caso(datos_caso);

            tabla_resultados.estado(i) = "correcto";
            tabla_resultados.accuracy_global(i) = metricas.accuracy_global;
            tabla_resultados.total_stickers(i) = metricas.total_stickers;
            tabla_resultados.correctos(i) = metricas.correctos;
            tabla_resultados.incorrectos(i) = metricas.incorrectos;
            tabla_resultados.tiempo_segundos(i) = toc(t_inicio);
            tabla_resultados.mensaje_error(i) = "";
            tabla_resultados.ruta_resultados(i) = string(cfg_caso.resultados_dir);

            fprintf('\nResultado %s:\n', caso_actual);
            fprintf('Accuracy: %.2f %%\n', metricas.accuracy_global * 100);
            fprintf('Correctos: %d / %d\n', metricas.correctos, metricas.total_stickers);

            %% Reporte individual opcional

            if cfg.generar_reporte_caso_masivo
                try
                    datos_caso = fase10_reporte_final(datos_caso, cfg_caso);
                catch ME_reporte
                    warning('El caso %s fue evaluado, pero falló el reporte individual: %s', ...
                        caso_actual, ME_reporte.message);
                end
            end

        catch ME

            tabla_resultados.estado(i) = "fallo";
            tabla_resultados.accuracy_global(i) = NaN;
            tabla_resultados.total_stickers(i) = NaN;
            tabla_resultados.correctos(i) = NaN;
            tabla_resultados.incorrectos(i) = NaN;
            tabla_resultados.tiempo_segundos(i) = toc(t_inicio);
            tabla_resultados.mensaje_error(i) = string(ME.message);

            if exist('cfg_caso', 'var') && isfield(cfg_caso, 'resultados_dir')
                tabla_resultados.ruta_resultados(i) = string(cfg_caso.resultados_dir);
            else
                tabla_resultados.ruta_resultados(i) = "";
            end

            fprintf('\nFALLO en %s:\n%s\n', caso_actual, ME.message);

            if ~cfg.continuar_si_falla_caso
                rethrow(ME);
            end

        end

        close all;

    end

    %% ------------------------------------------------------------
    % 3. Crear resumen global
    % ------------------------------------------------------------

    resumen_global = crear_resumen_global(tabla_resultados);

    %% ------------------------------------------------------------
    % 4. Guardar resultados
    % ------------------------------------------------------------

    guardar_resultados_masivos(tabla_resultados, resumen_global, cfg);

    %% ------------------------------------------------------------
    % 5. Visualización final
    % ------------------------------------------------------------

    if cfg.mostrar_grafico_masivo
        visualizar_accuracy_masivo(tabla_resultados);
    end

    %% ------------------------------------------------------------
    % 6. Salida
    % ------------------------------------------------------------

    resultados_masivos = struct();
    resultados_masivos.tabla_resultados = tabla_resultados;
    resultados_masivos.resumen_global = resumen_global;

    fprintf('\n================ RESUMEN FASE 11 ================\n');
    disp(resumen_global);
    fprintf('=================================================\n');

    fprintf('\nFASE 11 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase11(cfg)

    if ~isfield(cfg, 'dataset_dir')
        cfg.dataset_dir = 'dataset';
    end

    if ~isfield(cfg, 'resultados_base_dir')
        cfg.resultados_base_dir = 'resultados';
    end

    if ~isfield(cfg, 'casos_masivos')
        cfg.casos_masivos = arrayfun(@(k) sprintf('caso_%03d', k), ...
            1:20, ...
            'UniformOutput', false);
    end

    if ~isfield(cfg, 'resultados_masivos_dir')
        cfg.resultados_masivos_dir = fullfile(cfg.resultados_base_dir, 'prueba_masiva');
    end

    if ~exist(cfg.resultados_masivos_dir, 'dir')
        mkdir(cfg.resultados_masivos_dir);
    end

    if ~isfield(cfg, 'mostrar_figuras_masivo')
        cfg.mostrar_figuras_masivo = false;
    end

    if ~isfield(cfg, 'modo_poligonos_masivo')
        cfg.modo_poligonos_masivo = 'hough';
    end

    if ~isfield(cfg, 'reutilizar_poligonos_masivo')
        cfg.reutilizar_poligonos_masivo = true;
    end

    if ~isfield(cfg, 'forzar_nueva_seleccion_masivo')
        cfg.forzar_nueva_seleccion_masivo = false;
    end

    if ~isfield(cfg, 'generar_reporte_caso_masivo')
        cfg.generar_reporte_caso_masivo = false;
    end

    if ~isfield(cfg, 'mostrar_grafico_masivo')
        cfg.mostrar_grafico_masivo = true;
    end

    if ~isfield(cfg, 'continuar_si_falla_caso')
        cfg.continuar_si_falla_caso = true;
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Preparar configuración de un caso
% ================================================================

function cfg_caso = preparar_cfg_caso(cfg, caso_actual)

    cfg_caso = cfg;

    cfg_caso.usar_dataset = true;
    cfg_caso.caso_actual = caso_actual;

    cfg_caso.caso_dir = fullfile(cfg_caso.dataset_dir, cfg_caso.caso_actual);

    cfg_caso.img1_path = fullfile(cfg_caso.caso_dir, 'img1.png');
    cfg_caso.img2_path = fullfile(cfg_caso.caso_dir, 'img2.png');
    cfg_caso.ground_truth_path = fullfile(cfg_caso.caso_dir, 'ground_truth_cubo.csv');

    cfg_caso.resultados_dir = fullfile(cfg_caso.resultados_base_dir, cfg_caso.caso_actual);

    if ~exist(cfg_caso.resultados_dir, 'dir')
        mkdir(cfg_caso.resultados_dir);
    end

    %% Recalcular carpetas derivadas del caso

    cfg_caso.candidatos_dir = fullfile(cfg_caso.resultados_dir, 'candidatos_fase5');
    cfg_caso.poligonos_dir = fullfile(cfg_caso.resultados_dir, 'poligonos_caras');
    cfg_caso.agrupacion_caras_dir = fullfile(cfg_caso.resultados_dir, 'agrupacion_caras');
    cfg_caso.matrices_dir = fullfile(cfg_caso.resultados_dir, 'matrices_caras');
    cfg_caso.cubo_integrado_dir = fullfile(cfg_caso.resultados_dir, 'cubo_integrado');
    cfg_caso.evaluacion_dir = fullfile(cfg_caso.resultados_dir, 'evaluacion');
    cfg_caso.reporte_final_dir = fullfile(cfg_caso.resultados_dir, 'reporte_final');

    crear_dir_si_no_existe(cfg_caso.candidatos_dir);
    crear_dir_si_no_existe(cfg_caso.poligonos_dir);
    crear_dir_si_no_existe(cfg_caso.agrupacion_caras_dir);
    crear_dir_si_no_existe(cfg_caso.matrices_dir);
    crear_dir_si_no_existe(cfg_caso.cubo_integrado_dir);
    crear_dir_si_no_existe(cfg_caso.evaluacion_dir);
    crear_dir_si_no_existe(cfg_caso.reporte_final_dir);

    %% Configuración especial para prueba masiva

    cfg_caso.mostrar_figuras = cfg.mostrar_figuras_masivo;
    cfg_caso.guardar_figuras = false;

    cfg_caso.mostrar_candidatos_geometricos = false;
    cfg_caso.mostrar_caras_rectificadas = false;
    cfg_caso.mostrar_matrices_graficas = false;
    cfg_caso.mostrar_cubo_integrado_grafico = false;
    cfg_caso.mostrar_matriz_confusion = false;

    cfg_caso.mostrar_matrices_consola = false;
    cfg_caso.mostrar_cubo_integrado_consola = false;
    cfg_caso.mostrar_metricas_consola = false;
    cfg_caso.mostrar_reporte_final_consola = false;

    cfg_caso.hough_mostrar_diagnostico = false;
    cfg_caso.hough_mostrar_reporte_validacion = false;

    %% Polígonos automáticos para masivo

    cfg_caso.modo_poligonos_caras = cfg.modo_poligonos_masivo;
    cfg_caso.reutilizar_poligonos_caras = cfg.reutilizar_poligonos_masivo;
    cfg_caso.forzar_nueva_seleccion_caras = cfg.forzar_nueva_seleccion_masivo;

end


%% ================================================================
% FUNCIÓN LOCAL: Verificar archivos del caso
% ================================================================

function verificar_archivos_caso(cfg_caso)

    if ~exist(cfg_caso.caso_dir, 'dir')
        error('No existe la carpeta del caso: %s', cfg_caso.caso_dir);
    end

    if ~exist(cfg_caso.img1_path, 'file')
        error('No existe img1.png en: %s', cfg_caso.img1_path);
    end

    if ~exist(cfg_caso.img2_path, 'file')
        error('No existe img2.png en: %s', cfg_caso.img2_path);
    end

    if ~exist(cfg_caso.ground_truth_path, 'file')
        error('No existe ground_truth_cubo.csv en: %s', cfg_caso.ground_truth_path);
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Ejecutar pipeline individual
% ================================================================

function datos = ejecutar_pipeline_caso(cfg_caso)

    datos = fase1_analisis_hsv(cfg_caso);
    datos = fase2_preprocesamiento(datos, cfg_caso);
    datos = fase3_roi_cubo(datos, cfg_caso);
    datos = fase4_segmentacion_stickers(datos, cfg_caso);
    datos = fase5_regionprops_kmeans(datos, cfg_caso);
    datos = fase6_agrupacion_caras(datos, cfg_caso);
    datos = fase7_matrices_caras(datos, cfg_caso);
    datos = fase8_integracion_cubo(datos, cfg_caso);
    datos = fase9_evaluacion_cubo(datos, cfg_caso);

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer métricas del caso
% ================================================================

function metricas = extraer_metricas_caso(datos)

    metricas = struct();

    if isfield(datos, 'metricas_evaluacion')

        m = datos.metricas_evaluacion;

        metricas.total_stickers = m.total_stickers;
        metricas.correctos = m.total_correctos;
        metricas.incorrectos = m.total_incorrectos;
        metricas.accuracy_global = m.accuracy_global;

    elseif isfield(datos, 'evaluacion')

        m = datos.evaluacion;

        if isfield(m, 'total')
            metricas.total_stickers = m.total;
        elseif isfield(m, 'total_stickers')
            metricas.total_stickers = m.total_stickers;
        else
            metricas.total_stickers = NaN;
        end

        if isfield(m, 'correctos')
            metricas.correctos = m.correctos;
        elseif isfield(m, 'total_correctos')
            metricas.correctos = m.total_correctos;
        else
            metricas.correctos = NaN;
        end

        if isfield(m, 'incorrectos')
            metricas.incorrectos = m.incorrectos;
        elseif isfield(m, 'total_incorrectos')
            metricas.incorrectos = m.total_incorrectos;
        else
            metricas.incorrectos = NaN;
        end

        if isfield(m, 'accuracy_global')
            metricas.accuracy_global = m.accuracy_global;
        else
            metricas.accuracy_global = NaN;
        end

    else

        error('No se encontraron métricas de evaluación en datos.');

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Crear resumen global
% ================================================================

function resumen_global = crear_resumen_global(tabla_resultados)

    total_casos = height(tabla_resultados);

    idx_correctos = tabla_resultados.estado == "correcto";
    idx_fallidos = tabla_resultados.estado == "fallo";

    casos_correctos = sum(idx_correctos);
    casos_fallidos = sum(idx_fallidos);

    accuracies = tabla_resultados.accuracy_global(idx_correctos);
    accuracies = accuracies(~isnan(accuracies));

    if isempty(accuracies)
        accuracy_promedio = NaN;
        accuracy_minima = NaN;
        accuracy_maxima = NaN;
        desviacion_accuracy = NaN;
    else
        accuracy_promedio = mean(accuracies);
        accuracy_minima = min(accuracies);
        accuracy_maxima = max(accuracies);
        desviacion_accuracy = std(accuracies);
    end

    stickers_totales = nansum(tabla_resultados.total_stickers);
    correctos_totales = nansum(tabla_resultados.correctos);
    incorrectos_totales = nansum(tabla_resultados.incorrectos);

    if stickers_totales > 0
        accuracy_global_dataset = correctos_totales / stickers_totales;
    else
        accuracy_global_dataset = NaN;
    end

    resumen_global = table( ...
        total_casos, ...
        casos_correctos, ...
        casos_fallidos, ...
        stickers_totales, ...
        correctos_totales, ...
        incorrectos_totales, ...
        accuracy_global_dataset, ...
        accuracy_promedio, ...
        accuracy_minima, ...
        accuracy_maxima, ...
        desviacion_accuracy);

end


%% ================================================================
% FUNCIÓN LOCAL: Guardar resultados masivos
% ================================================================

function guardar_resultados_masivos(tabla_resultados, resumen_global, cfg)

    if ~exist(cfg.resultados_masivos_dir, 'dir')
        mkdir(cfg.resultados_masivos_dir);
    end

    ruta_tabla = fullfile(cfg.resultados_masivos_dir, 'resultados_por_caso.csv');
    ruta_resumen = fullfile(cfg.resultados_masivos_dir, 'resumen_global_dataset.csv');
    ruta_mat = fullfile(cfg.resultados_masivos_dir, 'resultados_prueba_masiva.mat');

    writetable(tabla_resultados, ruta_tabla);
    writetable(resumen_global, ruta_resumen);

    save(ruta_mat, ...
        'tabla_resultados', ...
        'resumen_global');

    fprintf('\nResultados masivos guardados en:\n');
    fprintf('%s\n', ruta_tabla);
    fprintf('%s\n', ruta_resumen);
    fprintf('%s\n', ruta_mat);

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar accuracy por caso
% ================================================================

function visualizar_accuracy_masivo(tabla_resultados)

    figure('Name', 'Fase 11 - Accuracy por caso', ...
           'NumberTitle', 'off');

    acc = tabla_resultados.accuracy_global * 100;

    bar(acc);
    ylim([0 100]);

    grid on;

    xlabel('Caso');
    ylabel('Accuracy (%)');
    title('Fase 11 - Accuracy por caso');

    xticks(1:height(tabla_resultados));
    xticklabels(cellstr(tabla_resultados.caso));
    xtickangle(45);

end


%% ================================================================
% FUNCIÓN LOCAL: Crear carpeta si no existe
% ================================================================

function crear_dir_si_no_existe(ruta)

    if ~exist(ruta, 'dir')
        mkdir(ruta);
    end

end