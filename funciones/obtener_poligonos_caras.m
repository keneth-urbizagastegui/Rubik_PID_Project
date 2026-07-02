function poligonos = obtener_poligonos_caras(img_roi, mask_roi, nombre_img, cfg)
% ================================================================
% OBTENER_POLIGONOS_CARAS
%
% Obtiene los poligonos de las tres caras visibles del cubo.
%
% Modos:
%   manual
%   hough
%   hough_manual_fallback
%
% Salida:
%   poligonos.superior
%   poligonos.izquierda
%   poligonos.derecha
%
% Cada poligono tiene 4 puntos en orden:
%   1) superior izquierda
%   2) superior derecha
%   3) inferior derecha
%   4) inferior izquierda
% ================================================================

    if nargin < 4
        error('Faltan argumentos en obtener_poligonos_caras.');
    end

    cfg = completar_cfg_poligonos(cfg);

    nombre_archivo = lower(strrep(nombre_img, ' ', '_'));

    ruta_poligonos = fullfile(cfg.poligonos_dir, ...
        ['poligonos_' nombre_archivo '.mat']);

    %% ------------------------------------------------------------
    % 1. Reutilizar puntos guardados
    % ------------------------------------------------------------

    if cfg.reutilizar_poligonos_caras && ...
       exist(ruta_poligonos, 'file') && ...
       ~cfg.forzar_nueva_seleccion_caras

        carga = load(ruta_poligonos, 'poligonos');
        poligonos = carga.poligonos;

        fprintf('\nPoligonos cargados desde archivo para %s:\n%s\n', ...
            nombre_img, ruta_poligonos);

        return;

    end

    %% ------------------------------------------------------------
    % 2. Seleccionar metodo
    % ------------------------------------------------------------

    modo = lower(strtrim(cfg.modo_poligonos_caras));

    switch modo

        case 'manual'

            poligonos = obtener_poligonos_manual(img_roi, nombre_img);

        case 'hough'

            [poligonos, ok] = obtener_poligonos_hough(img_roi, mask_roi, nombre_img, cfg);

            if ~ok
                error('Hough no logro estimar poligonos validos para %s.', nombre_img);
            end

        case 'hough_manual_fallback'

            [poligonos, ok] = obtener_poligonos_hough(img_roi, mask_roi, nombre_img, cfg);

            if ~ok

                warning('Hough no fue confiable para %s. Se activa seleccion manual.', nombre_img);

                poligonos = obtener_poligonos_manual(img_roi, nombre_img);

            end

        otherwise

            error('Modo de poligonos no reconocido: %s', modo);

    end

    %% ------------------------------------------------------------
    % 3. Guardar poligonos
    % ------------------------------------------------------------

    if cfg.guardar_poligonos_caras

        save(ruta_poligonos, 'poligonos');

        fprintf('\nPoligonos guardados para %s en:\n%s\n', ...
            nombre_img, ruta_poligonos);

    end

end


%% ================================================================
% CONFIGURACION POR DEFECTO
% ================================================================

