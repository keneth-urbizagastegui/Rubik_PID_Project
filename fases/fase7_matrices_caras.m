function datos = fase7_matrices_caras(datos, cfg)
% ================================================================
% FASE 7: Construcción de matrices 3x3 por cara visible
%
% Objetivo:
%   - Usar los stickers asignados geométricamente en Fase 6.
%   - Construir matrices 3x3 para cada cara visible:
%       superior, izquierda, derecha.
%   - Cada celda contiene el color detectado del sticker.
%   - Generar tablas y visualizaciones por imagen.
%
% Requiere:
%   - candidatos con campos:
%       cara
%       fila_cara
%       columna_cara
%       u_cara
%       v_cara
%       color_kmeans
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 7: Matrices 3x3 por cara\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase7(cfg);

    %% ------------------------------------------------------------
    % 1. Construir matrices de Imagen 1
    % ------------------------------------------------------------

    [matrices1, tabla1] = construir_matrices_imagen( ...
        datos.candidatos1, ...
        cfg, ...
        'Imagen 1');

    %% ------------------------------------------------------------
    % 2. Construir matrices de Imagen 2
    % ------------------------------------------------------------

    [matrices2, tabla2] = construir_matrices_imagen( ...
        datos.candidatos2, ...
        cfg, ...
        'Imagen 2');

    %% ------------------------------------------------------------
    % 3. Mostrar matrices en consola
    % ------------------------------------------------------------

    if cfg.mostrar_matrices_consola

        fprintf('\n================ MATRICES IMAGEN 1 ================\n');
        imprimir_matrices_consola(matrices1);

        fprintf('\n================ MATRICES IMAGEN 2 ================\n');
        imprimir_matrices_consola(matrices2);

    end

    %% ------------------------------------------------------------
    % 4. Visualizar matrices como gráfico
    % ------------------------------------------------------------

    if cfg.mostrar_figuras && cfg.mostrar_matrices_graficas

        visualizar_matrices_caras(matrices1, ...
            'Imagen 1 - Matrices 3x3 por cara');

        visualizar_matrices_caras(matrices2, ...
            'Imagen 2 - Matrices 3x3 por cara');

    end

    %% ------------------------------------------------------------
    % 5. Guardar tablas
    % ------------------------------------------------------------

    if cfg.guardar_matrices_caras

        guardar_tablas_matrices(tabla1, tabla2, cfg);

    end

    %% ------------------------------------------------------------
    % 6. Guardar resultados en datos
    % ------------------------------------------------------------

    datos.matrices_caras1 = matrices1;
    datos.matrices_caras2 = matrices2;

    datos.tabla_matrices_caras1 = tabla1;
    datos.tabla_matrices_caras2 = tabla2;

    %% ------------------------------------------------------------
    % 7. Resumen
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 7 ================\n');
    fprintf('Imagen 1: matrices 3x3 construidas.\n');
    fprintf('Imagen 2: matrices 3x3 construidas.\n');
    fprintf('Cada cara contiene colores ordenados por fila y columna.\n');
    fprintf('La siguiente fase puede integrar las caras visibles de ambas imágenes.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 7 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase7(cfg)

    if ~isfield(cfg, 'campo_color_final')
        cfg.campo_color_final = 'color_kmeans';
    end

    if ~isfield(cfg, 'mostrar_matrices_consola')
        cfg.mostrar_matrices_consola = true;
    end

    if ~isfield(cfg, 'mostrar_matrices_graficas')
        cfg.mostrar_matrices_graficas = true;
    end

    if ~isfield(cfg, 'guardar_matrices_caras')
        cfg.guardar_matrices_caras = true;
    end

    if ~isfield(cfg, 'matrices_dir')
        cfg.matrices_dir = fullfile(cfg.resultados_dir, 'matrices_caras');
    end

    if ~exist(cfg.matrices_dir, 'dir')
        mkdir(cfg.matrices_dir);
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Construir matrices de una imagen
% ================================================================

function [matrices, tabla_general] = construir_matrices_imagen(candidatos, cfg, nombre_img)

    fprintf('\nConstruyendo matrices 3x3 - %s\n', nombre_img);

    nombres_caras = {'superior', 'izquierda', 'derecha'};

    matrices = struct();
    tablas = cell(1, numel(nombres_caras));

    for k = 1:numel(nombres_caras)

        nombre_cara = nombres_caras{k};

        candidatos_cara = candidatos(strcmp({candidatos.cara}, nombre_cara));

        fprintf('%s - Cara %s: %d stickers\n', ...
            nombre_img, nombre_cara, numel(candidatos_cara));

        matriz_cara = construir_matriz_cara(candidatos_cara, cfg, nombre_cara);

        matrices.(nombre_cara) = matriz_cara;

        tablas{k} = matriz_cara.tabla;

    end

    tabla_general = vertcat(tablas{:});

end


%% ================================================================
% FUNCIÓN LOCAL: Construir matriz 3x3 de una cara
% ================================================================

function matriz_cara = construir_matriz_cara(candidatos_cara, cfg, nombre_cara)

    L = cfg.face_warp_size;

    colores = repmat({'vacio'}, 3, 3);
    codigos = repmat({'-'}, 3, 3);
    ids = NaN(3, 3);
    distancias = NaN(3, 3);

    n = numel(candidatos_cara);

    if n == 0

        matriz_cara.nombre = nombre_cara;
        matriz_cara.colores = colores;
        matriz_cara.codigos = codigos;
        matriz_cara.ids = ids;
        matriz_cara.distancias = distancias;
        matriz_cara.tabla = crear_tabla_vacia_cara(nombre_cara);
        return;

    end

    %% ------------------------------------------------------------
    % Centros ideales de las 9 celdas en la cara rectificada
    % ------------------------------------------------------------

    centros = zeros(9, 2);
    filas_celdas = zeros(9, 1);
    columnas_celdas = zeros(9, 1);

    contador = 0;

    for fila = 1:3
        for columna = 1:3

            contador = contador + 1;

            centros(contador, :) = [
                (columna - 0.5) * L / 3, ...
                (fila    - 0.5) * L / 3
            ];

            filas_celdas(contador) = fila;
            columnas_celdas(contador) = columna;

        end
    end

    %% ------------------------------------------------------------
    % Posiciones reales de los candidatos en la cara rectificada
    % ------------------------------------------------------------

    posiciones = zeros(n, 2);

    for i = 1:n

        if isfield(candidatos_cara, 'u_cara') && ...
           isfield(candidatos_cara, 'v_cara') && ...
           ~isnan(candidatos_cara(i).u_cara) && ...
           ~isnan(candidatos_cara(i).v_cara)

            posiciones(i, :) = [
                candidatos_cara(i).u_cara, ...
                candidatos_cara(i).v_cara
            ];

        else

            % Respaldo si no existieran u_cara/v_cara.
            posiciones(i, :) = [
                (candidatos_cara(i).columna_cara - 0.5) * L / 3, ...
                (candidatos_cara(i).fila_cara    - 0.5) * L / 3
            ];

        end

    end

    %% ------------------------------------------------------------
    % Asignación candidato-celda por distancia mínima
    % ------------------------------------------------------------

    D = zeros(n, 9);

    for i = 1:n
        for j = 1:9
            D(i, j) = norm(posiciones(i, :) - centros(j, :));
        end
    end

    usados_candidatos = false(n, 1);
    usadas_celdas = false(9, 1);

    asignacion_candidato_a_celda = NaN(n, 1);
    distancia_asignada = NaN(n, 1);

    [~, orden] = sort(D(:), 'ascend');

    for q = 1:numel(orden)

        [i, j] = ind2sub(size(D), orden(q));

        if ~usados_candidatos(i) && ~usadas_celdas(j)

            usados_candidatos(i) = true;
            usadas_celdas(j) = true;

            asignacion_candidato_a_celda(i) = j;
            distancia_asignada(i) = D(i, j);

        end

        if sum(usadas_celdas) == min(n, 9)
            break;
        end

    end

    %% ------------------------------------------------------------
    % Llenar matrices 3x3
    % ------------------------------------------------------------

    filas_tabla = [];
    columnas_tabla = [];
    ids_tabla = [];
    colores_tabla = {};
    codigos_tabla = {};
    distancias_tabla = [];
    caras_tabla = {};

    for i = 1:n

        celda = asignacion_candidato_a_celda(i);

        if isnan(celda)
            continue;
        end

        fila = filas_celdas(celda);
        columna = columnas_celdas(celda);

        color = obtener_color_candidato(candidatos_cara(i), cfg);
        color = normalizar_nombre_color(color);

        codigo = codigo_color(color);

        colores{fila, columna} = color;
        codigos{fila, columna} = codigo;
        ids(fila, columna) = candidatos_cara(i).id;
        distancias(fila, columna) = distancia_asignada(i);

        filas_tabla(end+1, 1) = fila;
        columnas_tabla(end+1, 1) = columna;
        ids_tabla(end+1, 1) = candidatos_cara(i).id;
        colores_tabla{end+1, 1} = color;
        codigos_tabla{end+1, 1} = codigo;
        distancias_tabla(end+1, 1) = distancia_asignada(i);
        caras_tabla{end+1, 1} = nombre_cara;

    end

    %% ------------------------------------------------------------
    % Crear tabla de la cara
    % ------------------------------------------------------------

    tabla = table( ...
        caras_tabla, ...
        filas_tabla, ...
        columnas_tabla, ...
        ids_tabla, ...
        colores_tabla, ...
        codigos_tabla, ...
        distancias_tabla, ...
        'VariableNames', { ...
            'cara', ...
            'fila', ...
            'columna', ...
            'id_sticker', ...
            'color', ...
            'codigo', ...
            'distancia_celda' ...
        } ...
    );

    tabla = sortrows(tabla, {'fila', 'columna'});

    %% ------------------------------------------------------------
    % Guardar salida
    % ------------------------------------------------------------

    matriz_cara.nombre = nombre_cara;
    matriz_cara.colores = colores;
    matriz_cara.codigos = codigos;
    matriz_cara.ids = ids;
    matriz_cara.distancias = distancias;
    matriz_cara.tabla = tabla;

end


%% ================================================================
% FUNCIÓN LOCAL: Obtener color final del candidato
% ================================================================

function color = obtener_color_candidato(candidato, cfg)

    if isfield(candidato, cfg.campo_color_final)

        color = candidato.(cfg.campo_color_final);

    elseif isfield(candidato, 'color_kmeans')

        color = candidato.color_kmeans;

    else

        color = candidato.color_pre_hsv;

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Normalizar nombre de color
% ================================================================

function color = normalizar_nombre_color(color)

    if iscell(color)
        color = color{1};
    end

    if isstring(color)
        color = char(color);
    end

    color = lower(strtrim(color));

    switch color
        case {'red', 'rojo'}
            color = 'rojo';
        case {'orange', 'naranja'}
            color = 'naranja';
        case {'yellow', 'amarillo'}
            color = 'amarillo';
        case {'green', 'verde'}
            color = 'verde';
        case {'blue', 'azul'}
            color = 'azul';
        case {'white', 'blanco'}
            color = 'blanco';
        otherwise
            color = 'indefinido';
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Código corto para color
% ================================================================

function codigo = codigo_color(color)

    switch color
        case 'rojo'
            codigo = 'R';
        case 'naranja'
            codigo = 'N';
        case 'amarillo'
            codigo = 'A';
        case 'verde'
            codigo = 'V';
        case 'azul'
            codigo = 'Az';
        case 'blanco'
            codigo = 'B';
        case 'vacio'
            codigo = '-';
        otherwise
            codigo = '?';
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Crear tabla vacía
% ================================================================

function tabla = crear_tabla_vacia_cara(nombre_cara)

    tabla = table( ...
        {nombre_cara}, ...
        NaN, ...
        NaN, ...
        NaN, ...
        {'vacio'}, ...
        {'-'}, ...
        NaN, ...
        'VariableNames', { ...
            'cara', ...
            'fila', ...
            'columna', ...
            'id_sticker', ...
            'color', ...
            'codigo', ...
            'distancia_celda' ...
        } ...
    );

end


%% ================================================================
% FUNCIÓN LOCAL: Imprimir matrices en consola
% ================================================================

function imprimir_matrices_consola(matrices)

    nombres_caras = {'superior', 'izquierda', 'derecha'};

    for k = 1:numel(nombres_caras)

        nombre_cara = nombres_caras{k};

        fprintf('\nCara %s:\n', upper(nombre_cara));

        codigos = matrices.(nombre_cara).codigos;

        for fila = 1:3

            fprintf('[ ');

            for columna = 1:3

                fprintf('%3s ', codigos{fila, columna});

            end

            fprintf(']\n');

        end

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar matrices 3x3
% ================================================================

function visualizar_matrices_caras(matrices, titulo_figura)

    nombres_caras = {'superior', 'izquierda', 'derecha'};
    titulos = {'Superior', 'Izquierda', 'Derecha'};

    figure('Name', titulo_figura, 'NumberTitle', 'off');

    for k = 1:numel(nombres_caras)

        nombre_cara = nombres_caras{k};

        subplot(1, 3, k);
        hold on;
        axis equal;
        axis ij;
        axis off;

        title(titulos{k});

        xlim([0 3]);
        ylim([0 3]);

        colores = matrices.(nombre_cara).colores;
        codigos = matrices.(nombre_cara).codigos;
        ids = matrices.(nombre_cara).ids;

        for fila = 1:3
            for columna = 1:3

                color_nombre = colores{fila, columna};
                rgb = rgb_color(color_nombre);

                rectangle('Position', [columna-1, fila-1, 1, 1], ...
                    'FaceColor', rgb, ...
                    'EdgeColor', 'black', ...
                    'LineWidth', 2);

                if isnan(ids(fila, columna))
                    texto = codigos{fila, columna};
                else
                    texto = sprintf('%s\nID %d', ...
                        codigos{fila, columna}, ...
                        ids(fila, columna));
                end

                text(columna - 0.5, fila - 0.5, texto, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 10, ...
                    'Color', color_texto(rgb));

            end
        end

        hold off;

    end

end


%% ================================================================
% FUNCIÓN LOCAL: RGB para visualización
% ================================================================

function rgb = rgb_color(color)

    switch color
        case 'rojo'
            rgb = [1.00 0.00 0.00];
        case 'naranja'
            rgb = [1.00 0.50 0.00];
        case 'amarillo'
            rgb = [1.00 1.00 0.00];
        case 'verde'
            rgb = [0.00 0.75 0.25];
        case 'azul'
            rgb = [0.00 0.20 1.00];
        case 'blanco'
            rgb = [1.00 1.00 1.00];
        otherwise
            rgb = [0.60 0.60 0.60];
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Color del texto según fondo
% ================================================================

function c = color_texto(rgb)

    brillo = 0.299 * rgb(1) + 0.587 * rgb(2) + 0.114 * rgb(3);

    if brillo > 0.60
        c = 'black';
    else
        c = 'white';
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Guardar tablas de matrices
% ================================================================

function guardar_tablas_matrices(tabla1, tabla2, cfg)

    ruta1 = fullfile(cfg.matrices_dir, 'matrices_caras_imagen1.csv');
    ruta2 = fullfile(cfg.matrices_dir, 'matrices_caras_imagen2.csv');

    writetable(tabla1, ruta1);
    writetable(tabla2, ruta2);

    fprintf('\nTablas de matrices guardadas en:\n');
    fprintf('%s\n', ruta1);
    fprintf('%s\n', ruta2);

end