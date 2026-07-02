function datos = fase3_roi_cubo(datos, cfg)
% ================================================================
% FASE 3: Extracción de ROI del cubo
%
% Objetivo:
%   - Separar la región completa del cubo respecto al fondo.
%   - Usar información HSV, no solo brillo V.
%   - Combinar stickers coloreados y stickers blancos.
%   - Reconstruir la silueta del cubo mediante morfología y convex hull.
%   - Recortar la región de interés para las fases posteriores.
%
% Importante:
%   Esta fase NO detecta stickers individuales.
%   Solo obtiene la región completa del cubo.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 3: Extracción de ROI del cubo\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase3(cfg);


    %% ------------------------------------------------------------
    % 1. Procesar ROI de Imagen 1
    % ------------------------------------------------------------

    roi1 = extraer_roi_individual( ...
        datos.img1, ...
        datos.hsv1, ...
        datos.S1, ...
        datos.V1_proc, ...
        cfg, ...
        'Imagen 1');


    %% ------------------------------------------------------------
    % 2. Procesar ROI de Imagen 2
    % ------------------------------------------------------------

    roi2 = extraer_roi_individual( ...
        datos.img2, ...
        datos.hsv2, ...
        datos.S2, ...
        datos.V2_proc, ...
        cfg, ...
        'Imagen 2');


    %% ------------------------------------------------------------
    % 3. Visualización
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        visualizar_roi(roi1, 'Imagen 1');
        visualizar_roi(roi2, 'Imagen 2');

    end


    %% ------------------------------------------------------------
    % 4. Guardar resultados en estructura datos
    % ------------------------------------------------------------

    % Máscaras completas Imagen 1
    datos.mask_roi1_raw = roi1.mask_raw;
    datos.mask_roi1_color = roi1.mask_color;
    datos.mask_roi1_white = roi1.mask_white;
    datos.mask_roi1_base = roi1.mask_base;
    datos.mask_roi1_clean = roi1.mask_clean;

    % Máscaras completas Imagen 2
    datos.mask_roi2_raw = roi2.mask_raw;
    datos.mask_roi2_color = roi2.mask_color;
    datos.mask_roi2_white = roi2.mask_white;
    datos.mask_roi2_base = roi2.mask_base;
    datos.mask_roi2_clean = roi2.mask_clean;

    % Bounding boxes
    datos.bbox_roi1 = roi1.bbox;
    datos.bbox_roi2 = roi2.bbox;

    % Imágenes recortadas RGB
    datos.img1_roi = roi1.img_roi;
    datos.img2_roi = roi2.img_roi;

    % HSV recortado
    datos.hsv1_roi = roi1.hsv_roi;
    datos.hsv2_roi = roi2.hsv_roi;

    % Canales HSV recortados
    datos.H1_roi = roi1.H_roi;
    datos.S1_roi = roi1.S_roi;
    datos.V1_roi = roi1.V_roi;

    datos.H2_roi = roi2.H_roi;
    datos.S2_roi = roi2.S_roi;
    datos.V2_roi = roi2.V_roi;

    % Canal V procesado recortado
    datos.V1_proc_roi = roi1.V_proc_roi;
    datos.V2_proc_roi = roi2.V_proc_roi;

    % Máscaras recortadas
    datos.mask_roi1_crop = roi1.mask_crop;
    datos.mask_roi2_crop = roi2.mask_crop;

    % Estadísticas
    datos.area_roi1 = roi1.area;
    datos.area_roi2 = roi2.area;
    datos.centroide_roi1 = roi1.centroide;
    datos.centroide_roi2 = roi2.centroide;


    %% ------------------------------------------------------------
    % 5. Resumen técnico
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 3 ================\n');
    fprintf('Método ROI usado: %s\n', cfg.metodo_roi);

    fprintf('\nImagen 1:\n');
    fprintf('Área ROI: %.0f píxeles\n', datos.area_roi1);
    fprintf('Bounding Box: [%.1f %.1f %.1f %.1f]\n', datos.bbox_roi1);

    fprintf('\nImagen 2:\n');
    fprintf('Área ROI: %.0f píxeles\n', datos.area_roi2);
    fprintf('Bounding Box: [%.1f %.1f %.1f %.1f]\n', datos.bbox_roi2);

    fprintf('\nObservaciones:\n');
    fprintf('1. La ROI ya no depende solo del canal V.\n');
    fprintf('2. Se combinaron stickers coloreados y blancos.\n');
    fprintf('3. La silueta se compactó con morfología y convex hull.\n');
    fprintf('4. El recorte RGB/HSV será usado en la segmentación posterior.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 3 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase3(cfg)

    if ~isfield(cfg, 'metodo_roi')
        cfg.metodo_roi = 'hsv_stickers_convexhull';
    end

    if ~isfield(cfg, 'umbral_roi_V')
        cfg.umbral_roi_V = 0.45;
    end

    if ~isfield(cfg, 'area_min_roi_component')
        cfg.area_min_roi_component = 120;
    end

    if ~isfield(cfg, 'area_min_roi')
        cfg.area_min_roi = 1000;
    end

    if ~isfield(cfg, 'radio_cierre_roi')
        cfg.radio_cierre_roi = 8;
    end

    if ~isfield(cfg, 'radio_dilatacion_roi')
        cfg.radio_dilatacion_roi = 6;
    end

    if ~isfield(cfg, 'usar_convex_hull_roi')
        cfg.usar_convex_hull_roi = true;
    end

    if ~isfield(cfg, 'padding_roi')
        cfg.padding_roi = 8;
    end

    if ~isfield(cfg, 'roi_S_min_color')
        cfg.roi_S_min_color = 0.35;
    end

    if ~isfield(cfg, 'roi_V_min_color')
        cfg.roi_V_min_color = 0.35;
    end

    if ~isfield(cfg, 'roi_S_max_white')
        cfg.roi_S_max_white = 0.35;
    end

    if ~isfield(cfg, 'roi_V_min_white')
        cfg.roi_V_min_white = 0.60;
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Extraer ROI de una imagen individual
% ================================================================

function roi = extraer_roi_individual(img_rgb, hsv_img, S, V_proc, cfg, nombre_img)

    fprintf('\nProcesando ROI - %s\n', nombre_img);

    img_rgb = im2double(img_rgb);
    hsv_img = im2double(hsv_img);
    S = im2double(S);
    V_proc = im2double(V_proc);

    [alto, ancho, ~] = size(img_rgb);


    %% ------------------------------------------------------------
    % 1. Máscara inicial según método seleccionado
    % ------------------------------------------------------------

    switch lower(cfg.metodo_roi)

        case 'v_simple'

            mask_color = false(alto, ancho);
            mask_white = false(alto, ancho);

            mask_raw = V_proc > cfg.umbral_roi_V;

        case 'hsv_stickers_convexhull'

            % Stickers coloreados:
            % saturación alta y brillo suficiente.
            mask_color = ...
                S >= cfg.roi_S_min_color & ...
                V_proc >= cfg.roi_V_min_color;

            % Stickers blancos:
            % saturación baja, pero brillo alto.
            mask_white = ...
                S <= cfg.roi_S_max_white & ...
                V_proc >= cfg.roi_V_min_white;

            mask_raw = mask_color | mask_white;

        otherwise

            error('Método de ROI no reconocido: %s', cfg.metodo_roi);

    end


    %% ------------------------------------------------------------
    % 2. Respaldo si la máscara HSV es insuficiente
    % ------------------------------------------------------------

    if nnz(mask_raw) < cfg.area_min_roi_component

        warning('%s: máscara HSV insuficiente. Se usa respaldo por V.', nombre_img);

        mask_raw = V_proc > cfg.umbral_roi_V;

    end


    %% ------------------------------------------------------------
    % 3. Limpieza inicial
    % ------------------------------------------------------------

    mask_base = bwareaopen(mask_raw, cfg.area_min_roi_component);

    if cfg.radio_cierre_roi > 0

        se_close = strel('disk', cfg.radio_cierre_roi);
        mask_base = imclose(mask_base, se_close);

    end

    if cfg.radio_dilatacion_roi > 0

        se_dilate = strel('disk', cfg.radio_dilatacion_roi);
        mask_base = imdilate(mask_base, se_dilate);

    end

    mask_base = imfill(mask_base, 'holes');
    mask_base = bwareaopen(mask_base, cfg.area_min_roi_component);


    %% ------------------------------------------------------------
    % 4. Conservar componente principal
    % ------------------------------------------------------------

    if nnz(mask_base) == 0

        warning('%s: máscara base vacía. Se usará respaldo por V simple.', nombre_img);

        mask_base = V_proc > cfg.umbral_roi_V;
        mask_base = bwareaopen(mask_base, cfg.area_min_roi);
        mask_base = imfill(mask_base, 'holes');

    end

    if nnz(mask_base) == 0
        error('%s: no se pudo extraer ROI del cubo.', nombre_img);
    end

    mask_largest = bwareafilt(mask_base, 1);


    %% ------------------------------------------------------------
    % 5. Convex hull para recuperar silueta completa
    % ------------------------------------------------------------

    if cfg.usar_convex_hull_roi

        mask_clean = bwconvhull(mask_largest);

    else

        mask_clean = mask_largest;

    end

    mask_clean = imfill(mask_clean, 'holes');

    if cfg.radio_cierre_roi > 0

        se_close_final = strel('disk', max(2, round(cfg.radio_cierre_roi / 2)));
        mask_clean = imclose(mask_clean, se_close_final);

    end

    mask_clean = bwareaopen(mask_clean, cfg.area_min_roi);
    mask_clean = bwareafilt(mask_clean, 1);


    %% ------------------------------------------------------------
    % 6. Cálculo de propiedades geométricas
    % ------------------------------------------------------------

    props = regionprops(mask_clean, ...
        'Area', ...
        'BoundingBox', ...
        'Centroid');

    if isempty(props)
        error('No se detectó ninguna ROI válida en %s.', nombre_img);
    end

    [~, idx_max] = max([props.Area]);

    bbox_original = props(idx_max).BoundingBox;
    area = props(idx_max).Area;
    centroide = props(idx_max).Centroid;


    %% ------------------------------------------------------------
    % 7. Agregar padding al bounding box
    % ------------------------------------------------------------

    bbox = agregar_padding_bbox(bbox_original, size(img_rgb), cfg.padding_roi);


    %% ------------------------------------------------------------
    % 8. Recortar imagen RGB, HSV, V procesado y máscara
    % ------------------------------------------------------------

    img_roi = imcrop(img_rgb, bbox);
    hsv_roi = imcrop(hsv_img, bbox);
    V_proc_roi = imcrop(V_proc, bbox);
    mask_crop = imcrop(mask_clean, bbox);

    mask_crop = logical(mask_crop);


    %% ------------------------------------------------------------
    % 9. Separación de canales HSV de la ROI
    % ------------------------------------------------------------

    H_roi = hsv_roi(:,:,1);
    S_roi = hsv_roi(:,:,2);
    V_roi = hsv_roi(:,:,3);


    %% ------------------------------------------------------------
    % 10. Guardar estructura local
    % ------------------------------------------------------------

    roi = struct();

    roi.mask_color = mask_color;
    roi.mask_white = mask_white;
    roi.mask_raw = mask_raw;
    roi.mask_base = mask_base;
    roi.mask_clean = mask_clean;
    roi.mask_crop = mask_crop;

    roi.bbox_original = bbox_original;
    roi.bbox = bbox;

    roi.area = area;
    roi.centroide = centroide;

    roi.img_roi = img_roi;
    roi.hsv_roi = hsv_roi;

    roi.H_roi = H_roi;
    roi.S_roi = S_roi;
    roi.V_roi = V_roi;
    roi.V_proc_roi = V_proc_roi;

    fprintf('ROI detectada en %s.\n', nombre_img);
    fprintf('Área: %.0f píxeles\n', area);
    fprintf('Bounding Box con padding: [%.1f %.1f %.1f %.1f]\n', bbox);

end


%% ================================================================
% FUNCIÓN LOCAL: Agregar padding a Bounding Box
% ================================================================

function bbox_out = agregar_padding_bbox(bbox, img_size, padding)

    % bbox de MATLAB: [x y width height]
    x1 = floor(bbox(1)) - padding;
    y1 = floor(bbox(2)) - padding;

    x2 = ceil(bbox(1) + bbox(3)) + padding;
    y2 = ceil(bbox(2) + bbox(4)) + padding;

    % Limitar a los bordes de la imagen
    x1 = max(1, x1);
    y1 = max(1, y1);

    x2 = min(img_size(2), x2);
    y2 = min(img_size(1), y2);

    w = x2 - x1;
    h = y2 - y1;

    bbox_out = [x1, y1, w, h];

end


%% ================================================================
% FUNCIÓN LOCAL: Visualizar ROI
% ================================================================

function visualizar_roi(roi, nombre_img)

    figure('Name',['Fase 3 - ROI del cubo - ', nombre_img], ...
           'NumberTitle','off');

    subplot(2,3,1);
    imshow(roi.img_roi);
    title([nombre_img, ' - ROI RGB']);

    subplot(2,3,2);
    imshow(roi.mask_raw);
    title('Máscara raw HSV');

    subplot(2,3,3);
    imshow(roi.mask_base);
    title('Máscara base morfológica');

    subplot(2,3,4);
    imshow(roi.mask_clean);
    title('Máscara ROI final');

    subplot(2,3,5);
    imshow(roi.mask_color);
    title('Componentes color');

    subplot(2,3,6);
    imshow(roi.mask_white);
    title('Componentes blanco');


    figure('Name',['Fase 3 - BBox del cubo - ', nombre_img], ...
           'NumberTitle','off');

    imshow(roi.mask_clean);
    title([nombre_img, ' - Máscara final con bounding box']);
    hold on;

    rectangle('Position', roi.bbox, ...
        'EdgeColor', 'yellow', ...
        'LineWidth', 2);

    plot(roi.centroide(1), roi.centroide(2), ...
        'ro', ...
        'MarkerFaceColor', 'r', ...
        'MarkerSize', 6);

    hold off;

end