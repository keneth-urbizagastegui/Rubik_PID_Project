function datos = fase9_evaluacion_cubo(datos, cfg)
% ================================================================
% FASE 9: Evaluacion cuantitativa del cubo reconstruido
%
% Objetivo:
%   - Comparar el cubo integrado con una referencia manual.
%   - Calcular accuracy global.
%   - Calcular accuracy por color.
%   - Construir matriz de confusion.
%   - Validar conteo de colores.
%
% Nota:
%   El ground truth incluido corresponde a la inspeccion visual de las
%   matrices obtenidas en las fases anteriores. Si se usan otras imagenes,
%   se debe actualizar la funcion crear_ground_truth_manual().
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 9: Evaluacion cuantitativa\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase9(cfg);

    if ~cfg.evaluar_cubo
        fprintf('Evaluacion desactivada en configuracion.\n');
        return;
    end

    %% ------------------------------------------------------------
    % 1. Leer ground truth desde CSV del caso actual
    % ------------------------------------------------------------

    if ~isfield(cfg, 'ground_truth_path') || isempty(cfg.ground_truth_path)
        error('No existe cfg.ground_truth_path. Revisa config_rubik.m.');
    end

    if ~exist(cfg.ground_truth_path, 'file')
        error('No se encontro el archivo ground truth: %s', cfg.ground_truth_path);
    end

    fprintf('\nLeyendo ground truth desde:\n%s\n', cfg.ground_truth_path);

    tabla_gt = leer_ground_truth_csv(cfg.ground_truth_path);

    fprintf('Ground truth leido correctamente: %d filas.\n', height(tabla_gt));

    %% ------------------------------------------------------------
    % 2. Extraer etiquetas reales y predichas usando cara-fila-columna
    % ------------------------------------------------------------

    [y_true, y_pred, tabla_comparacion] = comparar_cubo_con_ground_truth_csv( ...
        tabla_gt, ...
        datos.cubo_integrado, ...
        cfg);

    %% ================================================================
    % FUNCION LOCAL: Leer ground truth desde CSV
    % ================================================================
    
    function tabla_gt = leer_ground_truth_csv(ruta_csv)
    
        tabla_gt = readtable(ruta_csv, ...
            'Delimiter', ',', ...
            'TextType', 'string');
    
        nombres = lower(string(tabla_gt.Properties.VariableNames));
    
        idx_cara = find(nombres == "cara", 1);
        idx_fila = find(nombres == "fila", 1);
        idx_columna = find(nombres == "columna", 1);
        idx_color = find(nombres == "color", 1);
    
        if isempty(idx_cara) || isempty(idx_fila) || isempty(idx_columna) || isempty(idx_color)
            error('El CSV debe tener las columnas: cara, fila, columna, color.');
        end
    
        tabla_gt = tabla_gt(:, [idx_cara, idx_fila, idx_columna, idx_color]);
        tabla_gt.Properties.VariableNames = {'cara', 'fila', 'columna', 'color'};
    
        tabla_gt.cara = lower(strtrim(string(tabla_gt.cara)));
        tabla_gt.color = strtrim(string(tabla_gt.color));
    
        tabla_gt.cara = erase(tabla_gt.cara, '"');
        tabla_gt.color = erase(tabla_gt.color, '"');
    
        if ~isnumeric(tabla_gt.fila)
            tabla_gt.fila = str2double(string(tabla_gt.fila));
        end
    
        if ~isnumeric(tabla_gt.columna)
            tabla_gt.columna = str2double(string(tabla_gt.columna));
        end
    
        if any(isnan(tabla_gt.fila)) || any(isnan(tabla_gt.columna))
            error('Existen valores no numericos en fila o columna del ground truth.');
        end
    
    end
    
    
    %% ================================================================
    % FUNCION LOCAL: Comparar cubo detectado con ground truth CSV
    % ================================================================
    
    function [y_true, y_pred, tabla] = comparar_cubo_con_ground_truth_csv(tabla_gt, cubo_pred, cfg)
    
        n = height(tabla_gt);
    
        y_true = {};
        y_pred = {};
    
        cara_tabla = {};
        fila_tabla = [];
        columna_tabla = [];
        esperado_tabla = {};
        detectado_tabla = {};
        correcto_tabla = [];
    
        for i = 1:n
    
            cara = char(lower(strtrim(string(tabla_gt.cara(i)))));
            fila = tabla_gt.fila(i);
            columna = tabla_gt.columna(i);
    
            esperado = normalizar_codigo(tabla_gt.color(i));
    
            if ~isfield(cubo_pred, cara)
                error('La cara "%s" no existe en datos.cubo_integrado.', cara);
            end
    
            matriz_pred = obtener_matriz_codigos_cara(cubo_pred, cara);
    
            if fila < 1 || fila > 3 || columna < 1 || columna > 3
                error('Indice fuera de rango en ground truth: cara=%s, fila=%d, columna=%d.', ...
                    cara, fila, columna);
            end
    
            detectado = normalizar_codigo(matriz_pred{fila, columna});
    
            y_true{end+1, 1} = esperado;
            y_pred{end+1, 1} = detectado;
    
            cara_tabla{end+1, 1} = cara;
            fila_tabla(end+1, 1) = fila;
            columna_tabla(end+1, 1) = columna;
            esperado_tabla{end+1, 1} = esperado;
            detectado_tabla{end+1, 1} = detectado;
            correcto_tabla(end+1, 1) = strcmp(esperado, detectado);
    
        end
    
        tabla = table( ...
            cara_tabla, ...
            fila_tabla, ...
            columna_tabla, ...
            esperado_tabla, ...
            detectado_tabla, ...
            correcto_tabla, ...
            'VariableNames', { ...
                'cara', ...
                'fila', ...
                'columna', ...
                'esperado', ...
                'detectado', ...
                'correcto' ...
            } ...
        );
    
    end
    
    
    %% ================================================================
    % FUNCION LOCAL: Obtener matriz de codigos de una cara integrada
    % ================================================================
    
    function matriz = obtener_matriz_codigos_cara(cubo_pred, cara)
    
        entrada = cubo_pred.(cara);
    
        if isstruct(entrada)
    
            if isfield(entrada, 'codigos')
                matriz = entrada.codigos;
    
            elseif isfield(entrada, 'matriz')
                matriz = entrada.matriz;
    
            elseif isfield(entrada, 'matriz_colores')
                matriz = entrada.matriz_colores;
    
            elseif isfield(entrada, 'colores')
                matriz = entrada.colores;
    
            else
                error('La cara "%s" no contiene codigos, matriz, matriz_colores ni colores.', cara);
            end
    
        else
            matriz = entrada;
        end
    
        if isstring(matriz)
            matriz = cellstr(matriz);
        end
    
        if istable(matriz)
            matriz = table2cell(matriz);
        end
    
        if ~iscell(matriz)
            error('La matriz de la cara "%s" debe ser cell, string o table.', cara);
        end
    
        if ~isequal(size(matriz), [3 3])
            error('La matriz de la cara "%s" no es 3x3. Tamano detectado: %dx%d.', ...
                cara, size(matriz, 1), size(matriz, 2));
        end
    
    end
    
    %% ------------------------------------------------------------
    % 3. Calcular metricas
    % ------------------------------------------------------------

    metricas = calcular_metricas(y_true, y_pred, cfg);

    %% ------------------------------------------------------------
    % 4. Validar conteo de colores
    % ------------------------------------------------------------

    tabla_conteo = validar_conteo_colores(y_true, y_pred, cfg);

    %% ------------------------------------------------------------
    % 5. Mostrar resultados
    % ------------------------------------------------------------

    if cfg.mostrar_metricas_consola

        imprimir_resultados_evaluacion(metricas, tabla_conteo);

        fprintf('\nTabla de comparacion celda por celda:\n');
        disp(tabla_comparacion);

    end

    %% ------------------------------------------------------------
    % 6. Visualizar matriz de confusion
    % ------------------------------------------------------------

    if cfg.mostrar_figuras && cfg.mostrar_matriz_confusion

        visualizar_matriz_confusion(metricas, ...
            'Fase 9 - Matriz de confusion');

    end

    %% ------------------------------------------------------------
    % 7. Guardar resultados
    % ------------------------------------------------------------

    if cfg.guardar_evaluacion

        guardar_resultados_evaluacion( ...
            metricas, ...
            tabla_conteo, ...
            tabla_comparacion, ...
            cfg);

    end

    %% ------------------------------------------------------------
    % 8. Guardar en datos
    % ------------------------------------------------------------

    datos.ground_truth_cubo = tabla_gt;
    datos.y_true_cubo = y_true;
    datos.y_pred_cubo = y_pred;
    datos.metricas_evaluacion = metricas;
    datos.tabla_conteo_colores = tabla_conteo;
    datos.tabla_comparacion_cubo = tabla_comparacion;

    %% ------------------------------------------------------------
    % 9. Resumen
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 9 ================\n');
    fprintf('Accuracy global: %.2f %%\n', metricas.accuracy_global * 100);
    fprintf('Total de stickers evaluados: %d\n', numel(y_true));
    fprintf('Stickers correctos: %d\n', metricas.total_correctos);
    fprintf('Stickers incorrectos: %d\n', metricas.total_incorrectos);
    fprintf('=================================================\n');

    fprintf('\nFASE 9 finalizada correctamente.\n');

