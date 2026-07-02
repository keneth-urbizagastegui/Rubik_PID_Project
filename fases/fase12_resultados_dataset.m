function resultados_fase12 = fase12_resultados_dataset(cfg)
% ================================================================
% FASE 12: Resultados globales del dataset
%
% Objetivo:
%   - Consolidar los resultados de todos los casos evaluados.
%   - Construir una matriz de confusion global.
%   - Calcular metricas globales por color.
%   - Generar tablas y graficos para presentacion.
%
% Esta fase NO procesa imagenes.
% Lee los archivos generados por Fase 9 y Fase 11.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 12: Resultados globales del dataset\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase12(cfg);

    %% ------------------------------------------------------------
    % 1. Leer resultados por caso generados en Fase 11
    % ------------------------------------------------------------

    ruta_resultados_por_caso = fullfile( ...
        cfg.resultados_masivos_dir, ...
        'resultados_por_caso.csv');

    if ~exist(ruta_resultados_por_caso, 'file')
        error('No se encontro resultados_por_caso.csv. Ejecuta primero la Fase 11.');
    end

    tabla_casos = readtable(ruta_resultados_por_caso, ...
        'TextType', 'string');

    fprintf('\nResultados por caso leidos desde:\n%s\n', ruta_resultados_por_caso);
    fprintf('Casos registrados: %d\n', height(tabla_casos));

    %% ------------------------------------------------------------
    % 2. Leer comparaciones celda por celda de todos los casos
    % ------------------------------------------------------------

    tabla_global = table();

    for i = 1:height(tabla_casos)

        caso_actual = string(tabla_casos.caso(i));

        ruta_comparacion = fullfile( ...
            cfg.resultados_base_dir, ...
            char(caso_actual), ...
            'evaluacion', ...
            'comparacion_celda_por_celda.csv');

        if exist(ruta_comparacion, 'file')

            T = leer_comparacion_caso(ruta_comparacion, caso_actual);
            tabla_global = [tabla_global; T]; %#ok<AGROW>

        else

            warning('No se encontro comparacion para %s: %s', ...
                caso_actual, ruta_comparacion);

        end

    end

    if isempty(tabla_global)
        error('No se pudo construir la tabla global. No hay comparaciones disponibles.');
    end

    fprintf('Comparaciones globales leidas: %d stickers.\n', height(tabla_global));

    %% ------------------------------------------------------------
    % 3. Construir matriz de confusion global
    % ------------------------------------------------------------

    colores = cfg.colores_eval;
    matriz_confusion_global = construir_matriz_confusion_global( ...
        tabla_global, ...
        colores);

    %% ------------------------------------------------------------
    % 4. Calcular resumen global
    % ------------------------------------------------------------

    resumen_global = calcular_resumen_global(tabla_global, tabla_casos);

    %% ------------------------------------------------------------
    % 5. Calcular metricas por color
    % ------------------------------------------------------------

    metricas_color = calcular_metricas_por_color( ...
        matriz_confusion_global, ...
        colores);

    %% ------------------------------------------------------------
    % 6. Extraer errores globales
    % ------------------------------------------------------------

    errores_globales = tabla_global(tabla_global.correcto == false, :);

    %% ------------------------------------------------------------
    % 7. Crear tabla de matriz de confusion
    % ------------------------------------------------------------

    tabla_matriz_confusion = matriz_a_tabla( ...
        matriz_confusion_global, ...
        colores);

    %% ------------------------------------------------------------
    % 8. Mostrar resumen en consola
    % ------------------------------------------------------------

    fprintf('\n================ RESULTADOS GLOBALES ================\n');
    disp(resumen_global);

    fprintf('\n================ METRICAS POR COLOR ================\n');
    disp(metricas_color);

    fprintf('\n================ MATRIZ DE CONFUSION GLOBAL ================\n');
    disp(tabla_matriz_confusion);

    fprintf('\n================ ERRORES GLOBALES ================\n');
    if isempty(errores_globales)
        fprintf('No se encontraron errores.\n');
    else
        disp(errores_globales);
    end

    %% ------------------------------------------------------------
    % 9. Guardar tablas
    % ------------------------------------------------------------

    if cfg.guardar_tablas_fase12

        if ~exist(cfg.fase12_dir, 'dir')
            mkdir(cfg.fase12_dir);
        end

        writetable(tabla_global, ...
            fullfile(cfg.fase12_dir, 'comparacion_global_celdas.csv'));

        writetable(resumen_global, ...
            fullfile(cfg.fase12_dir, 'resumen_global_fase12.csv'));

        writetable(metricas_color, ...
            fullfile(cfg.fase12_dir, 'metricas_globales_por_color.csv'));

        writetable(tabla_matriz_confusion, ...
            fullfile(cfg.fase12_dir, 'matriz_confusion_global.csv'));

        writetable(errores_globales, ...
            fullfile(cfg.fase12_dir, 'errores_globales.csv'));

    end

    %% ------------------------------------------------------------
    % 10. Generar graficos para presentacion
    % ------------------------------------------------------------

    visualizar_accuracy_por_caso(tabla_casos, cfg);
    visualizar_matriz_confusion_global(matriz_confusion_global, colores, cfg);
    visualizar_metricas_por_color(metricas_color, cfg);

    %% ------------------------------------------------------------
    % 11. Guardar archivo MAT
    % ------------------------------------------------------------

    save(fullfile(cfg.fase12_dir, 'resultados_fase12_dataset.mat'), ...
        'tabla_casos', ...
        'tabla_global', ...
        'resumen_global', ...
        'metricas_color', ...
        'matriz_confusion_global', ...
        'tabla_matriz_confusion', ...
        'errores_globales');

    %% ------------------------------------------------------------
    % 12. Salida
    % ------------------------------------------------------------

    resultados_fase12 = struct();

    resultados_fase12.tabla_casos = tabla_casos;
    resultados_fase12.tabla_global = tabla_global;
    resultados_fase12.resumen_global = resumen_global;
    resultados_fase12.metricas_color = metricas_color;
    resultados_fase12.matriz_confusion_global = matriz_confusion_global;
    resultados_fase12.tabla_matriz_confusion = tabla_matriz_confusion;
    resultados_fase12.errores_globales = errores_globales;

    fprintf('\nResultados de Fase 12 guardados en:\n%s\n', cfg.fase12_dir);

    fprintf('\n================ RESUMEN FASE 12 ================\n');
    fprintf('Casos evaluados: %d\n', resumen_global.total_casos);
    fprintf('Stickers evaluados: %d\n', resumen_global.stickers_totales);
    fprintf('Correctos: %d\n', resumen_global.correctos_totales);
    fprintf('Incorrectos: %d\n', resumen_global.incorrectos_totales);
    fprintf('Accuracy global: %.3f %%\n', resumen_global.accuracy_global_dataset * 100);
    fprintf('=================================================\n');

    fprintf('\nFASE 12 finalizada correctamente.\n');