function cfg = completar_cfg_poligonos(cfg)

    if ~isfield(cfg, 'modo_poligonos_caras')
        cfg.modo_poligonos_caras = 'hough_manual_fallback';
    end

    if ~isfield(cfg, 'guardar_poligonos_caras')
        cfg.guardar_poligonos_caras = true;
    end

    if ~isfield(cfg, 'reutilizar_poligonos_caras')
        cfg.reutilizar_poligonos_caras = true;
    end

    if ~isfield(cfg, 'forzar_nueva_seleccion_caras')
        cfg.forzar_nueva_seleccion_caras = false;
    end

    if ~isfield(cfg, 'poligonos_dir')
        cfg.poligonos_dir = fullfile(cfg.resultados_dir, 'poligonos_caras');
    end

    if ~exist(cfg.poligonos_dir, 'dir')
        mkdir(cfg.poligonos_dir);
    end

    if ~isfield(cfg, 'hough_mostrar_diagnostico')
        cfg.hough_mostrar_diagnostico = true;
    end

    if ~isfield(cfg, 'hough_canny_sigma')
        cfg.hough_canny_sigma = 1.2;
    end

    if ~isfield(cfg, 'hough_theta_step')
        cfg.hough_theta_step = 0.5;
    end

    if ~isfield(cfg, 'hough_num_peaks')
        cfg.hough_num_peaks = 60;
    end

    if ~isfield(cfg, 'hough_peak_threshold_factor')
        cfg.hough_peak_threshold_factor = 0.15;
    end

    if ~isfield(cfg, 'hough_fill_gap')
        cfg.hough_fill_gap = 25;
    end

    if ~isfield(cfg, 'hough_min_length')
        cfg.hough_min_length = 35;
    end

    if ~isfield(cfg, 'hough_margen_interseccion')
        cfg.hough_margen_interseccion = 25;
    end

    if ~isfield(cfg, 'hough_reducepoly_tol')
        cfg.hough_reducepoly_tol = 0.015;
    end

    %% ------------------------------------------------------------
    % Control de calidad de poligonos Hough
    % ------------------------------------------------------------

    if ~isfield(cfg, 'hough_validar_poligonos')
        cfg.hough_validar_poligonos = true;
    end

    if ~isfield(cfg, 'hough_mostrar_reporte_validacion')
        cfg.hough_mostrar_reporte_validacion = true;
    end

    if ~isfield(cfg, 'hough_area_min_rel')
        cfg.hough_area_min_rel = 0.08;
    end

    if ~isfield(cfg, 'hough_area_max_rel')
        cfg.hough_area_max_rel = 0.45;
    end

    if ~isfield(cfg, 'hough_overlap_min')
        cfg.hough_overlap_min = 0.55;
    end

    if ~isfield(cfg, 'hough_union_mask_min')
        cfg.hough_union_mask_min = 0.60;
    end

    if ~isfield(cfg, 'hough_ratio_area_max')
        cfg.hough_ratio_area_max = 3.50;
    end

    if ~isfield(cfg, 'hough_validar_centro_en_mask')
        cfg.hough_validar_centro_en_mask = true;
    end

    if ~isfield(cfg, 'hough_margen_vertices_px')
        cfg.hough_margen_vertices_px = 10;
    end

end


%% ================================================================
% Hough automatico
% ================================================================

