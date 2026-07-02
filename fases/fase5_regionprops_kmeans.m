function datos = fase5_regionprops_kmeans(datos, cfg)
% ================================================================
% FASE 5: Extracción de candidatos a stickers
%
% Modo anterior:
%   - regionprops sobre máscaras por color.
%
% Modo recomendado para dataset:
%   - extracción geométrica mediante polígonos de caras,
%     rectificación proyectiva y grilla 3x3.
%
% Objetivo:
%   - Generar candidatos a stickers.
%   - Estimar color central de cada sticker.
%   - Aplicar kmeans() de MATLAB para agrupamiento adaptativo.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 5: Extracción de candidatos + K-means MATLAB\n');
    fprintf('=================================================\n');

    if ~isfield(cfg, 'modo_extraccion_candidatos')
        cfg.modo_extraccion_candidatos = 'geometrico';
    end

    fprintf('Modo de extracción de candidatos: %s\n', cfg.modo_extraccion_candidatos);

    switch lower(cfg.modo_extraccion_candidatos)

        case 'regionprops'

            %% ----------------------------------------------------
            % MODO ANTIGUO: regionprops por máscaras de color
            % ----------------------------------------------------

            candidatos1 = extraer_candidatos_por_color( ...
                datos.img1_roi, ...
                datos.H1_roi, ...
                datos.S1_roi, ...
                datos.V1_roi, ...
                datos.masks_color1, ...
                cfg, ...
                'Imagen 1');

            candidatos2 = extraer_candidatos_por_color( ...
                datos.img2_roi, ...
                datos.H2_roi, ...
                datos.S2_roi, ...
                datos.V2_roi, ...
                datos.masks_color2, ...
                cfg, ...
                'Imagen 2');

            if cfg.eliminar_duplicados
                candidatos1 = eliminar_duplicados_candidatos(candidatos1, cfg, 'Imagen 1');
                candidatos2 = eliminar_duplicados_candidatos(candidatos2, cfg, 'Imagen 2');
            end


        case 'geometrico'

            %% ----------------------------------------------------
            % MODO NUEVO: polígonos + rectificación + grilla 3x3
            % ----------------------------------------------------

            fprintf('\nObteniendo polígonos de caras visibles - Imagen 1\n');
            poligonos1 = obtener_poligonos_caras( ...
                datos.img1_roi, ...
                datos.mask_roi1_crop, ...
                'Imagen 1', ...
                cfg);

            fprintf('\nObteniendo polígonos de caras visibles - Imagen 2\n');
            poligonos2 = obtener_poligonos_caras( ...
                datos.img2_roi, ...
                datos.mask_roi2_crop, ...
                'Imagen 2', ...
                cfg);

            candidatos1 = extraer_candidatos_geometricos( ...
                datos.img1_roi, ...
                poligonos1, ...
                cfg, ...
                'Imagen 1');

            candidatos2 = extraer_candidatos_geometricos( ...
                datos.img2_roi, ...
                poligonos2, ...
                cfg, ...
                'Imagen 2');

            datos.poligonos_caras1_fase5 = poligonos1;
            datos.poligonos_caras2_fase5 = poligonos2;


        otherwise

            error('Modo de extracción de candidatos no reconocido: %s', ...
                cfg.modo_extraccion_candidatos);

    end


    %% ------------------------------------------------------------
    % Aplicar K-means de MATLAB
    % ------------------------------------------------------------

    candidatos1 = aplicar_kmeans_matlab(candidatos1, cfg, 'Imagen 1');
    candidatos2 = aplicar_kmeans_matlab(candidatos2, cfg, 'Imagen 2');


    %% ------------------------------------------------------------
    % Reenumerar candidatos
    % ------------------------------------------------------------

    candidatos1 = reenumerar_candidatos(candidatos1);
    candidatos2 = reenumerar_candidatos(candidatos2);


    %% ------------------------------------------------------------
    % Convertir a tablas
    % ------------------------------------------------------------

    tabla1 = candidatos_a_tabla(candidatos1);
    tabla2 = candidatos_a_tabla(candidatos2);


    %% ------------------------------------------------------------
    % Visualización
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        visualizar_candidatos_regionprops(datos.img1_roi, candidatos1, ...
            'Imagen 1 - Candidatos Fase 5 + K-means MATLAB');

        visualizar_candidatos_regionprops(datos.img2_roi, candidatos2, ...
            'Imagen 2 - Candidatos Fase 5 + K-means MATLAB');

    end


    %% ------------------------------------------------------------
    % Guardar resultados
    % ------------------------------------------------------------

    datos.candidatos1 = candidatos1;
    datos.candidatos2 = candidatos2;

    datos.tabla_candidatos1 = tabla1;
    datos.tabla_candidatos2 = tabla2;

    datos.num_candidatos1 = numel(candidatos1);
    datos.num_candidatos2 = numel(candidatos2);


    %% ------------------------------------------------------------
    % Guardar CSV si está activado
    % ------------------------------------------------------------

    if isfield(cfg, 'guardar_candidatos_fase5') && cfg.guardar_candidatos_fase5

        if ~exist(cfg.candidatos_dir, 'dir')
            mkdir(cfg.candidatos_dir);
        end

        writetable(tabla1, fullfile(cfg.candidatos_dir, 'candidatos_imagen1.csv'));
        writetable(tabla2, fullfile(cfg.candidatos_dir, 'candidatos_imagen2.csv'));

    end


    %% ------------------------------------------------------------
    % Resumen técnico
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 5 ================\n');

    fprintf('Modo usado: %s\n', cfg.modo_extraccion_candidatos);
    fprintf('Imagen 1 - candidatos refinados: %d\n', datos.num_candidatos1);
    fprintf('Imagen 2 - candidatos refinados: %d\n', datos.num_candidatos2);

    fprintf('\nTabla de candidatos - Imagen 1:\n');
    disp(tabla1);

    fprintf('\nTabla de candidatos - Imagen 2:\n');
    disp(tabla2);

    fprintf('\nObservaciones:\n');

    if strcmpi(cfg.modo_extraccion_candidatos, 'geometrico')
        fprintf('1. Los candidatos se generaron por caras rectificadas y grilla 3x3.\n');
        fprintf('2. Este modo no depende de que regionprops separe stickers pegados.\n');
        fprintf('3. Cada imagen debe producir 27 candidatos.\n');
    else
        fprintf('1. Los candidatos provienen de máscaras individuales por color.\n');
        fprintf('2. Este modo puede fallar si stickers vecinos quedan conectados.\n');
    end

    fprintf('4. Se aplicó kmeans() de MATLAB sobre características de color.\n');
    fprintf('5. La siguiente fase debe ordenar candidatos por cara y posición 3x3.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 5 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer candidatos geométricos por cara rectificada
% ================================================================

function candidatos = extraer_candidatos_geometricos(img_roi, poligonos, cfg, nombre_img)

    fprintf('\nExtrayendo candidatos geométricos - %s\n', nombre_img);

    img_roi = im2double(img_roi);

    nombres_caras = {'superior', 'izquierda', 'derecha'};

    candidatos = crear_estructura_candidatos_vacia();
    contador = 0;

    W = cfg.face_warp_size;
    N = cfg.grid_n;

    destino = [ ...
        1, 1; ...
        W, 1; ...
        W, W; ...
        1, W ...
    ];

    for c = 1:numel(nombres_caras)

        cara = nombres_caras{c};

        if ~isfield(poligonos, cara)
            error('%s: no existe polígono para la cara %s.', nombre_img, cara);
        end

        puntos_origen = poligonos.(cara);

        if size(puntos_origen, 1) ~= 4 || size(puntos_origen, 2) ~= 2
            error('%s: el polígono de la cara %s no tiene formato 4x2.', nombre_img, cara);
        end

        % Transformación proyectiva desde cara en imagen hacia cara frontal.
        tform = fitgeotrans(puntos_origen, destino, 'projective');

        cara_rectificada = imwarp( ...
            img_roi, ...
            tform, ...
            'OutputView', imref2d([W W]));

        hsv_rectificada = rgb2hsv(cara_rectificada);

        tam_celda = W / N;

        for fila = 1:N
            for columna = 1:N

                contador = contador + 1;

                % ------------------------------------------------
                % Límites de celda en la imagen rectificada
                % ------------------------------------------------

                x1 = (columna - 1) * tam_celda + 1;
                x2 = columna * tam_celda;

                y1 = (fila - 1) * tam_celda + 1;
                y2 = fila * tam_celda;

                % Centro de celda en coordenadas rectificadas.
                cx_warp = (x1 + x2) / 2;
                cy_warp = (y1 + y2) / 2;

                % ------------------------------------------------
                % Región central de la celda para estimar color
                % ------------------------------------------------

                margen = cfg.margen_interno_celda;

                xi1 = round(x1 + margen * tam_celda);
                xi2 = round(x2 - margen * tam_celda);

                yi1 = round(y1 + margen * tam_celda);
                yi2 = round(y2 - margen * tam_celda);

                xi1 = max(1, min(W, xi1));
                xi2 = max(1, min(W, xi2));
                yi1 = max(1, min(W, yi1));
                yi2 = max(1, min(W, yi2));

                patch_rgb = cara_rectificada(yi1:yi2, xi1:xi2, :);
                patch_hsv = hsv_rectificada(yi1:yi2, xi1:xi2, :);

                [meanH, meanS, meanV, meanR, meanG, meanB] = ...
                    extraer_color_patch(patch_rgb, patch_hsv);

                % ------------------------------------------------
                % Centro y bbox aproximados en la imagen original ROI
                % ------------------------------------------------

                [cx_img, cy_img] = transformPointsInverse(tform, cx_warp, cy_warp);

                esquinas_celda_warp = [ ...
                    x1, y1; ...
                    x2, y1; ...
                    x2, y2; ...
                    x1, y2 ...
                ];

                [xs, ys] = transformPointsInverse( ...
                    tform, ...
                    esquinas_celda_warp(:,1), ...
                    esquinas_celda_warp(:,2));

                bbox_x = min(xs);
                bbox_y = min(ys);
                bbox_w = max(xs) - min(xs);
                bbox_h = max(ys) - min(ys);

                % ------------------------------------------------
                % Guardar candidato
                % ------------------------------------------------

                candidatos(contador).id = contador;

                candidatos(contador).color_pre_hsv = 'geometrico';

                candidatos(contador).cara_geometrica = cara;
                candidatos(contador).fila_geometrica = fila;
                candidatos(contador).columna_geometrica = columna;

                candidatos(contador).area = bbox_w * bbox_h;
                candidatos(contador).centroid_x = cx_img;
                candidatos(contador).centroid_y = cy_img;

                candidatos(contador).bbox_x = bbox_x;
                candidatos(contador).bbox_y = bbox_y;
                candidatos(contador).bbox_w = bbox_w;
                candidatos(contador).bbox_h = bbox_h;

                candidatos(contador).solidez = 1;
                candidatos(contador).extent = 1;
                candidatos(contador).aspect_ratio = bbox_w / max(bbox_h, eps);

                candidatos(contador).major_axis = max(bbox_w, bbox_h);
                candidatos(contador).minor_axis = min(bbox_w, bbox_h);

                candidatos(contador).meanH = meanH;
                candidatos(contador).meanS = meanS;
                candidatos(contador).meanV = meanV;

                candidatos(contador).meanR = meanR;
                candidatos(contador).meanG = meanG;
                candidatos(contador).meanB = meanB;

                candidatos(contador).cluster_kmeans = NaN;
                candidatos(contador).color_kmeans = 'sin_cluster';

                candidatos(contador).score = 1;

            end
        end
    end

    fprintf('%s: candidatos geométricos generados: %d\n', nombre_img, contador);

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer color de un parche rectificado
% ================================================================

function [meanH, meanS, meanV, meanR, meanG, meanB] = ...
    extraer_color_patch(patch_rgb, patch_hsv)

    R = patch_rgb(:,:,1);
    G = patch_rgb(:,:,2);
    B = patch_rgb(:,:,3);

    H = patch_hsv(:,:,1);
    S = patch_hsv(:,:,2);
    V = patch_hsv(:,:,3);

    meanH = median(H(:), 'omitnan');
    meanS = median(S(:), 'omitnan');
    meanV = median(V(:), 'omitnan');

    meanR = median(R(:), 'omitnan');
    meanG = median(G(:), 'omitnan');
    meanB = median(B(:), 'omitnan');

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer candidatos por máscara de color
% Modo antiguo conservado para diagnóstico
% ================================================================

function candidatos = extraer_candidatos_por_color(img_roi, H, S, V, masks_color, cfg, nombre_img)

    fprintf('\nExtrayendo candidatos con regionprops - %s\n', nombre_img);

    nombres_colores = fieldnames(masks_color);
    candidatos = crear_estructura_candidatos_vacia();
    contador = 0;

    for c = 1:length(nombres_colores)

        color_pre = nombres_colores{c};
        mask = logical(masks_color.(color_pre));

        props = regionprops(mask, ...
            'Area', ...
            'Centroid', ...
            'BoundingBox', ...
            'Solidity', ...
            'Extent', ...
            'MajorAxisLength', ...
            'MinorAxisLength');

        for i = 1:length(props)

            area = props(i).Area;
            bbox = props(i).BoundingBox;
            centroide = props(i).Centroid;
            solidez = props(i).Solidity;
            extent = props(i).Extent;

            ancho = bbox(3);
            alto = bbox(4);
            aspect_ratio = ancho / max(alto, eps);

            if area < cfg.area_min_sticker
                continue;
            end

            if area > cfg.area_max_sticker
                continue;
            end

            if solidez < cfg.solidez_min_sticker
                continue;
            end

            if extent < cfg.extent_min_sticker
                continue;
            end

            if aspect_ratio < cfg.aspect_min_sticker || aspect_ratio > cfg.aspect_max_sticker
                continue;
            end

            [meanH, meanS, meanV, meanR, meanG, meanB] = ...
                extraer_color_central(img_roi, H, S, V, centroide, cfg.radio_patch_color);

            contador = contador + 1;

            candidatos(contador).id = contador;
            candidatos(contador).color_pre_hsv = color_pre;

            candidatos(contador).cara_geometrica = 'sin_cara';
            candidatos(contador).fila_geometrica = NaN;
            candidatos(contador).columna_geometrica = NaN;

            candidatos(contador).area = area;
            candidatos(contador).centroid_x = centroide(1);
            candidatos(contador).centroid_y = centroide(2);

            candidatos(contador).bbox_x = bbox(1);
            candidatos(contador).bbox_y = bbox(2);
            candidatos(contador).bbox_w = bbox(3);
            candidatos(contador).bbox_h = bbox(4);

            candidatos(contador).solidez = solidez;
            candidatos(contador).extent = extent;
            candidatos(contador).aspect_ratio = aspect_ratio;

            candidatos(contador).major_axis = props(i).MajorAxisLength;
            candidatos(contador).minor_axis = props(i).MinorAxisLength;

            candidatos(contador).meanH = meanH;
            candidatos(contador).meanS = meanS;
            candidatos(contador).meanV = meanV;

            candidatos(contador).meanR = meanR;
            candidatos(contador).meanG = meanG;
            candidatos(contador).meanB = meanB;

            candidatos(contador).cluster_kmeans = NaN;
            candidatos(contador).color_kmeans = 'sin_cluster';

            candidatos(contador).score = calcular_score_candidato(area, solidez, extent);

        end
    end

    fprintf('Candidatos válidos iniciales en %s: %d\n', nombre_img, contador);

end


%% ================================================================
% FUNCIÓN LOCAL: Score para candidatos
% ================================================================

function score = calcular_score_candidato(area, solidez, extent)

    score = (0.45 * solidez) + ...
            (0.45 * extent) + ...
            (0.10 * min(area / 5000, 1));

end


%% ================================================================
% FUNCIÓN LOCAL: Eliminar duplicados por centroides cercanos
% ================================================================

function candidatos_out = eliminar_duplicados_candidatos(candidatos, cfg, nombre_img)

    n = numel(candidatos);

    if n == 0
        candidatos_out = candidatos;
        return;
    end

    fprintf('Eliminando duplicados en %s...\n', nombre_img);

    centroides = [[candidatos.centroid_x]', [candidatos.centroid_y]'];
    scores = [candidatos.score]';

    keep = true(n, 1);

    for i = 1:n

        if ~keep(i)
            continue;
        end

        for j = i+1:n

            if ~keep(j)
                continue;
            end

            d = norm(centroides(i,:) - centroides(j,:));

            if d < cfg.distancia_dup_px

                if scores(i) >= scores(j)
                    keep(j) = false;
                else
                    keep(i) = false;
                    break;
                end

            end
        end
    end

    candidatos_out = candidatos(keep);

    fprintf('Candidatos antes: %d | después de duplicados: %d\n', ...
        n, numel(candidatos_out));

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer color central
% ================================================================

function [meanH, meanS, meanV, meanR, meanG, meanB] = ...
    extraer_color_central(img_roi, H, S, V, centroide, radio)

    x = round(centroide(1));
    y = round(centroide(2));

    filas = size(H, 1);
    columnas = size(H, 2);

    x1 = max(1, x - radio);
    x2 = min(columnas, x + radio);

    y1 = max(1, y - radio);
    y2 = min(filas, y + radio);

    patchH = H(y1:y2, x1:x2);
    patchS = S(y1:y2, x1:x2);
    patchV = V(y1:y2, x1:x2);

    img_double = im2double(img_roi);

    patchR = img_double(y1:y2, x1:x2, 1);
    patchG = img_double(y1:y2, x1:x2, 2);
    patchB = img_double(y1:y2, x1:x2, 3);

    meanH = median(patchH(:));
    meanS = median(patchS(:));
    meanV = median(patchV(:));

    meanR = median(patchR(:));
    meanG = median(patchG(:));
    meanB = median(patchB(:));

end


%% ================================================================
% FUNCIÓN LOCAL: Aplicar K-means de MATLAB
% ================================================================

function candidatos = aplicar_kmeans_matlab(candidatos, cfg, nombre_img)

    n = numel(candidatos);

    if n == 0
        fprintf('No hay candidatos para clasificar en %s.\n', nombre_img);
        return;
    end

    if ~cfg.usar_kmeans
        fprintf('K-means desactivado para %s. Se aplicará clasificación individual.\n', nombre_img);

        for i = 1:n
            candidatos(i).cluster_kmeans = NaN;
            candidatos(i).color_kmeans = clasificar_color_individual(candidatos(i), cfg);
        end

        return;
    end

    if n < cfg.kmeans_K_colores
        fprintf('No hay suficientes candidatos para K-means en %s. Se aplicará clasificación individual.\n', nombre_img);

        for i = 1:n
            candidatos(i).cluster_kmeans = NaN;
            candidatos(i).color_kmeans = clasificar_color_individual(candidatos(i), cfg);
        end

        return;
    end

    if exist('kmeans', 'file') ~= 2
        error(['La función kmeans() no está disponible. ', ...
               'Verifica el Statistics and Machine Learning Toolbox.']);
    end

    fprintf('Aplicando kmeans() de MATLAB en %s con K = %d...\n', ...
        nombre_img, cfg.kmeans_K_colores);

    H = [candidatos.meanH]';
    S = [candidatos.meanS]';
    V = [candidatos.meanV]';

    R = [candidatos.meanR]';
    G = [candidatos.meanG]';
    B = [candidatos.meanB]';

    % Representación circular del tono H.
    X = [cos(2*pi*H), sin(2*pi*H), S, V, R, G, B];

    % Pesos para mejorar separación cromática.
    X(:,1) = 1.5 * X(:,1);
    X(:,2) = 1.5 * X(:,2);
    X(:,3) = 1.2 * X(:,3);
    X(:,5) = 1.2 * X(:,5);
    X(:,6) = 1.2 * X(:,6);
    X(:,7) = 1.2 * X(:,7);

    K = min(cfg.kmeans_K_colores, n);

    rng(1);

    idx = kmeans(X, K, ...
        'Replicates', cfg.kmeans_replicates, ...
        'MaxIter', cfg.kmeans_max_iter, ...
        'Display', 'off');

    % Guardar número de cluster.
    for i = 1:n
        candidatos(i).cluster_kmeans = idx(i);
    end

    % ------------------------------------------------------------
    % Corrección importante:
    % El color final ya no se toma del promedio del cluster.
    % Se clasifica cada candidato individualmente con su parche central.
    % ------------------------------------------------------------

    for i = 1:n
        candidatos(i).color_kmeans = clasificar_color_individual(candidatos(i), cfg);
    end

    fprintf('kmeans() de MATLAB aplicado correctamente en %s.\n', nombre_img);
    fprintf('Color final corregido candidato por candidato.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Clasificación individual robusta HSV + RGB
% ================================================================

function nombre = clasificar_color_individual(cand, cfg)

    H = cand.meanH;
    S = cand.meanS;
    V = cand.meanV;

    R = cand.meanR;
    G = cand.meanG;
    B = cand.meanB;

    rgb_max = max([R, G, B]);
    rgb_min = min([R, G, B]);
    rgb_diff = rgb_max - rgb_min;

    RG_diff = abs(R - G);

    %% ------------------------------------------------------------
    % 1. BLANCO PRIMERO
    % ------------------------------------------------------------
    % El blanco bajo sombra o luz cálida puede parecer amarillo.
    % Por eso se evalúa antes que amarillo.

    es_blanco_rgb = ...
        R >= cfg.white_R_min && ...
        G >= cfg.white_G_min && ...
        B >= cfg.white_B_min && ...
        rgb_diff <= cfg.white_RGB_diff_max;

    es_blanco_hsv = ...
        S <= cfg.white_S_max && ...
        V >= cfg.white_V_min && ...
        rgb_diff <= cfg.white_RGB_diff_max;

    es_blanco_seguro = ...
        rgb_diff <= cfg.white_RGB_diff_seguro && ...
        V >= cfg.white_V_min;

    % Si B no está claramente por debajo de R y G, no debe ser amarillo.
    B_no_es_bajo = ...
        (R - B) < cfg.yellow_RB_min || ...
        (G - B) < cfg.yellow_GB_min;

    if cfg.priorizar_blanco_sobre_amarillo && ...
       (es_blanco_rgb || es_blanco_hsv || es_blanco_seguro) && ...
       B_no_es_bajo

        nombre = 'blanco';
        return;
    end


    %% ------------------------------------------------------------
    % 2. ROJO
    % ------------------------------------------------------------

    es_rojo = ...
        S >= 0.35 && ...
        V >= 0.25 && ...
        (H <= 0.05 || H >= 0.93) && ...
        R > G && ...
        R > B;

    if es_rojo
        nombre = 'rojo';
        return;
    end


    %% ------------------------------------------------------------
    % 3. AMARILLO ESTRICTO
    % ------------------------------------------------------------
    % Amarillo real: R alto, G alto y B claramente bajo.

    es_amarillo_rgb = ...
        S >= cfg.yellow_S_min && ...
        V >= cfg.yellow_V_min && ...
        R >= cfg.yellow_R_min && ...
        G >= cfg.yellow_G_min && ...
        B <= cfg.yellow_B_max && ...
        (R - B) >= cfg.yellow_RB_min && ...
        (G - B) >= cfg.yellow_GB_min && ...
        RG_diff <= cfg.yellow_RG_diff_max;

    if cfg.yellow_B_debe_ser_menor_que_R_y_G
        es_amarillo_rgb = es_amarillo_rgb && B < R && B < G;
    end

    es_amarillo_hsv = H >= 0.09 && H <= 0.25;

    if es_amarillo_rgb && es_amarillo_hsv
        nombre = 'amarillo';
        return;
    end


    %% ------------------------------------------------------------
    % 4. NARANJA
    % ------------------------------------------------------------

    es_naranja = ...
        S >= 0.35 && ...
        V >= 0.25 && ...
        H > 0.03 && H <= 0.14 && ...
        (R - G) >= cfg.orange_RG_min && ...
        (R - B) >= cfg.orange_RB_min;

    if es_naranja
        nombre = 'naranja';
        return;
    end


    %% ------------------------------------------------------------
    % 5. VERDE
    % ------------------------------------------------------------

    es_verde = ...
        S >= 0.25 && ...
        V >= 0.20 && ...
        H > 0.20 && H <= 0.47 && ...
        G >= R * 0.75 && ...
        G >= B * 0.75;

    if es_verde
        nombre = 'verde';
        return;
    end


    %% ------------------------------------------------------------
    % 6. AZUL
    % ------------------------------------------------------------

    es_azul = ...
        S >= 0.25 && ...
        V >= 0.20 && ...
        H > 0.47 && H <= 0.75;

    if es_azul
        nombre = 'azul';
        return;
    end


    %% ------------------------------------------------------------
    % 7. Segunda oportunidad para blanco
    % ------------------------------------------------------------

    if V >= 0.30 && rgb_diff <= 0.40 && B_no_es_bajo
        nombre = 'blanco';
        return;
    end


    %% ------------------------------------------------------------
    % 8. Respaldo por distancia RGB
    % ------------------------------------------------------------

    nombre = clasificar_por_distancia_rgb(R, G, B);

end


%% ================================================================
% FUNCIÓN LOCAL: Clasificación por distancia RGB
% ================================================================

function nombre = clasificar_por_distancia_rgb(R, G, B)

    x = [R, G, B];

    protos = struct();

    protos.blanco   = [0.78, 0.78, 0.74];
    protos.amarillo = [0.92, 0.84, 0.18];
    protos.rojo     = [0.85, 0.12, 0.08];
    protos.naranja  = [0.92, 0.45, 0.08];
    protos.verde    = [0.10, 0.65, 0.25];
    protos.azul     = [0.06, 0.38, 0.80];

    nombres = fieldnames(protos);

    distancias = zeros(numel(nombres), 1);

    for i = 1:numel(nombres)
        p = protos.(nombres{i});
        distancias(i) = norm(x - p);
    end

    [~, idx_min] = min(distancias);

    nombre = nombres{idx_min};

    % Corrección final:
    % si RGB es parejo, debe ser blanco.
    rgb_diff = max(x) - min(x);

    if rgb_diff <= 0.30 && min(x) >= 0.30
        nombre = 'blanco';
    end

end



%% ================================================================
% FUNCIÓN LOCAL: Media circular para H
% ================================================================

function H_medio = media_circular_hue(H)

    ang = 2*pi*H;

    x = mean(cos(ang));
    y = mean(sin(ang));

    ang_medio = atan2(y, x);

    if ang_medio < 0
        ang_medio = ang_medio + 2*pi;
    end

    H_medio = ang_medio / (2*pi);

end


%% ================================================================
% FUNCIÓN LOCAL: Nombrar color usando HSV + RGB
% ================================================================

function nombre = nombrar_color_hsv_rgb(H, S, V, R, G, B)

    % Blanco: baja saturación y alto brillo.
    if S < 0.35 && V > 0.45
        nombre = 'blanco';
        return;
    end

    % Rojo: tono cerca de 0 o 1.
    if H <= 0.05 || H >= 0.93
        nombre = 'rojo';
        return;
    end

    % Amarillo: R y G altos, B bajo.
    % Se evalúa antes que naranja para recuperar amarillos cálidos.
    es_amarillo_rgb = ...
        R >= 0.45 && ...
        G >= 0.42 && ...
        B <= 0.50 && ...
        (R - B) >= 0.12 && ...
        (G - B) >= 0.12 && ...
        abs(R - G) <= 0.40;

    if es_amarillo_rgb && H >= 0.08 && H <= 0.25
        nombre = 'amarillo';
        return;
    end

    % Naranja: zona cálida con predominio de R sobre G.
    if H > 0.03 && H <= 0.14
        nombre = 'naranja';
        return;
    end

    % Verde.
    if H > 0.20 && H <= 0.47
        nombre = 'verde';
        return;
    end

    % Azul/celeste.
    if H > 0.47 && H <= 0.75
        nombre = 'azul';
        return;
    end

    nombre = 'indefinido';

end


%% ================================================================
% FUNCIÓN LOCAL: Reenumerar candidatos
% ================================================================

function candidatos = reenumerar_candidatos(candidatos)

    for i = 1:numel(candidatos)
        candidatos(i).id = i;
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Crear estructura vacía de candidatos
% ================================================================

function candidatos = crear_estructura_candidatos_vacia()

    candidatos = struct( ...
        'id', {}, ...
        'color_pre_hsv', {}, ...
        'cara_geometrica', {}, ...
        'fila_geometrica', {}, ...
        'columna_geometrica', {}, ...
        'area', {}, ...
        'centroid_x', {}, ...
        'centroid_y', {}, ...
        'bbox_x', {}, ...
        'bbox_y', {}, ...
        'bbox_w', {}, ...
        'bbox_h', {}, ...
        'solidez', {}, ...
        'extent', {}, ...
        'aspect_ratio', {}, ...
        'major_axis', {}, ...
        'minor_axis', {}, ...
        'meanH', {}, ...
        'meanS', {}, ...
        'meanV', {}, ...
        'meanR', {}, ...
        'meanG', {}, ...
        'meanB', {}, ...
        'cluster_kmeans', {}, ...
        'color_kmeans', {}, ...
        'score', {} ...
    );

end


%% ================================================================
% FUNCIÓN LOCAL: Convertir candidatos a tabla
% ================================================================

function tabla = candidatos_a_tabla(candidatos)

    if isempty(candidatos)
        tabla = table();
        return;
    end

    tabla = struct2table(candidatos);

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar candidatos
% ================================================================

function visualizar_candidatos_regionprops(img_roi, candidatos, titulo_figura)

    figure('Name', titulo_figura, 'NumberTitle', 'off');

    imshow(img_roi);
    title(titulo_figura);
    hold on;

    for i = 1:numel(candidatos)

        bbox = [ ...
            candidatos(i).bbox_x, ...
            candidatos(i).bbox_y, ...
            candidatos(i).bbox_w, ...
            candidatos(i).bbox_h ...
        ];

        rectangle('Position', bbox, ...
            'EdgeColor', 'yellow', ...
            'LineWidth', 1.4);

        etiqueta = sprintf('%d | K%d | %s', ...
            candidatos(i).id, ...
            candidatos(i).cluster_kmeans, ...
            candidatos(i).color_kmeans);

        text(candidatos(i).centroid_x, candidatos(i).centroid_y, etiqueta, ...
            'Color', 'white', ...
            'BackgroundColor', 'black', ...
            'Margin', 1, ...
            'FontSize', 8, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');

    end

    hold off;

end