end


%% ================================================================
% COMPLETAR CONFIGURACION
% ================================================================

function cfg = completar_cfg_fase12(cfg)

    if ~isfield(cfg, 'resultados_base_dir')
        cfg.resultados_base_dir = 'resultados';
    end

    if ~isfield(cfg, 'resultados_masivos_dir')
        cfg.resultados_masivos_dir = fullfile(cfg.resultados_base_dir, 'prueba_masiva');
    end

    if ~isfield(cfg, 'fase12_dir')
        cfg.fase12_dir = fullfile(cfg.resultados_masivos_dir, 'fase12_resultados');
    end

    if ~exist(cfg.fase12_dir, 'dir')
        mkdir(cfg.fase12_dir);
    end

    if ~isfield(cfg, 'colores_eval')
        cfg.colores_eval = {'B', 'A', 'R', 'N', 'V', 'Az'};
    end

    if ~isfield(cfg, 'mostrar_figuras_fase12')
        cfg.mostrar_figuras_fase12 = true;
    end

    if ~isfield(cfg, 'guardar_figuras_fase12')
        cfg.guardar_figuras_fase12 = true;
    end

    if ~isfield(cfg, 'guardar_tablas_fase12')
        cfg.guardar_tablas_fase12 = true;
    end

end


%% ================================================================
% LEER COMPARACION DE UN CASO
% ================================================================

function T = leer_comparacion_caso(ruta_comparacion, caso_actual)

    T = readtable(ruta_comparacion, ...
        'TextType', 'string');

    nombres = lower(string(T.Properties.VariableNames));

    idx_cara = find(nombres == "cara", 1);
    idx_fila = find(nombres == "fila", 1);
    idx_columna = find(nombres == "columna", 1);
    idx_esperado = find(nombres == "esperado", 1);
    idx_detectado = find(nombres == "detectado", 1);

    if isempty(idx_cara) || isempty(idx_fila) || isempty(idx_columna) || ...
       isempty(idx_esperado) || isempty(idx_detectado)

        error('La tabla de comparacion no tiene las columnas esperadas: %s', ...
            ruta_comparacion);
    end

    T = T(:, [idx_cara, idx_fila, idx_columna, idx_esperado, idx_detectado]);
    T.Properties.VariableNames = {'cara', 'fila', 'columna', 'esperado', 'detectado'};

    T.caso = repmat(string(caso_actual), height(T), 1);
    T = movevars(T, 'caso', 'Before', 1);

    T.cara = lower(strtrim(string(T.cara)));
    T.esperado = normalizar_columna_color(T.esperado);
    T.detectado = normalizar_columna_color(T.detectado);

    if ~isnumeric(T.fila)
        T.fila = str2double(string(T.fila));
    end

    if ~isnumeric(T.columna)
        T.columna = str2double(string(T.columna));
    end

    T.correcto = T.esperado == T.detectado;