end


%% ================================================================
% FUNCION LOCAL: Completar configuracion
% ================================================================

function cfg = completar_cfg_fase9(cfg)

    if ~isfield(cfg, 'evaluar_cubo')
        cfg.evaluar_cubo = true;
    end

    if ~isfield(cfg, 'mostrar_metricas_consola')
        cfg.mostrar_metricas_consola = true;
    end

    if ~isfield(cfg, 'mostrar_matriz_confusion')
        cfg.mostrar_matriz_confusion = true;
    end

    if ~isfield(cfg, 'guardar_evaluacion')
        cfg.guardar_evaluacion = true;
    end

    if ~isfield(cfg, 'evaluacion_dir')
        cfg.evaluacion_dir = fullfile(cfg.resultados_dir, 'evaluacion');
    end

    if ~exist(cfg.evaluacion_dir, 'dir')
        mkdir(cfg.evaluacion_dir);
    end

    if ~isfield(cfg, 'colores_cubo')
        cfg.colores_cubo = {'blanco', 'amarillo', 'rojo', 'naranja', 'verde', 'azul'};
    end

end


%% ================================================================
% FUNCION LOCAL: Ground truth manual
% ================================================================

function cubo_gt = crear_ground_truth_manual()
% ================================================================
% Referencia manual del cubo.
%
% Codigos:
%   B  = blanco
%   A  = amarillo
%   R  = rojo
%   N  = naranja
%   V  = verde
%   Az = azul
% ================================================================

    cubo_gt = struct();

    cubo_gt.blanco = {
        'N',  'Az', 'N';
        'A',  'B',  'A';
        'R',  'V',  'R'
    };

    cubo_gt.amarillo = {
        'N',  'B',  'R';
        'V',  'A',  'Az';
        'N',  'B',  'R'
    };

    cubo_gt.rojo = {
        'V',  'N',  'Az';
        'B',  'R',  'A';
        'V',  'N',  'Az'
    };

    cubo_gt.naranja = {
        'V',  'R',  'Az';
        'A',  'N',  'B';
        'V',  'R',  'Az'
    };

    cubo_gt.verde = {
        'B',  'R',  'B';
        'Az', 'V',  'Az';
        'A',  'N',  'A'
    };

    cubo_gt.azul = {
        'A',  'R',  'A';
        'V',  'Az', 'V';
        'B',  'N',  'B'
    };