function [poligonos, ok] = obtener_poligonos_hough(img_roi, mask_roi, nombre_img, cfg)

    fprintf('\nIntentando estimar esquinas con Canny + Hough - %s\n', nombre_img);

    ok = false;
    poligonos = struct();

    img_roi = im2double(img_roi);

    if size(img_roi, 3) == 3
        Igray = rgb2gray(img_roi);
    else
        Igray = img_roi;
    end

    mask_roi = logical(mask_roi);

    [alto, ancho] = size(Igray);

    %% ------------------------------------------------------------
    % 1. Preparar bordes
    % ------------------------------------------------------------

    Igray_suave = imgaussfilt(Igray, cfg.hough_canny_sigma);

    E_img = edge(Igray_suave, 'Canny');

    % Borde exterior de la mascara del cubo.
    E_mask = bwperim(mask_roi);

    % Usamos ambos: bordes reales de la imagen y borde externo del ROI.
    E = E_img & imdilate(mask_roi, strel('disk', 1));
    E = E | E_mask;

    E = bwareaopen(E, 10);

    %% ------------------------------------------------------------
    % 2. Hough
    % ------------------------------------------------------------

    theta = -90:cfg.hough_theta_step:(90 - cfg.hough_theta_step);

    [H, T, R] = hough(E, 'Theta', theta);

    threshold = ceil(cfg.hough_peak_threshold_factor * max(H(:)));

    P = houghpeaks(H, cfg.hough_num_peaks, ...
        'Threshold', threshold);

    lineas = houghlines(E, T, R, P, ...
        'FillGap', cfg.hough_fill_gap, ...
        'MinLength', cfg.hough_min_length);

    if numel(lineas) < 6
        warning('%s: Hough detecto pocas lineas: %d.', nombre_img, numel(lineas));
        return;
    end

    %% ------------------------------------------------------------
    % 3. Obtener vertices externos desde la silueta del cubo
    % ------------------------------------------------------------

    [puntos_externos, ok_ext] = estimar_vertices_externos(mask_roi, cfg);

    if ~ok_ext
        warning('%s: no se pudieron estimar vertices externos.', nombre_img);
        return;
    end

    Ttop = puntos_externos.T;
    Bbot = puntos_externos.B;
    LU = puntos_externos.LU;
    RU = puntos_externos.RU;
    LL = puntos_externos.LL;
    RR = puntos_externos.RR;

    %% ------------------------------------------------------------
    % 4. Estimar punto central C usando intersecciones Hough
    % ------------------------------------------------------------

    [C, ok_centro, intersecciones] = estimar_centro_hough( ...
        lineas, mask_roi, Ttop, Bbot, cfg);

    if ~ok_centro
        warning('%s: no se pudo estimar bien el punto central con Hough.', nombre_img);
        return;
    end

    %% ------------------------------------------------------------
    % 5. Construir poligonos de caras
    % ------------------------------------------------------------

    poligonos.superior = [
        LU;
        Ttop;
        RU;
        C
    ];

    poligonos.izquierda = [
        LU;
        C;
        Bbot;
        LL
    ];

    poligonos.derecha = [
        C;
        RU;
        RR;
        Bbot
    ];

    %% ------------------------------------------------------------
    % 6. Validacion geometrica de poligonos
    % ------------------------------------------------------------

    if cfg.hough_validar_poligonos

        [ok, reporte_validacion] = validar_poligonos_hough( ...
            poligonos, ...
            mask_roi, ...
            C, ...
            cfg, ...
            nombre_img);

        if cfg.hough_mostrar_reporte_validacion

            fprintf('\nReporte de validacion Hough - %s\n', nombre_img);
            disp(reporte_validacion.tabla_caras);

            fprintf('Cobertura union / mascara: %.3f\n', ...
                reporte_validacion.cobertura_union_mask);

            fprintf('Ratio area max/min: %.3f\n', ...
                reporte_validacion.ratio_area_max_min);

            fprintf('Centro C dentro de mascara: %d\n', ...
                reporte_validacion.centro_en_mask);

            fprintf('Resultado validacion Hough: %d\n', ...
                reporte_validacion.ok_global);

        end

        if ~ok
            warning('%s: los poligonos Hough no pasaron el control de calidad.', nombre_img);
            return;
        end

    else

        ok = validar_poligonos_basico(poligonos, ancho, alto);

        if ~ok
            warning('%s: los poligonos estimados no pasaron validacion basica.', nombre_img);
            return;
        end

    end

    %% ------------------------------------------------------------
    % 7. Diagnostico visual
    % ------------------------------------------------------------

    if cfg.hough_mostrar_diagnostico

        visualizar_diagnostico_hough( ...
            img_roi, ...
            E, ...
            lineas, ...
            intersecciones, ...
            puntos_externos, ...
            C, ...
            poligonos, ...
            nombre_img);

    end

    fprintf('%s: esquinas estimadas automaticamente con Hough.\n', nombre_img);

end


%% ================================================================
% Estimar vertices externos usando la mascara ROI
% ================================================================

function [pts, ok] = estimar_vertices_externos(mask_roi, cfg)

    ok = false;
    pts = struct();

    mask_roi = imfill(mask_roi, 'holes');
    mask_roi = bwareafilt(mask_roi, 1);

    hull = bwconvhull(mask_roi);

    B = bwboundaries(hull);

    if isempty(B)
        return;
    end

    boundary = B{1};

    % boundary viene como [fila, columna].
    xy = [boundary(:,2), boundary(:,1)];

    % Reducir contorno. Si reducepoly deja demasiados puntos,
    % igual usaremos extremos por posicion.
    poly = reducepoly(xy, cfg.hough_reducepoly_tol);

    if size(poly, 1) < 6
        poly = xy;
    end

    x = poly(:,1);
    y = poly(:,2);

    centro_x = mean(x);
    centro_y = mean(y);

    [~, idx_top] = min(y);
    [~, idx_bot] = max(y);

    Ttop = poly(idx_top, :);
    Bbot = poly(idx_bot, :);

    top_half = poly(y < centro_y, :);
    bottom_half = poly(y >= centro_y, :);

    if size(top_half,1) < 2 || size(bottom_half,1) < 2
        return;
    end

    [~, idx_lu] = min(top_half(:,1));
    [~, idx_ru] = max(top_half(:,1));

    [~, idx_ll] = min(bottom_half(:,1));
    [~, idx_rr] = max(bottom_half(:,1));

    LU = top_half(idx_lu, :);
    RU = top_half(idx_ru, :);
    LL = bottom_half(idx_ll, :);
    RR = bottom_half(idx_rr, :);

    pts.T = Ttop;
    pts.B = Bbot;
    pts.LU = LU;
    pts.RU = RU;
    pts.LL = LL;
    pts.RR = RR;

    ok = true;

