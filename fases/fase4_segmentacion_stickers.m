function datos = fase4_segmentacion_stickers(datos, cfg)
% ================================================================
% FASE 4: Segmentación preliminar de stickers
%
% Objetivo:
%   - Trabajar sobre las ROI obtenidas en la Fase 3.
%   - Usar HSV para separar regiones candidatas a stickers.
%   - Detectar stickers coloreados mediante S alta y V suficiente.
%   - Detectar stickers blancos mediante S baja y V alta.
%   - Agregar una regla RGB especial para recuperar stickers amarillos.
%   - Limpiar la máscara con morfología suave.
%
% Importante:
%   Esta fase NO clasifica definitivamente cada sticker.
%   Solo genera máscaras preliminares para que en Fase 5 se extraigan
%   regiones con regionprops y luego se refine con K-means.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 4: Segmentación preliminar de stickers\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase4(cfg);

    %% ------------------------------------------------------------
    % 1. Segmentar stickers en Imagen 1
    % ------------------------------------------------------------

    seg1 = segmentar_stickers_individual( ...
        datos.img1_roi, ...
        datos.H1_roi, ...
        datos.S1_roi, ...
        datos.V1_roi, ...
        datos.mask_roi1_crop, ...
        cfg, ...
        'Imagen 1');


    %% ------------------------------------------------------------
    % 2. Segmentar stickers en Imagen 2
    % ------------------------------------------------------------

    seg2 = segmentar_stickers_individual( ...
        datos.img2_roi, ...
        datos.H2_roi, ...
        datos.S2_roi, ...
        datos.V2_roi, ...
        datos.mask_roi2_crop, ...
        cfg, ...
        'Imagen 2');


    %% ------------------------------------------------------------
    % 3. Visualización
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        visualizar_segmentacion_stickers(seg1, 'Imagen 1');
        visualizar_segmentacion_stickers(seg2, 'Imagen 2');

        visualizar_mascaras_por_color(seg1.masks_color, 'Imagen 1');
        visualizar_mascaras_por_color(seg2.masks_color, 'Imagen 2');

    end


    %% ------------------------------------------------------------
    % 4. Guardar resultados
    % ------------------------------------------------------------

    % Imagen 1
    datos.mask_color_stickers1 = seg1.mask_color;
    datos.mask_white_stickers1 = seg1.mask_white;
    datos.mask_stickers1_raw = seg1.mask_raw;
    datos.mask_stickers1_clean = seg1.mask_clean;
    datos.masks_color1 = seg1.masks_color;

    datos.num_componentes_stickers1_raw = seg1.num_componentes_raw;
    datos.num_componentes_stickers1_clean = seg1.num_componentes_clean;

    % Imagen 2
    datos.mask_color_stickers2 = seg2.mask_color;
    datos.mask_white_stickers2 = seg2.mask_white;
    datos.mask_stickers2_raw = seg2.mask_raw;
    datos.mask_stickers2_clean = seg2.mask_clean;
    datos.masks_color2 = seg2.masks_color;

    datos.num_componentes_stickers2_raw = seg2.num_componentes_raw;
    datos.num_componentes_stickers2_clean = seg2.num_componentes_clean;


    %% ------------------------------------------------------------
    % 5. Resumen técnico
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 4 ================\n');

    fprintf('Imagen 1:\n');
    fprintf('Componentes en máscara raw:   %d\n', datos.num_componentes_stickers1_raw);
    fprintf('Componentes en máscara clean: %d\n', datos.num_componentes_stickers1_clean);

    fprintf('\nImagen 2:\n');
    fprintf('Componentes en máscara raw:   %d\n', datos.num_componentes_stickers2_raw);
    fprintf('Componentes en máscara clean: %d\n', datos.num_componentes_stickers2_clean);

    fprintf('\nObservaciones:\n');
    fprintf('1. Esta fase genera candidatos a stickers, no la clasificación final.\n');
    fprintf('2. La máscara de color usa S alta y V suficiente.\n');
    fprintf('3. La máscara blanca usa S baja y V alta.\n');
    fprintf('4. El amarillo usa HSV + una regla RGB adicional.\n');
    fprintf('5. La extracción geométrica formal se hará en Fase 5 con regionprops.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 4 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración de Fase 4
% ================================================================

function cfg = completar_cfg_fase4(cfg)

    %% ------------------------------------------------------------
    % Parámetros generales de segmentación
    % ------------------------------------------------------------

    if ~isfield(cfg, 'sticker_S_min_color')
        cfg.sticker_S_min_color = 0.20;
    end

    if ~isfield(cfg, 'sticker_V_min_color')
        cfg.sticker_V_min_color = 0.20;
    end

    if ~isfield(cfg, 'sticker_S_max_white')
        cfg.sticker_S_max_white = 0.36;
    end

    if ~isfield(cfg, 'sticker_V_min_white')
        cfg.sticker_V_min_white = 0.48;
    end

    if ~isfield(cfg, 'area_min_fragmento_sticker')
        cfg.area_min_fragmento_sticker = 40;
    end

    if ~isfield(cfg, 'radio_open_sticker')
        cfg.radio_open_sticker = 1;
    end

    if ~isfield(cfg, 'radio_close_sticker')
        cfg.radio_close_sticker = 0;
    end


    %% ------------------------------------------------------------
    % Rangos HSV por color
    % ------------------------------------------------------------

    if ~isfield(cfg, 'H_red_1')
        cfg.H_red_1 = [0.00 0.05];
    end

    if ~isfield(cfg, 'H_red_2')
        cfg.H_red_2 = [0.93 1.00];
    end

    if ~isfield(cfg, 'H_orange')
        cfg.H_orange = [0.03 0.12];
    end

    if ~isfield(cfg, 'H_yellow')
        cfg.H_yellow = [0.10 0.24];
    end

    if ~isfield(cfg, 'H_green')
        cfg.H_green = [0.24 0.47];
    end

    if ~isfield(cfg, 'H_blue')
        cfg.H_blue = [0.47 0.72];
    end


    %% ------------------------------------------------------------
    % Regla RGB adicional para amarillo
    % ------------------------------------------------------------

    if ~isfield(cfg, 'usar_regla_rgb_amarillo')
        cfg.usar_regla_rgb_amarillo = true;
    end

    if ~isfield(cfg, 'yellow_R_min')
        cfg.yellow_R_min = 0.50;
    end

    if ~isfield(cfg, 'yellow_G_min')
        cfg.yellow_G_min = 0.45;
    end

    if ~isfield(cfg, 'yellow_B_max')
        cfg.yellow_B_max = 0.45;
    end

    if ~isfield(cfg, 'yellow_RB_min')
        cfg.yellow_RB_min = 0.18;
    end

    if ~isfield(cfg, 'yellow_GB_min')
        cfg.yellow_GB_min = 0.18;
    end

    if ~isfield(cfg, 'yellow_RG_diff_max')
        cfg.yellow_RG_diff_max = 0.32;
    end

    if ~isfield(cfg, 'yellow_S_min')
        cfg.yellow_S_min = 0.20;
    end

    if ~isfield(cfg, 'yellow_V_min')
        cfg.yellow_V_min = 0.45;
    end

    if ~isfield(cfg, 'priorizar_amarillo_sobre_naranja')
        cfg.priorizar_amarillo_sobre_naranja = true;
    end


    %% ------------------------------------------------------------
    % Limpieza de máscaras por color
    % ------------------------------------------------------------

    if ~isfield(cfg, 'radio_open_color')
        cfg.radio_open_color = 2;
    end

    if ~isfield(cfg, 'radio_close_color')
        cfg.radio_close_color = 1;
    end

    if ~isfield(cfg, 'area_min_color_component')
        cfg.area_min_color_component = 300;
    end

    if ~isfield(cfg, 'area_max_color_component')
        cfg.area_max_color_component = 9000;
    end

    if ~isfield(cfg, 'ancho_min_color_component')
        cfg.ancho_min_color_component = 12;
    end

    if ~isfield(cfg, 'alto_min_color_component')
        cfg.alto_min_color_component = 12;
    end

    if ~isfield(cfg, 'solidez_min_color_component')
        cfg.solidez_min_color_component = 0.40;
    end

    if ~isfield(cfg, 'extent_min_color_component')
        cfg.extent_min_color_component = 0.20;
    end

    if ~isfield(cfg, 'aspect_min_color_component')
        cfg.aspect_min_color_component = 0.20;
    end

    if ~isfield(cfg, 'aspect_max_color_component')
        cfg.aspect_max_color_component = 4.50;
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Segmentar stickers de una ROI
% ================================================================

function seg = segmentar_stickers_individual(img_roi, H, S, V, mask_roi, cfg, nombre_img)

    fprintf('\nSegmentando stickers - %s\n', nombre_img);

    img_roi = im2double(img_roi);
    H = im2double(H);
    S = im2double(S);
    V = im2double(V);

    % Asegurar que la máscara ROI sea lógica.
    mask_roi = logical(mask_roi);

    if ndims(mask_roi) > 2
        mask_roi = mask_roi(:,:,1);
    end


    %% ------------------------------------------------------------
    % 1. Máscara de stickers coloreados
    % ------------------------------------------------------------

    mask_color = ...
        (S > cfg.sticker_S_min_color) & ...
        (V > cfg.sticker_V_min_color) & ...
        mask_roi;


    %% ------------------------------------------------------------
    % 2. Máscara de stickers blancos
    % ------------------------------------------------------------

    mask_white = ...
        (S < cfg.sticker_S_max_white) & ...
        (V > cfg.sticker_V_min_white) & ...
        mask_roi;


    %% ------------------------------------------------------------
    % 3. Máscara general de stickers
    % ------------------------------------------------------------

    mask_raw = (mask_color | mask_white) & mask_roi;


    %% ------------------------------------------------------------
    % 4. Limpieza morfológica suave
    % ------------------------------------------------------------

    mask_clean = mask_raw;

    % Eliminar fragmentos pequeños.
    mask_clean = bwareaopen(mask_clean, cfg.area_min_fragmento_sticker);

    % Apertura suave: elimina ruido fino.
    if cfg.radio_open_sticker > 0

        se_open = strel('disk', cfg.radio_open_sticker);
        mask_clean = imopen(mask_clean, se_open);

    end

    % Cierre suave: rellena cortes pequeños dentro de stickers.
    if cfg.radio_close_sticker > 0

        se_close = strel('disk', cfg.radio_close_sticker);
        mask_clean = imclose(mask_clean, se_close);

    end

    % Nueva eliminación de fragmentos pequeños.
    mask_clean = bwareaopen(mask_clean, cfg.area_min_fragmento_sticker);


    %% ------------------------------------------------------------
    % 5. Máscaras por color aproximadas para diagnóstico visual
    % ------------------------------------------------------------

    masks_color = crear_mascaras_color_aproximadas( ...
        H, S, V, img_roi, mask_roi, cfg);


    %% ------------------------------------------------------------
    % 6. Conteo preliminar de componentes conectados
    % ------------------------------------------------------------

    cc_raw = bwconncomp(mask_raw, 8);
    cc_clean = bwconncomp(mask_clean, 8);

    fprintf('Componentes raw: %d\n', cc_raw.NumObjects);
    fprintf('Componentes clean: %d\n', cc_clean.NumObjects);


    %% ------------------------------------------------------------
    % 7. Guardar estructura de salida
    % ------------------------------------------------------------

    seg = struct();

    seg.img_roi = img_roi;
    seg.H = H;
    seg.S = S;
    seg.V = V;
    seg.mask_roi = mask_roi;

    seg.mask_color = mask_color;
    seg.mask_white = mask_white;
    seg.mask_raw = mask_raw;
    seg.mask_clean = mask_clean;

    seg.masks_color = masks_color;

    seg.num_componentes_raw = cc_raw.NumObjects;
    seg.num_componentes_clean = cc_clean.NumObjects;

end


%% ================================================================
% FUNCIÓN LOCAL: Crear máscaras aproximadas por color
% ================================================================

function masks = crear_mascaras_color_aproximadas(H, S, V, img_roi, mask_roi, cfg)

    img_roi = im2double(img_roi);

    R = img_roi(:,:,1);
    G = img_roi(:,:,2);
    B = img_roi(:,:,3);

    mask_roi = logical(mask_roi);

    if ndims(mask_roi) > 2
        mask_roi = mask_roi(:,:,1);
    end


    %% ------------------------------------------------------------
    % Bases generales
    % ------------------------------------------------------------

    base_color = ...
        (S > cfg.sticker_S_min_color) & ...
        (V > cfg.sticker_V_min_color) & ...
        mask_roi;

    base_white = ...
        (S < cfg.sticker_S_max_white) & ...
        (V > cfg.sticker_V_min_white) & ...
        mask_roi;


    %% ------------------------------------------------------------
    % Rojo
    % ------------------------------------------------------------

    mask_red = ...
        (((H >= cfg.H_red_1(1)) & (H <= cfg.H_red_1(2))) | ...
         ((H >= cfg.H_red_2(1)) & (H <= cfg.H_red_2(2)))) & ...
         base_color;


    %% ------------------------------------------------------------
    % Naranja
    % ------------------------------------------------------------

    mask_orange = ...
        (H >= cfg.H_orange(1)) & ...
        (H <= cfg.H_orange(2)) & ...
        base_color;


    %% ------------------------------------------------------------
    % Amarillo por HSV
    % ------------------------------------------------------------

    mask_yellow_hsv = ...
        (H >= cfg.H_yellow(1)) & ...
        (H <= cfg.H_yellow(2)) & ...
        base_color;


    %% ------------------------------------------------------------
    % Amarillo por regla RGB adicional
    % ------------------------------------------------------------

    if cfg.usar_regla_rgb_amarillo

        mask_yellow_rgb = ...
            (R >= cfg.yellow_R_min) & ...
            (G >= cfg.yellow_G_min) & ...
            (B <= cfg.yellow_B_max) & ...
            ((R - B) >= cfg.yellow_RB_min) & ...
            ((G - B) >= cfg.yellow_GB_min) & ...
            (abs(R - G) <= cfg.yellow_RG_diff_max) & ...
            (S >= cfg.yellow_S_min) & ...
            (V >= cfg.yellow_V_min) & ...
            mask_roi;

    else

        mask_yellow_rgb = false(size(H));

    end

    mask_yellow = (mask_yellow_hsv | mask_yellow_rgb) & mask_roi;


    %% ------------------------------------------------------------
    % Evitar duplicidad amarillo/naranja
    % ------------------------------------------------------------

    if cfg.priorizar_amarillo_sobre_naranja

        mask_orange = mask_orange & ~mask_yellow;

    end


    %% ------------------------------------------------------------
    % Verde
    % ------------------------------------------------------------

    mask_green = ...
        (H >= cfg.H_green(1)) & ...
        (H <= cfg.H_green(2)) & ...
        base_color;


    %% ------------------------------------------------------------
    % Azul
    % ------------------------------------------------------------

    mask_blue = ...
        (H >= cfg.H_blue(1)) & ...
        (H <= cfg.H_blue(2)) & ...
        base_color;


    %% ------------------------------------------------------------
    % Blanco
    % ------------------------------------------------------------

    mask_white = base_white;


    %% ------------------------------------------------------------
    % Máscaras raw
    % ------------------------------------------------------------

    masks_raw = struct();

    masks_raw.red = mask_red;
    masks_raw.orange = mask_orange;
    masks_raw.yellow = mask_yellow;
    masks_raw.green = mask_green;
    masks_raw.blue = mask_blue;
    masks_raw.white = mask_white;


    %% ------------------------------------------------------------
    % Limpieza morfológica y geométrica por color
    % ------------------------------------------------------------

    masks = struct();

    nombres = fieldnames(masks_raw);

    for i = 1:length(nombres)

        nombre = nombres{i};

        mask_in = masks_raw.(nombre);

        mask_clean = limpiar_mascara_color(mask_in, cfg);

        masks.(nombre) = mask_clean;

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Limpieza morfológica y geométrica por color
% ================================================================

function mask_out = limpiar_mascara_color(mask_in, cfg)
% ================================================================
% Limpieza morfológica y geométrica de una máscara por color.
%
% Esta función elimina:
%   - líneas delgadas,
%   - fragmentos pequeños,
%   - componentes demasiado deformes,
%   - regiones que no tienen tamaño mínimo de sticker.
% ================================================================

    mask = logical(mask_in);


    %% ------------------------------------------------------------
    % 1. Apertura morfológica: elimina líneas delgadas
    % ------------------------------------------------------------

    if cfg.radio_open_color > 0

        se_open = strel('disk', cfg.radio_open_color);
        mask = imopen(mask, se_open);

    end


    %% ------------------------------------------------------------
    % 2. Cierre suave: recupera continuidad de regiones válidas
    % ------------------------------------------------------------

    if cfg.radio_close_color > 0

        se_close = strel('disk', cfg.radio_close_color);
        mask = imclose(mask, se_close);

    end


    %% ------------------------------------------------------------
    % 3. Eliminar componentes pequeños
    % ------------------------------------------------------------

    mask = bwareaopen(mask, cfg.area_min_color_component);


    %% ------------------------------------------------------------
    % 4. Filtro geométrico con regionprops
    % ------------------------------------------------------------

    props = regionprops(mask, ...
        'Area', ...
        'BoundingBox', ...
        'Solidity', ...
        'Extent', ...
        'PixelIdxList');

    mask_out = false(size(mask));

    for k = 1:length(props)

        area = props(k).Area;
        bbox = props(k).BoundingBox;
        solidez = props(k).Solidity;
        extent = props(k).Extent;

        ancho = bbox(3);
        alto = bbox(4);
        aspect_ratio = ancho / max(alto, eps);

        es_valido = true;

        if area < cfg.area_min_color_component
            es_valido = false;
        end

        if area > cfg.area_max_color_component
            es_valido = false;
        end

        if ancho < cfg.ancho_min_color_component
            es_valido = false;
        end

        if alto < cfg.alto_min_color_component
            es_valido = false;
        end

        if solidez < cfg.solidez_min_color_component
            es_valido = false;
        end

        if extent < cfg.extent_min_color_component
            es_valido = false;
        end

        if aspect_ratio < cfg.aspect_min_color_component || ...
           aspect_ratio > cfg.aspect_max_color_component
            es_valido = false;
        end

        if es_valido
            mask_out(props(k).PixelIdxList) = true;
        end

    end


    %% ------------------------------------------------------------
    % 5. Rellenar huecos internos en componentes válidos
    % ------------------------------------------------------------

    mask_out = imfill(mask_out, 'holes');


    %% ------------------------------------------------------------
    % 6. Limpieza final
    % ------------------------------------------------------------

    mask_out = bwareaopen(mask_out, cfg.area_min_color_component);

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar segmentación general
% ================================================================

function visualizar_segmentacion_stickers(seg, nombre_img)

    figure('Name',['Fase 4 - Segmentación de stickers - ', nombre_img], ...
           'NumberTitle','off');

    subplot(2,3,1);
    imshow(seg.img_roi);
    title([nombre_img, ' - ROI RGB']);

    subplot(2,3,2);
    imshow(seg.mask_roi);
    title('Máscara ROI cubo');

    subplot(2,3,3);
    imshow(seg.mask_color);
    title('Stickers coloreados');

    subplot(2,3,4);
    imshow(seg.mask_white);
    title('Stickers blancos');

    subplot(2,3,5);
    imshow(seg.mask_raw);
    title('Máscara stickers raw');

    subplot(2,3,6);
    imshow(seg.img_roi);
    title('Contornos sobre ROI');
    hold on;
    visboundaries(seg.mask_clean, 'Color', 'g');
    hold off;

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar máscaras aproximadas por color
% ================================================================

function visualizar_mascaras_por_color(masks_color, nombre_img)

    figure('Name',['Fase 4 - Máscaras HSV por color - ', nombre_img], ...
           'NumberTitle','off');

    subplot(2,3,1);
    imshow(masks_color.red);
    title('Rojo');

    subplot(2,3,2);
    imshow(masks_color.orange);
    title('Naranja');

    subplot(2,3,3);
    imshow(masks_color.yellow);
    title('Amarillo');

    subplot(2,3,4);
    imshow(masks_color.green);
    title('Verde');

    subplot(2,3,5);
    imshow(masks_color.blue);
    title('Azul');

    subplot(2,3,6);
    imshow(masks_color.white);
    title('Blanco');

end