end


%% ================================================================
% FUNCION LOCAL: Comparar cubo detectado contra ground truth
% ================================================================

function [y_true, y_pred, tabla] = comparar_cubo_con_ground_truth(cubo_gt, cubo_pred, cfg)

    colores_caras = cfg.colores_cubo;

    y_true = {};
    y_pred = {};

    cara_tabla = {};
    fila_tabla = [];
    columna_tabla = [];
    esperado_tabla = {};
    detectado_tabla = {};
    correcto_tabla = [];

    for c = 1:numel(colores_caras)

        cara = colores_caras{c};

        matriz_gt = cubo_gt.(cara);
        matriz_pred = cubo_pred.(cara).codigos;

        for fila = 1:3
            for columna = 1:3

                esperado = normalizar_codigo(matriz_gt{fila, columna});
                detectado = normalizar_codigo(matriz_pred{fila, columna});

                y_true{end+1, 1} = esperado;
                y_pred{end+1, 1} = detectado;

                cara_tabla{end+1, 1} = cara;
                fila_tabla(end+1, 1) = fila;
                columna_tabla(end+1, 1) = columna;
                esperado_tabla{end+1, 1} = esperado;
                detectado_tabla{end+1, 1} = detectado;
                correcto_tabla(end+1, 1) = strcmp(esperado, detectado);

            end
        end
    end

    tabla = table( ...
        cara_tabla, ...
        fila_tabla, ...
        columna_tabla, ...
        esperado_tabla, ...
        detectado_tabla, ...
        correcto_tabla, ...
        'VariableNames', { ...
            'cara', ...
            'fila', ...
            'columna', ...
            'esperado', ...
            'detectado', ...
            'correcto' ...
        } ...
    );

