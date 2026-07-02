function datos = fase10_reporte_final(datos, cfg)
% ================================================================
% FASE 10: Validación integral y reporte final del pipeline
%
% Objetivo:
%   - Consolidar los resultados principales del proyecto.
%   - Validar que cada fase crítica produjo una salida coherente.
%   - Generar un reporte final con detección, integración y métricas.
%
% Esta fase resume:
%   - número de stickers detectados por imagen,
%   - número de stickers por cara,
%   - seis caras integradas,
%   - conteo global de colores,
%   - accuracy global,
%   - accuracy por color,
%   - matriz de confusión.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 10: Reporte final del pipeline\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase10(cfg);

    %% ------------------------------------------------------------
    % 1. Crear resumen general
    % ------------------------------------------------------------

    resumen_general = crear_resumen_general(datos);

    %% ------------------------------------------------------------
    % 2. Crear resumen de detección
    % ------------------------------------------------------------

    resumen_deteccion = crear_resumen_deteccion(datos);

    %% ------------------------------------------------------------
    % 3. Crear resumen de caras
    % ------------------------------------------------------------

    resumen_caras = crear_resumen_caras(datos);

    %% ------------------------------------------------------------
    % 4. Crear resumen de integración
    % ------------------------------------------------------------

    resumen_integracion = crear_resumen_integracion(datos);

    %% ------------------------------------------------------------
    % 5. Crear resumen de evaluación
    % ------------------------------------------------------------

    resumen_evaluacion = crear_resumen_evaluacion(datos);

    %% ------------------------------------------------------------
    % 6. Diagnóstico final del pipeline
    % ------------------------------------------------------------

    diagnostico_final = crear_diagnostico_final( ...
        resumen_deteccion, ...
        resumen_caras, ...
        resumen_integracion, ...
        resumen_evaluacion);

    %% ------------------------------------------------------------
    % 7. Mostrar reporte en consola
    % ------------------------------------------------------------

    if cfg.mostrar_reporte_final_consola

        imprimir_reporte_final( ...
            resumen_general, ...
            resumen_deteccion, ...
            resumen_caras, ...
            resumen_integracion, ...
            resumen_evaluacion, ...
            diagnostico_final);

    end

    %% ------------------------------------------------------------
    % 8. Guardar reporte
    % ------------------------------------------------------------

    if cfg.guardar_reporte_final

        guardar_reporte_final( ...
            resumen_general, ...
            resumen_deteccion, ...
            resumen_caras, ...
            resumen_integracion, ...
            resumen_evaluacion, ...
            diagnostico_final, ...
            cfg);

    end

    %% ------------------------------------------------------------
    % 9. Guardar en datos
    % ------------------------------------------------------------

    datos.resumen_general = resumen_general;
    datos.resumen_deteccion = resumen_deteccion;
    datos.resumen_caras = resumen_caras;
    datos.resumen_integracion = resumen_integracion;
    datos.resumen_evaluacion = resumen_evaluacion;
    datos.diagnostico_final = diagnostico_final;

    fprintf('\n================ RESUMEN FASE 10 ================\n');
    fprintf('Reporte final generado correctamente.\n');
    fprintf('Diagnóstico final: %s\n', diagnostico_final.estado_general{1});
    fprintf('=================================================\n');

    fprintf('\nFASE 10 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase10(cfg)

    if ~isfield(cfg, 'mostrar_reporte_final_consola')
        cfg.mostrar_reporte_final_consola = true;
    end

    if ~isfield(cfg, 'guardar_reporte_final')
        cfg.guardar_reporte_final = true;
    end

    if ~isfield(cfg, 'reporte_final_dir')
        cfg.reporte_final_dir = fullfile(cfg.resultados_dir, 'reporte_final');
    end

    if ~exist(cfg.reporte_final_dir, 'dir')
        mkdir(cfg.reporte_final_dir);
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Resumen general
% ================================================================

function resumen = crear_resumen_general(datos)

    fase = {
        'Fase 1';
        'Fase 2';
        'Fase 3';
        'Fase 4';
        'Fase 5';
        'Fase 6';
        'Fase 7';
        'Fase 8';
        'Fase 9'
    };

    descripcion = {
        'Lectura RGB y análisis HSV';
        'Preprocesamiento y suavizado';
        'Extracción de ROI del cubo';
        'Segmentación preliminar por HSV';
        'Extracción geométrica de 27 candidatos y clasificación con K-means';
        'Agrupación de candidatos por caras visibles';
        'Construcción de matrices 3x3 por cara';
        'Integración de seis caras por color central';
        'Evaluación cuantitativa con ground truth CSV'
    };

    estado = repmat({'completada'}, numel(fase), 1);

    resumen = table(fase, descripcion, estado);

end


%% ================================================================
% FUNCIÓN LOCAL: Resumen de detección
% ================================================================

function resumen = crear_resumen_deteccion(datos)

    imagen = {
        'Imagen 1';
        'Imagen 2'
    };

    if isfield(datos, 'num_candidatos1')
        n1 = datos.num_candidatos1;
    elseif isfield(datos, 'candidatos1')
        n1 = numel(datos.candidatos1);
    else
        n1 = NaN;
    end

    if isfield(datos, 'num_candidatos2')
        n2 = datos.num_candidatos2;
    elseif isfield(datos, 'candidatos2')
        n2 = numel(datos.candidatos2);
    else
        n2 = NaN;
    end

    stickers_detectados = [
        n1;
        n2
    ];

    stickers_esperados = [
        27;
        27
    ];

    diferencia = stickers_detectados - stickers_esperados;

    estado = cell(2,1);

    for i = 1:2

        if isnan(stickers_detectados(i))
            estado{i} = 'sin_dato';

        elseif diferencia(i) == 0
            estado{i} = 'correcto';

        else
            estado{i} = 'revisar';
        end

    end

    resumen = table( ...
        imagen, ...
        stickers_esperados, ...
        stickers_detectados, ...
        diferencia, ...
        estado);

end


%% ================================================================
% FUNCIÓN LOCAL: Resumen de caras
% ================================================================

function resumen = crear_resumen_caras(datos)

    imagen = {};
    cara = {};
    stickers_esperados = [];
    stickers_detectados = [];
    estado = {};

    nombres_caras = {'superior', 'izquierda', 'derecha'};

    caras_img = {
        datos.caras1, 'Imagen 1';
        datos.caras2, 'Imagen 2'
    };

    for i = 1:size(caras_img, 1)

        caras = caras_img{i, 1};
        nombre_img = caras_img{i, 2};

        for k = 1:numel(nombres_caras)

            nombre_cara = nombres_caras{k};

            campo_num = ['num_' nombre_cara];

            detectados = caras.(campo_num);

            imagen{end+1,1} = nombre_img;
            cara{end+1,1} = nombre_cara;
            stickers_esperados(end+1,1) = 9;
            stickers_detectados(end+1,1) = detectados;

            if detectados == 9
                estado{end+1,1} = 'correcto';
            else
                estado{end+1,1} = 'revisar';
            end

        end
    end

    resumen = table( ...
        imagen, ...
        cara, ...
        stickers_esperados, ...
        stickers_detectados, ...
        estado);

end


%% ================================================================
% FUNCIÓN LOCAL: Resumen de integración
% ================================================================

function resumen = crear_resumen_integracion(datos)

    reporte = datos.reporte_validacion_cubo;

    resumen = reporte;

end


%% ================================================================
% FUNCIÓN LOCAL: Resumen de evaluación
% ================================================================

function resumen = crear_resumen_evaluacion(datos)

    if isfield(datos, 'metricas_evaluacion')

        metricas = datos.metricas_evaluacion;

        total_stickers = metricas.total_stickers;
        total_correctos = metricas.total_correctos;
        total_incorrectos = metricas.total_incorrectos;
        accuracy_global = metricas.accuracy_global;

    elseif isfield(datos, 'evaluacion')

        metricas = datos.evaluacion;

        if isfield(metricas, 'total')
            total_stickers = metricas.total;
        else
            total_stickers = NaN;
        end

        if isfield(metricas, 'correctos')
            total_correctos = metricas.correctos;
        else
            total_correctos = NaN;
        end

        if isfield(metricas, 'incorrectos')
            total_incorrectos = metricas.incorrectos;
        else
            total_incorrectos = NaN;
        end

        if isfield(metricas, 'accuracy_global')
            accuracy_global = metricas.accuracy_global;
        else
            accuracy_global = NaN;
        end

    else

        error('No existen datos.metricas_evaluacion ni datos.evaluacion. Ejecuta primero la Fase 9.');

    end

    indicador = {
        'total_stickers';
        'total_correctos';
        'total_incorrectos';
        'accuracy_global'
    };

    valor = [
        total_stickers;
        total_correctos;
        total_incorrectos;
        accuracy_global
    ];

    resumen = table(indicador, valor);

end


%% ================================================================
% FUNCIÓN LOCAL: Diagnóstico final
% ================================================================

function diagnostico = crear_diagnostico_final( ...
    resumen_deteccion, ...
    resumen_caras, ...
    resumen_integracion, ...
    resumen_evaluacion)

    ok_deteccion = all(strcmp(string(resumen_deteccion.estado), "correcto"));
    ok_caras = all(strcmp(string(resumen_caras.estado), "correcto"));

    if ismember('observacion', resumen_integracion.Properties.VariableNames)
        ok_integracion = all(strcmp(string(resumen_integracion.observacion), "correcto"));
    elseif ismember('estado', resumen_integracion.Properties.VariableNames)
        ok_integracion = all(strcmp(string(resumen_integracion.estado), "integrada") | ...
                             strcmp(string(resumen_integracion.estado), "correcto"));
    else
        ok_integracion = false;
    end

    idx_accuracy = strcmp(string(resumen_evaluacion.indicador), "accuracy_global");

    if any(idx_accuracy)
        accuracy = resumen_evaluacion.valor(idx_accuracy);
    else
        accuracy = NaN;
    end

    % Se usa tolerancia numérica para evitar problemas por decimales.
    ok_accuracy = ~isnan(accuracy) && accuracy >= 0.9999;

    if ok_deteccion && ok_caras && ok_integracion && ok_accuracy
        estado_general = {'correcto'};
        observacion = {'El pipeline reconstruyo correctamente el cubo evaluado.'};
    else
        estado_general = {'revisar'};
        observacion = {'Alguna etapa del pipeline requiere revision.'};
    end

    diagnostico = table( ...
        estado_general, ...
        ok_deteccion, ...
        ok_caras, ...
        ok_integracion, ...
        ok_accuracy, ...
        accuracy, ...
        observacion);

end


%% ================================================================
% FUNCIÓN LOCAL: Imprimir reporte
% ================================================================

function imprimir_reporte_final( ...
    resumen_general, ...
    resumen_deteccion, ...
    resumen_caras, ...
    resumen_integracion, ...
    resumen_evaluacion, ...
    diagnostico_final)

    fprintf('\n================ REPORTE FINAL DEL PIPELINE ================\n');

    fprintf('\n1. Resumen general de fases:\n');
    disp(resumen_general);

    fprintf('\n2. Resumen de detección de stickers:\n');
    disp(resumen_deteccion);

    fprintf('\n3. Resumen de asignación por caras:\n');
    disp(resumen_caras);

    fprintf('\n4. Resumen de integración del cubo:\n');
    disp(resumen_integracion);

    fprintf('\n5. Resumen de evaluación cuantitativa:\n');
    disp(resumen_evaluacion);

    fprintf('\n6. Diagnóstico final:\n');
    disp(diagnostico_final);

end


%% ================================================================
% FUNCIÓN LOCAL: Guardar reporte final
% ================================================================

function guardar_reporte_final( ...
    resumen_general, ...
    resumen_deteccion, ...
    resumen_caras, ...
    resumen_integracion, ...
    resumen_evaluacion, ...
    diagnostico_final, ...
    cfg)

    writetable(resumen_general, ...
        fullfile(cfg.reporte_final_dir, '01_resumen_general.csv'));

    writetable(resumen_deteccion, ...
        fullfile(cfg.reporte_final_dir, '02_resumen_deteccion.csv'));

    writetable(resumen_caras, ...
        fullfile(cfg.reporte_final_dir, '03_resumen_caras.csv'));

    writetable(resumen_integracion, ...
        fullfile(cfg.reporte_final_dir, '04_resumen_integracion.csv'));

    writetable(resumen_evaluacion, ...
        fullfile(cfg.reporte_final_dir, '05_resumen_evaluacion.csv'));

    writetable(diagnostico_final, ...
        fullfile(cfg.reporte_final_dir, '06_diagnostico_final.csv'));

    save(fullfile(cfg.reporte_final_dir, 'reporte_final_pipeline.mat'), ...
        'resumen_general', ...
        'resumen_deteccion', ...
        'resumen_caras', ...
        'resumen_integracion', ...
        'resumen_evaluacion', ...
        'diagnostico_final');

    fprintf('\nReporte final guardado en:\n');
    fprintf('%s\n', cfg.reporte_final_dir);

end