end


%% ================================================================
% NORMALIZAR COLUMNA DE COLOR
% ================================================================

function salida = normalizar_columna_color(col)

    salida = strings(height(table(col)), 1);

    for i = 1:numel(col)
        salida(i) = normalizar_codigo_color(col(i));
    end

end


%% ================================================================
% NORMALIZAR CODIGO DE COLOR
% ================================================================

function codigo = normalizar_codigo_color(codigo)

    if iscell(codigo)
        codigo = codigo{1};
    end

    if iscategorical(codigo)
        codigo = string(codigo);
    end

    codigo = strtrim(string(codigo));
    codigo = erase(codigo, '"');
    codigo = lower(codigo);

    switch codigo

        case {"b", "blanco", "white"}
            codigo = "B";

        case {"a", "amarillo", "yellow"}
            codigo = "A";

        case {"r", "rojo", "red"}
            codigo = "R";

        case {"n", "naranja", "orange"}
            codigo = "N";

        case {"v", "verde", "green"}
            codigo = "V";

        case {"az", "azul", "blue"}
            codigo = "Az";

        otherwise
            error('Codigo de color no reconocido: %s', codigo);

    end

end


%% ================================================================
% CONSTRUIR MATRIZ DE CONFUSION GLOBAL
% ================================================================

function M = construir_matriz_confusion_global(tabla_global, colores)

    n = numel(colores);
    M = zeros(n, n);

    for i = 1:height(tabla_global)

        esperado = string(tabla_global.esperado(i));
        detectado = string(tabla_global.detectado(i));

        idx_esp = find(strcmp(colores, esperado), 1);
        idx_det = find(strcmp(colores, detectado), 1);

        if isempty(idx_esp) || isempty(idx_det)
            warning('Color no reconocido en fila %d: esperado=%s detectado=%s', ...
                i, esperado, detectado);
        else
            M(idx_esp, idx_det) = M(idx_esp, idx_det) + 1;
        end

    end

end


%% ================================================================
% CALCULAR RESUMEN GLOBAL
% ================================================================

function resumen = calcular_resumen_global(tabla_global, tabla_casos)

    total_casos = height(tabla_casos);

    estados = string(tabla_casos.estado);

    casos_correctos = sum(estados == "correcto");
    casos_fallidos = sum(estados == "fallo");

    stickers_totales = height(tabla_global);
    correctos_totales = sum(tabla_global.correcto);
    incorrectos_totales = stickers_totales - correctos_totales;

    accuracy_global_dataset = correctos_totales / stickers_totales;

    accuracies = tabla_casos.accuracy_global;
    accuracies = accuracies(~isnan(accuracies));

    accuracy_promedio = mean(accuracies);
    accuracy_minima = min(accuracies);
    accuracy_maxima = max(accuracies);
    desviacion_accuracy = std(accuracies);

    tiempos = tabla_casos.tiempo_segundos;
    tiempos = tiempos(~isnan(tiempos));

    tiempo_total_segundos = sum(tiempos);
    tiempo_promedio_segundos = mean(tiempos);

    resumen = table( ...
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
        desviacion_accuracy, ...
        tiempo_total_segundos, ...
        tiempo_promedio_segundos);

end


%% ================================================================
% CALCULAR METRICAS POR COLOR
% ================================================================