end


%% ================================================================
% FUNCION LOCAL: Calcular metricas
% ================================================================

function metricas = calcular_metricas(y_true, y_pred, cfg)

    etiquetas = {'B', 'A', 'R', 'N', 'V', 'Az'};

    n = numel(y_true);

    correctos = strcmp(y_true, y_pred);

    accuracy_global = sum(correctos) / n;

    matriz_confusion = zeros(numel(etiquetas), numel(etiquetas));

    for i = 1:n

        idx_true = find(strcmp(etiquetas, y_true{i}));
        idx_pred = find(strcmp(etiquetas, y_pred{i}));

        if isempty(idx_true)
            continue;
        end

        if isempty(idx_pred)
            continue;
        end

        matriz_confusion(idx_true, idx_pred) = ...
            matriz_confusion(idx_true, idx_pred) + 1;

    end

    color_tabla = {};
    soporte_tabla = [];
    correctos_tabla = [];
    accuracy_tabla = [];
    precision_tabla = [];
    recall_tabla = [];
    f1_tabla = [];

    for k = 1:numel(etiquetas)

        etiqueta = etiquetas{k};

        soporte = sum(strcmp(y_true, etiqueta));
        correctos_color = matriz_confusion(k, k);

        total_predicho_color = sum(matriz_confusion(:, k));
        total_real_color = sum(matriz_confusion(k, :));

        if soporte > 0
            accuracy_color = correctos_color / soporte;
        else
            accuracy_color = NaN;
        end

        if total_predicho_color > 0
            precision = correctos_color / total_predicho_color;
        else
            precision = NaN;
        end

        if total_real_color > 0
            recall = correctos_color / total_real_color;
        else
            recall = NaN;
        end

        if ~isnan(precision) && ~isnan(recall) && (precision + recall) > 0
            f1 = 2 * precision * recall / (precision + recall);
        else
            f1 = NaN;
        end

        color_tabla{end+1,1} = etiqueta;
        soporte_tabla(end+1,1) = soporte;
        correctos_tabla(end+1,1) = correctos_color;
        accuracy_tabla(end+1,1) = accuracy_color;
        precision_tabla(end+1,1) = precision;
        recall_tabla(end+1,1) = recall;
        f1_tabla(end+1,1) = f1;

    end

    tabla_por_color = table( ...
        color_tabla, ...
        soporte_tabla, ...
        correctos_tabla, ...
        accuracy_tabla, ...
        precision_tabla, ...
        recall_tabla, ...
        f1_tabla, ...
        'VariableNames', { ...
            'color', ...
            'soporte', ...
            'correctos', ...
            'accuracy', ...
            'precision', ...
            'recall', ...
            'f1_score' ...
        } ...
    );

    metricas = struct();

    metricas.etiquetas = etiquetas;
    metricas.matriz_confusion = matriz_confusion;
    metricas.accuracy_global = accuracy_global;
    metricas.total_stickers = n;
    metricas.total_correctos = sum(correctos);
    metricas.total_incorrectos = n - sum(correctos);
    metricas.tabla_por_color = tabla_por_color;

end


%% ================================================================
% FUNCION LOCAL: Validar conteo de colores
% ================================================================

function tabla_conteo = validar_conteo_colores(y_true, y_pred, cfg)

    etiquetas = {'B', 'A', 'R', 'N', 'V', 'Az'};

    color_tabla = {};
    esperado_tabla = [];
    detectado_tabla = [];
    diferencia_tabla = [];
    estado_tabla = {};

    for k = 1:numel(etiquetas)

        etiqueta = etiquetas{k};

        esperado = sum(strcmp(y_true, etiqueta));
        detectado = sum(strcmp(y_pred, etiqueta));
        diferencia = detectado - esperado;

        if diferencia == 0
            estado = 'correcto';
        else
            estado = 'revisar';
        end

        color_tabla{end+1,1} = etiqueta;
        esperado_tabla(end+1,1) = esperado;
        detectado_tabla(end+1,1) = detectado;
        diferencia_tabla(end+1,1) = diferencia;
        estado_tabla{end+1,1} = estado;

    end

    tabla_conteo = table( ...
        color_tabla, ...
        esperado_tabla, ...
        detectado_tabla, ...
        diferencia_tabla, ...
        estado_tabla, ...
        'VariableNames', { ...
            'color', ...
            'conteo_esperado', ...
            'conteo_detectado', ...
            'diferencia', ...
            'estado' ...
        } ...
    );