end


%% ================================================================
% Estimar centro C con intersecciones de lineas Hough
% ================================================================

function [C, ok, intersecciones] = estimar_centro_hough(lineas, mask_roi, Ttop, Bbot, cfg)

    ok = false;
    C = [NaN NaN];

    [alto, ancho] = size(mask_roi);

    intersecciones = [];

    n = numel(lineas);

    datos_lineas = struct([]);

    for i = 1:n

        p1 = lineas(i).point1;
        p2 = lineas(i).point2;

        longitud = norm(double(p2) - double(p1));

        angulo = atan2d(double(p2(2)-p1(2)), double(p2(1)-p1(1)));

        datos_lineas(i).p1 = double(p1);
        datos_lineas(i).p2 = double(p2);
        datos_lineas(i).longitud = longitud;
        datos_lineas(i).angulo = angulo;

    end

    longitudes = [datos_lineas.longitud];

    if isempty(longitudes)
        return;
    end

    min_len = prctile(longitudes, 45);

    margen = cfg.hough_margen_interseccion;

    mask_dil = imdilate(mask_roi, strel('disk', 8));

    for i = 1:n
        for j = i+1:n

            if datos_lineas(i).longitud < min_len || datos_lineas(j).longitud < min_len
                continue;
            end

            dif_ang = abs(datos_lineas(i).angulo - datos_lineas(j).angulo);
            dif_ang = min(dif_ang, 180 - dif_ang);

            if dif_ang < 20
                continue;
            end

            [p, valido] = interseccion_lineas( ...
                datos_lineas(i).p1, datos_lineas(i).p2, ...
                datos_lineas(j).p1, datos_lineas(j).p2);

            if ~valido
                continue;
            end

            x = p(1);
            y = p(2);

            if x < -margen || x > ancho + margen || ...
               y < -margen || y > alto + margen
                continue;
            end

            xr = round(x);
            yr = round(y);

            xr = max(1, min(ancho, xr));
            yr = max(1, min(alto, yr));

            if ~mask_dil(yr, xr)
                continue;
            end

            intersecciones(end+1, :) = [ ...
                x, ...
                y, ...
                datos_lineas(i).longitud + datos_lineas(j).longitud, ...
                dif_ang ...
            ];

        end
    end

    if isempty(intersecciones)
        return;
    end

    %% ------------------------------------------------------------
    % Seleccionar interseccion central
    % ------------------------------------------------------------

    props = regionprops(mask_roi, 'Centroid');

    if isempty(props)
        centro_mask = [ancho/2, alto/2];
    else
        centro_mask = props(1).Centroid;
    end

    x = intersecciones(:,1);
    y = intersecciones(:,2);
    fuerza = intersecciones(:,3);

    rango_y = Bbot(2) - Ttop(2);

    y_min = Ttop(2) + 0.25 * rango_y;
    y_max = Ttop(2) + 0.75 * rango_y;

    x_min = 0.25 * ancho;
    x_max = 0.75 * ancho;

    candidatos = ...
        x >= x_min & x <= x_max & ...
        y >= y_min & y <= y_max;

    if ~any(candidatos)
        candidatos = true(size(x));
    end

    idx_cand = find(candidatos);

    dist_centro = sqrt( ...
        (x(idx_cand) - centro_mask(1)).^2 + ...
        (y(idx_cand) - centro_mask(2)).^2);

    fuerza_norm = fuerza(idx_cand) ./ max(fuerza(idx_cand));

    % Menor score es mejor:
    % cerca del centro de la mascara y con lineas largas.
    score = dist_centro ./ max(dist_centro + eps) - 0.25 * fuerza_norm;

    [~, idx_best_local] = min(score);

    idx_best = idx_cand(idx_best_local);

    C = [x(idx_best), y(idx_best)];

    ok = true;