function metricas = calcular_metricas_por_color(M, colores)

    soporte = sum(M, 2);
    predichos = sum(M, 1)';

    correctos = diag(M);

    precision = zeros(numel(colores), 1);
    recall = zeros(numel(colores), 1);
    f1_score = zeros(numel(colores), 1);
    accuracy_color = zeros(numel(colores), 1);

    for i = 1:numel(colores)

        if soporte(i) > 0
            recall(i) = correctos(i) / soporte(i);
            accuracy_color(i) = recall(i);
        else
            recall(i) = NaN;
            accuracy_color(i) = NaN;
        end

        if predichos(i) > 0
            precision(i) = correctos(i) / predichos(i);
        else
            precision(i) = NaN;
        end

        if ~isnan(precision(i)) && ~isnan(recall(i)) && ...
           (precision(i) + recall(i)) > 0

            f1_score(i) = 2 * precision(i) * recall(i) / ...
                (precision(i) + recall(i));
        else
            f1_score(i) = NaN;
        end

    end

    metricas = table( ...
        colores(:), ...
        soporte, ...
        predichos, ...
        correctos, ...
        accuracy_color, ...
        precision, ...
        recall, ...
        f1_score, ...
        'VariableNames', { ...
            'color', ...
            'soporte', ...
            'predichos', ...
            'correctos', ...
            'accuracy', ...
            'precision', ...
            'recall', ...
            'f1_score' ...
        });

end


%% ================================================================
% CONVERTIR MATRIZ A TABLA
% ================================================================

function tabla = matriz_a_tabla(M, colores)

    nombres_columnas = matlab.lang.makeValidName(strcat('detectado_', colores));

    tabla = array2table(M, ...
        'VariableNames', nombres_columnas);

    tabla.color_esperado = colores(:);

    tabla = movevars(tabla, 'color_esperado', 'Before', 1);

end


%% ================================================================
% GRAFICO: ACCURACY POR CASO
% ================================================================

function visualizar_accuracy_por_caso(tabla_casos, cfg)

    if cfg.mostrar_figuras_fase12
        fig = figure('Name', 'Fase 12 - Accuracy por caso', ...
                     'NumberTitle', 'off');
    else
        fig = figure('Visible', 'off', ...
                     'Name', 'Fase 12 - Accuracy por caso', ...
                     'NumberTitle', 'off');
    end

    acc = tabla_casos.accuracy_global * 100;

    bar(acc);
    ylim([0 100]);
    grid on;

    xlabel('Caso');
    ylabel('Accuracy (%)');
    title('Accuracy por caso');

    xticks(1:height(tabla_casos));
    xticklabels(cellstr(tabla_casos.caso));
    xtickangle(45);

    if cfg.guardar_figuras_fase12
        saveas(fig, fullfile(cfg.fase12_dir, 'grafico_accuracy_por_caso.png'));
    end

end


%% ================================================================
% GRAFICO: MATRIZ DE CONFUSION GLOBAL
% ================================================================

function visualizar_matriz_confusion_global(M, colores, cfg)

    if cfg.mostrar_figuras_fase12
        fig = figure('Name', 'Fase 12 - Matriz de confusion global', ...
                     'NumberTitle', 'off');
    else
        fig = figure('Visible', 'off', ...
                     'Name', 'Fase 12 - Matriz de confusion global', ...
                     'NumberTitle', 'off');
    end

    imagesc(M);
    colorbar;
    axis equal tight;

    xticks(1:numel(colores));
    yticks(1:numel(colores));

    xticklabels(colores);
    yticklabels(colores);

    xlabel('Color detectado');
    ylabel('Color esperado');
    title('Matriz de confusion global');

    for i = 1:size(M, 1)
        for j = 1:size(M, 2)

            valor = M(i, j);

            text(j, i, num2str(valor), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'Color', 'black', ...
                'FontWeight', 'bold');

        end
    end

    if cfg.guardar_figuras_fase12
        saveas(fig, fullfile(cfg.fase12_dir, 'matriz_confusion_global.png'));
    end

end


%% ================================================================
% GRAFICO: METRICAS POR COLOR
% ================================================================

function visualizar_metricas_por_color(metricas_color, cfg)

    if cfg.mostrar_figuras_fase12
        fig = figure('Name', 'Fase 12 - Metricas por color', ...
                     'NumberTitle', 'off');
    else
        fig = figure('Visible', 'off', ...
                     'Name', 'Fase 12 - Metricas por color', ...
                     'NumberTitle', 'off');
    end

    datos = [
        metricas_color.precision, ...
        metricas_color.recall, ...
        metricas_color.f1_score
    ] * 100;

    bar(datos);
    ylim([0 100]);
    grid on;

    xlabel('Color');
    ylabel('Porcentaje (%)');
    title('Metricas globales por color');

    xticks(1:height(metricas_color));
    xticklabels(metricas_color.color);

    legend({'Precision', 'Recall', 'F1-score'}, ...
        'Location', 'southoutside', ...
        'Orientation', 'horizontal');

    if cfg.guardar_figuras_fase12
        saveas(fig, fullfile(cfg.fase12_dir, 'metricas_globales_por_color.png'));
    end

end