end


%% ================================================================
% FUNCION LOCAL: Imprimir resultados
% ================================================================

function imprimir_resultados_evaluacion(metricas, tabla_conteo)

    fprintf('\n================ METRICAS DE EVALUACION ================\n');

    fprintf('Total de stickers evaluados: %d\n', metricas.total_stickers);
    fprintf('Correctos: %d\n', metricas.total_correctos);
    fprintf('Incorrectos: %d\n', metricas.total_incorrectos);
    fprintf('Accuracy global: %.2f %%\n', metricas.accuracy_global * 100);

    fprintf('\nMetricas por color:\n');
    disp(metricas.tabla_por_color);

    fprintf('\nConteo de colores:\n');
    disp(tabla_conteo);

    fprintf('\nMatriz de confusion:\n');
    disp(array2table(metricas.matriz_confusion, ...
        'VariableNames', metricas.etiquetas, ...
        'RowNames', metricas.etiquetas));

end


%% ================================================================
% FUNCION LOCAL: Visualizar matriz de confusion
% ================================================================

function visualizar_matriz_confusion(metricas, titulo_figura)

    figure('Name', titulo_figura, 'NumberTitle', 'off');

    imagesc(metricas.matriz_confusion);
    axis equal tight;

    colormap(parula);
    colorbar;

    title(titulo_figura);

    etiquetas = metricas.etiquetas;

    set(gca, 'XTick', 1:numel(etiquetas), 'XTickLabel', etiquetas);
    set(gca, 'YTick', 1:numel(etiquetas), 'YTickLabel', etiquetas);

    xlabel('Color detectado');
    ylabel('Color esperado');

    for i = 1:size(metricas.matriz_confusion, 1)
        for j = 1:size(metricas.matriz_confusion, 2)

            valor = metricas.matriz_confusion(i, j);

            text(j, i, num2str(valor), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', ...
                'Color', 'black');

        end
    end

end


%% ================================================================
% FUNCION LOCAL: Guardar resultados
% ================================================================

function guardar_resultados_evaluacion(metricas, tabla_conteo, tabla_comparacion, cfg)

    ruta_metricas = fullfile(cfg.evaluacion_dir, 'metricas_por_color.csv');
    ruta_conteo = fullfile(cfg.evaluacion_dir, 'conteo_colores.csv');
    ruta_comparacion = fullfile(cfg.evaluacion_dir, 'comparacion_celda_por_celda.csv');
    ruta_mat = fullfile(cfg.evaluacion_dir, 'metricas_evaluacion.mat');

    writetable(metricas.tabla_por_color, ruta_metricas);
    writetable(tabla_conteo, ruta_conteo);
    writetable(tabla_comparacion, ruta_comparacion);

    save(ruta_mat, 'metricas', 'tabla_conteo', 'tabla_comparacion');

    fprintf('\nResultados de evaluacion guardados en:\n');
    fprintf('%s\n', ruta_metricas);
    fprintf('%s\n', ruta_conteo);
    fprintf('%s\n', ruta_comparacion);
    fprintf('%s\n', ruta_mat);

end


%% ================================================================
% FUNCION LOCAL: Normalizar codigos
% ================================================================

function codigo = normalizar_codigo(codigo)

    if iscell(codigo)
        codigo = codigo{1};
    end

    if iscategorical(codigo)
        codigo = string(codigo);
    end

    if isnumeric(codigo)
        codigo = string(codigo);
    end

    if isstring(codigo)
        codigo = char(codigo);
    end

    codigo = strtrim(codigo);
    codigo = erase(codigo, '"');

    switch lower(codigo)
        case {'b', 'blanco', 'white'}
            codigo = 'B';

        case {'a', 'amarillo', 'yellow'}
            codigo = 'A';

        case {'r', 'rojo', 'red'}
            codigo = 'R';

        case {'n', 'naranja', 'orange'}
            codigo = 'N';

        case {'v', 'verde', 'green'}
            codigo = 'V';

        case {'az', 'azul', 'blue'}
            codigo = 'Az';

        otherwise
            error('Codigo de color no reconocido: %s', codigo);
    end

end