end


%% ================================================================
% Interseccion entre dos lineas infinitas
% ================================================================

function [p, valido] = interseccion_lineas(p1, p2, p3, p4)

    valido = false;
    p = [NaN NaN];

    x1 = p1(1); y1 = p1(2);
    x2 = p2(1); y2 = p2(2);
    x3 = p3(1); y3 = p3(2);
    x4 = p4(1); y4 = p4(2);

    den = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4);

    if abs(den) < 1e-9
        return;
    end

    px = ((x1*y2 - y1*x2)*(x3-x4) - ...
          (x1-x2)*(x3*y4 - y3*x4)) / den;

    py = ((x1*y2 - y1*x2)*(y3-y4) - ...
          (y1-y2)*(x3*y4 - y3*x4)) / den;

    p = [px py];
    valido = true;

end


%% ================================================================
% Validacion avanzada de poligonos Hough
% ================================================================

function [ok_global, reporte] = validar_poligonos_hough(poligonos, mask_roi, C, cfg, nombre_img)

    nombres = {'superior', 'izquierda', 'derecha'};

    mask_roi = logical(mask_roi);

    if ndims(mask_roi) > 2
        mask_roi = mask_roi(:,:,1);
    end

    mask_roi = imfill(mask_roi, 'holes');
    mask_roi = bwareafilt(mask_roi, 1);

    [alto, ancho] = size(mask_roi);

    area_mask = sum(mask_roi(:));

    if area_mask <= 0
        ok_global = false;
        reporte = crear_reporte_vacio_poligonos(nombre_img);
        return;
    end

    nombre_tabla = {};
    area_pix_tabla = [];
    area_rel_tabla = [];
    overlap_tabla = [];
    dentro_img_tabla = [];
    centro_cara_en_mask_tabla = [];
    ok_cara_tabla = [];

    areas = zeros(numel(nombres), 1);
    mask_union = false(alto, ancho);

    margen = cfg.hough_margen_vertices_px;

    for k = 1:numel(nombres)

        nombre = nombres{k};
        p = poligonos.(nombre);

        % --------------------------------------------------------
        % Validacion de dimensiones
        % --------------------------------------------------------

        if size(p,1) ~= 4 || size(p,2) ~= 2 || any(isnan(p(:)))

            area_pix = 0;
            area_rel = 0;
            overlap = 0;
            dentro_img = false;
            centro_cara_en_mask = false;
            ok_cara = false;

        else

            % ----------------------------------------------------
            % Verificar que los vertices esten dentro o cerca
            % de la imagen
            % ----------------------------------------------------

            dentro_img = ...
                all(p(:,1) >= 1 - margen) && ...
                all(p(:,1) <= ancho + margen) && ...
                all(p(:,2) >= 1 - margen) && ...
                all(p(:,2) <= alto + margen);

            % ----------------------------------------------------
            % Mascara del poligono
            % ----------------------------------------------------

            mask_p = poly2mask(p(:,1), p(:,2), alto, ancho);

            area_pix = sum(mask_p(:));
            areas(k) = area_pix;

            area_rel = area_pix / area_mask;

            if area_pix > 0
                overlap = sum(mask_p(:) & mask_roi(:)) / area_pix;
            else
                overlap = 0;
            end

            mask_union = mask_union | mask_p;

            % ----------------------------------------------------
            % Centro aproximado del poligono
            % ----------------------------------------------------

            centro_p = mean(p, 1);

            cx = round(centro_p(1));
            cy = round(centro_p(2));

            cx = max(1, min(ancho, cx));
            cy = max(1, min(alto, cy));

            centro_cara_en_mask = mask_roi(cy, cx);

            % ----------------------------------------------------
            % Criterio por cara
            % ----------------------------------------------------

            ok_cara = ...
                dentro_img && ...
                area_rel >= cfg.hough_area_min_rel && ...
                area_rel <= cfg.hough_area_max_rel && ...
                overlap >= cfg.hough_overlap_min && ...
                centro_cara_en_mask;

        end

        nombre_tabla{end+1,1} = nombre;
        area_pix_tabla(end+1,1) = area_pix;
        area_rel_tabla(end+1,1) = area_rel;
        overlap_tabla(end+1,1) = overlap;
        dentro_img_tabla(end+1,1) = dentro_img;
        centro_cara_en_mask_tabla(end+1,1) = centro_cara_en_mask;
        ok_cara_tabla(end+1,1) = ok_cara;

    end

    %% ------------------------------------------------------------
    % Validacion global
    % ------------------------------------------------------------

    areas_validas = areas(areas > 0);

    if isempty(areas_validas)
        ratio_area = inf;
    else
        ratio_area = max(areas_validas) / max(min(areas_validas), eps);
    end

    cobertura_union_mask = sum(mask_union(:) & mask_roi(:)) / area_mask;

    Cx = round(C(1));
    Cy = round(C(2));

    Cx = max(1, min(ancho, Cx));
    Cy = max(1, min(alto, Cy));

    centro_en_mask = mask_roi(Cy, Cx);

    ok_centro = true;

    if cfg.hough_validar_centro_en_mask
        ok_centro = centro_en_mask;
    end

    ok_global = ...
        all(ok_cara_tabla) && ...
        cobertura_union_mask >= cfg.hough_union_mask_min && ...
        ratio_area <= cfg.hough_ratio_area_max && ...
        ok_centro;

    %% ------------------------------------------------------------
    % Reporte
    % ------------------------------------------------------------

    tabla_caras = table( ...
        nombre_tabla, ...
        area_pix_tabla, ...
        area_rel_tabla, ...
        overlap_tabla, ...
        dentro_img_tabla, ...
        centro_cara_en_mask_tabla, ...
        ok_cara_tabla, ...
        'VariableNames', { ...
            'cara', ...
            'area_pix', ...
            'area_rel', ...
            'overlap_mask', ...
            'vertices_en_imagen', ...
            'centro_cara_en_mask', ...
            'ok_cara' ...
        } ...
    );

    reporte = struct();

    reporte.nombre_img = nombre_img;
    reporte.tabla_caras = tabla_caras;
    reporte.cobertura_union_mask = cobertura_union_mask;
    reporte.ratio_area_max_min = ratio_area;
    reporte.centro_en_mask = centro_en_mask;
    reporte.ok_global = ok_global;

