function datos = fase6_agrupacion_caras(datos, cfg)
% ================================================================
% FASE 6: Agrupación de stickers por caras visibles
%
% Versión corregida para el pipeline geométrico.
%
% Esta fase NO vuelve a detectar polígonos.
% Esta fase NO vuelve a aplicar Hough.
% Esta fase NO vuelve a seleccionar esquinas.
%
% Entrada principal:
%   datos.candidatos1
%   datos.candidatos2
%
% Cada candidato debe venir desde Fase 5 con:
%   - cara_geometrica
%   - fila_geometrica
%   - columna_geometrica
%   - color_kmeans
%
% Salida:
%   - datos.caras1
%   - datos.caras2
%   - datos.tabla_caras1
%   - datos.tabla_caras2
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 6: Agrupacion por caras visibles\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase6(cfg);

    %% ------------------------------------------------------------
    % 1. Verificar entradas de Fase 5
    % ------------------------------------------------------------

    if ~isfield(datos, 'candidatos1')
        error('No existe datos.candidatos1. Ejecuta primero la Fase 5.');
    end

    if ~isfield(datos, 'candidatos2')
        error('No existe datos.candidatos2. Ejecuta primero la Fase 5.');
    end

    %% ------------------------------------------------------------
    % 2. Procesar Imagen 1
    % ------------------------------------------------------------

    fprintf('\nAgrupando candidatos por cara - Imagen 1\n');

    [candidatos1, caras1, tabla1] = agrupar_imagen_por_caras( ...
        datos.candidatos1, ...
        cfg, ...
        'Imagen 1');

    %% ------------------------------------------------------------
    % 3. Procesar Imagen 2
    % ------------------------------------------------------------

    fprintf('\nAgrupando candidatos por cara - Imagen 2\n');

    [candidatos2, caras2, tabla2] = agrupar_imagen_por_caras( ...
        datos.candidatos2, ...
        cfg, ...
        'Imagen 2');

    %% ------------------------------------------------------------
    % 4. Visualización
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        visualizar_agrupacion_caras( ...
            datos.img1_roi, ...
            candidatos1, ...
            'Imagen 1 - Agrupacion por caras visibles');

        visualizar_agrupacion_caras( ...
            datos.img2_roi, ...
            candidatos2, ...
            'Imagen 2 - Agrupacion por caras visibles');

    end

    %% ------------------------------------------------------------
    % 5. Guardar resultados principales
    % ------------------------------------------------------------

    datos.candidatos1 = candidatos1;
    datos.candidatos2 = candidatos2;

    datos.candidatos1_asignados = candidatos1;
    datos.candidatos2_asignados = candidatos2;

    datos.caras1 = caras1;
    datos.caras2 = caras2;

    datos.caras_img1 = caras1;
    datos.caras_img2 = caras2;

    datos.tabla_caras1 = tabla1;
    datos.tabla_caras2 = tabla2;

    datos.tabla_agrupacion_img1 = tabla1;
    datos.tabla_agrupacion_img2 = tabla2;

    % Conservar polígonos generados en Fase 5 si existen.
    if isfield(datos, 'poligonos_caras1_fase5')
        datos.poligonos_caras1 = datos.poligonos_caras1_fase5;
    end

    if isfield(datos, 'poligonos_caras2_fase5')
        datos.poligonos_caras2 = datos.poligonos_caras2_fase5;
    end

    %% ------------------------------------------------------------
    % 6. Guardar CSV
    % ------------------------------------------------------------

    if cfg.guardar_agrupacion_caras

        if ~exist(cfg.agrupacion_caras_dir, 'dir')
            mkdir(cfg.agrupacion_caras_dir);
        end

        writetable(tabla1, ...
            fullfile(cfg.agrupacion_caras_dir, 'agrupacion_caras_imagen1.csv'));

        writetable(tabla2, ...
            fullfile(cfg.agrupacion_caras_dir, 'agrupacion_caras_imagen2.csv'));

    end

    %% ------------------------------------------------------------
    % 7. Resumen
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 6 ================\n');

    fprintf('\nImagen 1:\n');
    imprimir_resumen_caras(caras1);

    fprintf('\nImagen 2:\n');
    imprimir_resumen_caras(caras2);

    fprintf('\nObservaciones:\n');
    fprintf('1. La Fase 6 uso la geometria generada en Fase 5.\n');
    fprintf('2. No se volvio a ejecutar Hough ni seleccion manual.\n');
    fprintf('3. Cada candidato conserva cara, fila, columna y color final.\n');
    fprintf('4. La siguiente fase puede construir matrices 3x3 por cara.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 6 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase6(cfg)

    if ~isfield(cfg, 'num_caras_visibles')
        cfg.num_caras_visibles = 3;
    end

    if ~isfield(cfg, 'stickers_por_cara')
        cfg.stickers_por_cara = 9;
    end

    if ~isfield(cfg, 'grid_n')
        cfg.grid_n = 3;
    end

    if ~isfield(cfg, 'guardar_agrupacion_caras')
        cfg.guardar_agrupacion_caras = true;
    end

    if ~isfield(cfg, 'resultados_dir')
        cfg.resultados_dir = 'resultados';
    end

    if ~isfield(cfg, 'agrupacion_caras_dir')
        cfg.agrupacion_caras_dir = fullfile(cfg.resultados_dir, 'agrupacion_caras');
    end

    if ~exist(cfg.agrupacion_caras_dir, 'dir')
        mkdir(cfg.agrupacion_caras_dir);
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Agrupar una imagen por caras
% ================================================================

function [candidatos_out, caras, tabla] = agrupar_imagen_por_caras(candidatos, cfg, nombre_img)

    if isempty(candidatos)
        error('%s: no hay candidatos para agrupar.', nombre_img);
    end

    campos_requeridos = { ...
        'cara_geometrica', ...
        'fila_geometrica', ...
        'columna_geometrica', ...
        'color_kmeans'};

    for k = 1:numel(campos_requeridos)

        campo = campos_requeridos{k};

        if ~isfield(candidatos, campo)
            error('%s: falta el campo "%s" en los candidatos. Revisa Fase 5.', ...
                nombre_img, campo);
        end

    end

    %% ------------------------------------------------------------
    % 1. Normalizar campos para compatibilidad con Fase 7
    % ------------------------------------------------------------

    candidatos_out = candidatos;

    for i = 1:numel(candidatos_out)

        candidatos_out(i).cara = candidatos_out(i).cara_geometrica;
        candidatos_out(i).fila_cara = candidatos_out(i).fila_geometrica;
        candidatos_out(i).columna_cara = candidatos_out(i).columna_geometrica;

        candidatos_out(i).fila = candidatos_out(i).fila_geometrica;
        candidatos_out(i).columna = candidatos_out(i).columna_geometrica;

        candidatos_out(i).color_final = candidatos_out(i).color_kmeans;

    end

    %% ------------------------------------------------------------
    % 2. Crear estructura por caras
    % ------------------------------------------------------------

    caras = crear_estructura_caras(candidatos_out);

    %% ------------------------------------------------------------
    % 3. Validar conteo y grilla
    % ------------------------------------------------------------

    validar_conteo_caras(caras, cfg, nombre_img);
    validar_grillas_caras(caras, cfg, nombre_img);

    %% ------------------------------------------------------------
    % 4. Crear tabla
    % ------------------------------------------------------------

    tabla = crear_tabla_agrupacion(candidatos_out);

end


%% ================================================================
% FUNCIÓN LOCAL: Crear estructura por caras
% ================================================================

function caras = crear_estructura_caras(candidatos)

    nombres_caras = {'superior', 'izquierda', 'derecha'};

    caras = struct();

    for k = 1:numel(nombres_caras)

        cara = nombres_caras{k};

        idx = strcmp({candidatos.cara}, cara);

        candidatos_cara = candidatos(idx);

        candidatos_cara = ordenar_candidatos_cara(candidatos_cara);

        caras.(cara) = candidatos_cara;

    end

    caras.num_superior  = numel(caras.superior);
    caras.num_izquierda = numel(caras.izquierda);
    caras.num_derecha   = numel(caras.derecha);

end


%% ================================================================
% FUNCIÓN LOCAL: Ordenar candidatos dentro de una cara
% ================================================================

function candidatos_cara = ordenar_candidatos_cara(candidatos_cara)

    if isempty(candidatos_cara)
        return;
    end

    filas = [candidatos_cara.fila_cara]';
    columnas = [candidatos_cara.columna_cara]';

    [~, orden] = sortrows([filas, columnas], [1 2]);

    candidatos_cara = candidatos_cara(orden);

end


%% ================================================================
% FUNCIÓN LOCAL: Validar conteo por cara
% ================================================================

function validar_conteo_caras(caras, cfg, nombre_img)

    fprintf('\nConteo por caras - %s:\n', nombre_img);
    fprintf('Superior:  %d stickers\n', caras.num_superior);
    fprintf('Izquierda: %d stickers\n', caras.num_izquierda);
    fprintf('Derecha:   %d stickers\n', caras.num_derecha);

    if caras.num_superior ~= cfg.stickers_por_cara || ...
       caras.num_izquierda ~= cfg.stickers_por_cara || ...
       caras.num_derecha ~= cfg.stickers_por_cara

        warning('%s no tiene exactamente 9 stickers por cara.', nombre_img);

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Validar grilla 3x3
% ================================================================

function validar_grillas_caras(caras, cfg, nombre_img)

    nombres_caras = {'superior', 'izquierda', 'derecha'};
    N = cfg.grid_n;

    for k = 1:numel(nombres_caras)

        cara = nombres_caras{k};
        candidatos_cara = caras.(cara);

        ocupacion = zeros(N, N);

        for i = 1:numel(candidatos_cara)

            f = candidatos_cara(i).fila_cara;
            c = candidatos_cara(i).columna_cara;

            if f >= 1 && f <= N && c >= 1 && c <= N
                ocupacion(f, c) = ocupacion(f, c) + 1;
            end

        end

        faltantes = sum(ocupacion(:) == 0);
        duplicados = sum(ocupacion(:) > 1);

        if faltantes == 0 && duplicados == 0

            fprintf('%s - Cara %s: grilla 3x3 completa.\n', nombre_img, cara);

        else

            warning('%s - Cara %s: faltantes=%d, duplicados=%d.', ...
                nombre_img, cara, faltantes, duplicados);

        end

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Crear tabla de agrupación
% ================================================================

function tabla = crear_tabla_agrupacion(candidatos)

    n = numel(candidatos);

    id = zeros(n, 1);
    cara = strings(n, 1);
    fila = zeros(n, 1);
    columna = zeros(n, 1);
    color = strings(n, 1);
    cluster = zeros(n, 1);

    centroid_x = zeros(n, 1);
    centroid_y = zeros(n, 1);

    bbox_x = zeros(n, 1);
    bbox_y = zeros(n, 1);
    bbox_w = zeros(n, 1);
    bbox_h = zeros(n, 1);

    meanH = zeros(n, 1);
    meanS = zeros(n, 1);
    meanV = zeros(n, 1);
    meanR = zeros(n, 1);
    meanG = zeros(n, 1);
    meanB = zeros(n, 1);

    for i = 1:n

        id(i) = candidatos(i).id;
        cara(i) = string(candidatos(i).cara);
        fila(i) = candidatos(i).fila_cara;
        columna(i) = candidatos(i).columna_cara;
        color(i) = string(candidatos(i).color_kmeans);
        cluster(i) = candidatos(i).cluster_kmeans;

        centroid_x(i) = candidatos(i).centroid_x;
        centroid_y(i) = candidatos(i).centroid_y;

        bbox_x(i) = candidatos(i).bbox_x;
        bbox_y(i) = candidatos(i).bbox_y;
        bbox_w(i) = candidatos(i).bbox_w;
        bbox_h(i) = candidatos(i).bbox_h;

        meanH(i) = candidatos(i).meanH;
        meanS(i) = candidatos(i).meanS;
        meanV(i) = candidatos(i).meanV;
        meanR(i) = candidatos(i).meanR;
        meanG(i) = candidatos(i).meanG;
        meanB(i) = candidatos(i).meanB;

    end

    tabla = table( ...
        id, ...
        cara, ...
        fila, ...
        columna, ...
        color, ...
        cluster, ...
        centroid_x, ...
        centroid_y, ...
        bbox_x, ...
        bbox_y, ...
        bbox_w, ...
        bbox_h, ...
        meanH, ...
        meanS, ...
        meanV, ...
        meanR, ...
        meanG, ...
        meanB);

    tabla = sortrows(tabla, {'cara', 'fila', 'columna'});

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar agrupación
% ================================================================

function visualizar_agrupacion_caras(img_roi, candidatos, titulo_figura)

    figure('Name', titulo_figura, 'NumberTitle', 'off');

    imshow(img_roi);
    title(titulo_figura);
    hold on;

    for i = 1:numel(candidatos)

        bbox = [ ...
            candidatos(i).bbox_x, ...
            candidatos(i).bbox_y, ...
            candidatos(i).bbox_w, ...
            candidatos(i).bbox_h];

        switch lower(candidatos(i).cara)

            case 'superior'
                edge_color = 'yellow';

            case 'izquierda'
                edge_color = 'green';

            case 'derecha'
                edge_color = 'cyan';

            otherwise
                edge_color = 'red';

        end

        rectangle('Position', bbox, ...
            'EdgeColor', edge_color, ...
            'LineWidth', 1.5);

        etiqueta = sprintf('%d | %s | f%d c%d | %s', ...
            candidatos(i).id, ...
            candidatos(i).cara, ...
            candidatos(i).fila_cara, ...
            candidatos(i).columna_cara, ...
            candidatos(i).color_kmeans);

        text(candidatos(i).centroid_x, candidatos(i).centroid_y, etiqueta, ...
            'Color', 'white', ...
            'BackgroundColor', 'black', ...
            'Margin', 1, ...
            'FontSize', 7, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');

    end

    hold off;

end


%% ================================================================
% FUNCIÓN LOCAL: Imprimir resumen
% ================================================================

function imprimir_resumen_caras(caras)

    fprintf('Superior:  %d stickers\n', caras.num_superior);
    fprintf('Izquierda: %d stickers\n', caras.num_izquierda);
    fprintf('Derecha:   %d stickers\n', caras.num_derecha);

end