end


%% ================================================================
% Validacion basica de respaldo
% ================================================================

function ok = validar_poligonos_basico(poligonos, ancho, alto)

    ok = true;

    nombres = {'superior', 'izquierda', 'derecha'};

    for k = 1:numel(nombres)

        p = poligonos.(nombres{k});

        if any(isnan(p(:)))
            ok = false;
            return;
        end

        if size(p,1) ~= 4 || size(p,2) ~= 2
            ok = false;
            return;
        end

        if any(p(:,1) < -10) || any(p(:,1) > ancho + 10) || ...
           any(p(:,2) < -10) || any(p(:,2) > alto + 10)
            ok = false;
            return;
        end

        area_p = polyarea(p(:,1), p(:,2));

        if area_p < 500
            ok = false;
            return;
        end

    end

end


%% ================================================================
% Crear reporte vacio si la mascara falla
% ================================================================

function reporte = crear_reporte_vacio_poligonos(nombre_img)

    tabla_caras = table( ...
        {'superior'; 'izquierda'; 'derecha'}, ...
        [0; 0; 0], ...
        [0; 0; 0], ...
        [0; 0; 0], ...
        [false; false; false], ...
        [false; false; false], ...
        [false; false; false], ...
        'VariableNames', { ...
            'cara', ...
            'area_pix', ...
            'area_rel', ...
            'overlap_mask', ...
            'vertices_en_imagen', ...
            'centro_cara_en_mask', ...
            'ok_cara' ...
        } ...
    );

    reporte = struct();

    reporte.nombre_img = nombre_img;
    reporte.tabla_caras = tabla_caras;
    reporte.cobertura_union_mask = 0;
    reporte.ratio_area_max_min = inf;
    reporte.centro_en_mask = false;
    reporte.ok_global = false;

end


%% ================================================================
% Seleccion manual
% ================================================================

function poligonos = obtener_poligonos_manual(img_roi, nombre_img)

    nombres_caras = {'superior', 'izquierda', 'derecha'};
    colores = {'yellow', 'green', 'cyan'};

    figure('Name', ['Seleccion manual de caras - ' nombre_img], ...
        'NumberTitle', 'off');

    imshow(img_roi);
    hold on;

    poligonos = struct();

    for k = 1:length(nombres_caras)

        nombre_cara = nombres_caras{k};

        title({ ...
            [nombre_img ' - Seleccion de cara: ' nombre_cara], ...
            'Haz clic en 4 esquinas en este orden:', ...
            '1) superior izquierda  2) superior derecha', ...
            '3) inferior derecha    4) inferior izquierda' ...
        });

        fprintf('\n%s: selecciona 4 esquinas de la cara %s.\n', ...
            nombre_img, nombre_cara);

        fprintf('Orden: superior izquierda, superior derecha, inferior derecha, inferior izquierda.\n');

        [x, y] = ginput(4);

        poligono = [x, y];

        poligonos.(nombre_cara) = poligono;

        plot([x; x(1)], [y; y(1)], ...
            'Color', colores{k}, ...
            'LineWidth', 2.5);

        plot(x, y, 'o', ...
            'Color', colores{k}, ...
            'MarkerFaceColor', colores{k}, ...
            'MarkerSize', 6);

        text(mean(x), mean(y), nombre_cara, ...
            'Color', 'white', ...
            'BackgroundColor', 'black', ...
            'FontSize', 10, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');

        drawnow;

    end

    hold off;

end


%% ================================================================
% Visualizacion diagnostica
% ================================================================

function visualizar_diagnostico_hough( ...
    img_roi, E, lineas, intersecciones, puntos_externos, C, poligonos, nombre_img)

    figure('Name', ['Diagnostico Hough - ' nombre_img], ...
        'NumberTitle', 'off');

    subplot(1,3,1);
    imshow(img_roi);
    title([nombre_img ' - ROI']);

    subplot(1,3,2);
    imshow(E);
    title('Bordes usados para Hough');

    subplot(1,3,3);
    imshow(img_roi);
    title('Lineas, vertices y poligonos estimados');
    hold on;

    % Lineas Hough
    for k = 1:numel(lineas)

        xy = [lineas(k).point1; lineas(k).point2];

        plot(xy(:,1), xy(:,2), ...
            'LineWidth', 1, ...
            'Color', [0.7 0.7 0.7]);

    end

    % Intersecciones
    if ~isempty(intersecciones)
        plot(intersecciones(:,1), intersecciones(:,2), ...
            '.', ...
            'Color', [1 0 1], ...
            'MarkerSize', 8);
    end

    % Puntos externos
    plot(puntos_externos.T(1),  puntos_externos.T(2),  'yo', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
    plot(puntos_externos.B(1),  puntos_externos.B(2),  'yo', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
    plot(puntos_externos.LU(1), puntos_externos.LU(2), 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    plot(puntos_externos.RU(1), puntos_externos.RU(2), 'co', 'MarkerFaceColor', 'c', 'MarkerSize', 8);
    plot(puntos_externos.LL(1), puntos_externos.LL(2), 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    plot(puntos_externos.RR(1), puntos_externos.RR(2), 'co', 'MarkerFaceColor', 'c', 'MarkerSize', 8);

    % Centro
    plot(C(1), C(2), 'ro', ...
        'MarkerFaceColor', 'r', ...
        'MarkerSize', 9);

    text(C(1), C(2), ' C ', ...
        'Color', 'white', ...
        'BackgroundColor', 'red', ...
        'FontWeight', 'bold');

    % Poligonos
    dibujar_poligono(poligonos.superior, 'yellow', 'superior');
    dibujar_poligono(poligonos.izquierda, 'green', 'izquierda');
    dibujar_poligono(poligonos.derecha, 'cyan', 'derecha');

    hold off;

end


function dibujar_poligono(p, color, nombre)

    plot([p(:,1); p(1,1)], [p(:,2); p(1,2)], ...
        'Color', color, ...
        'LineWidth', 2.5);

    text(mean(p(:,1)), mean(p(:,2)), nombre, ...
        'Color', 'white', ...
        'BackgroundColor', 'black', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

end