function datos = fase2_preprocesamiento(datos, cfg)
% ================================================================
% FASE 2: Preprocesamiento y corrección de iluminación
%
% Objetivo:
%   - Convertir las imágenes a tipo double para procesamiento.
%   - Aplicar suavizado gaussiano moderado.
%   - Aplicar filtro de mediana sobre el canal V.
%   - Calcular una versión ecualizada del canal V como análisis.
%   - Definir qué versión del canal V se usará para fases posteriores.
%
% Importante:
%   La clasificación de colores debe evitar alterar demasiado H y S.
%   Por eso, la ecualización del canal V se calcula como comparación,
%   pero no se usa por defecto para clasificar colores.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 2: Preprocesamiento\n');
    fprintf('=================================================\n');

    %% ------------------------------------------------------------
    % 1. Conversión de imágenes RGB a double
    % ------------------------------------------------------------

    img1_double = im2double(datos.img1);
    img2_double = im2double(datos.img2);

    fprintf('Imágenes convertidas a formato double.\n');


    %% ------------------------------------------------------------
    % 2. Suavizado espacial de imágenes RGB
    % ------------------------------------------------------------

    % Filtro gaussiano suave para reducir ruido sin deformar demasiado
    % los bordes del cubo ni los límites entre stickers.
    img1_gauss = imgaussfilt(img1_double, cfg.sigma_gauss);
    img2_gauss = imgaussfilt(img2_double, cfg.sigma_gauss);

    fprintf('Filtro gaussiano aplicado con sigma = %.2f.\n', cfg.sigma_gauss);


    %% ------------------------------------------------------------
    % 3. Conversión de imágenes suavizadas a HSV
    % ------------------------------------------------------------

    hsv1_gauss = rgb2hsv(img1_gauss);
    hsv2_gauss = rgb2hsv(img2_gauss);

    H1_gauss = hsv1_gauss(:,:,1);
    S1_gauss = hsv1_gauss(:,:,2);
    V1_gauss = hsv1_gauss(:,:,3);

    H2_gauss = hsv2_gauss(:,:,1);
    S2_gauss = hsv2_gauss(:,:,2);
    V2_gauss = hsv2_gauss(:,:,3);


    %% ------------------------------------------------------------
    % 4. Suavizado del canal V con filtro de mediana
    % ------------------------------------------------------------

    % La mediana reduce ruido puntual en el brillo sin modificar tanto
    % las regiones grandes de color.
    V1_mediana = medfilt2(datos.V1, cfg.mediana_kernel);
    V2_mediana = medfilt2(datos.V2, cfg.mediana_kernel);

    fprintf('Filtro de mediana aplicado al canal V con kernel [%d %d].\n', ...
        cfg.mediana_kernel(1), cfg.mediana_kernel(2));


    %% ------------------------------------------------------------
    % 5. Ecualización adaptativa del canal V
    % ------------------------------------------------------------

    % La ecualización adaptativa puede mejorar contraste, pero también
    % puede alterar la relación entre blanco y amarillo. Por eso la
    % calculamos para análisis, no como opción principal.
    V1_eq = adapthisteq(datos.V1, ...
        'ClipLimit', cfg.clahe_clip_limit, ...
        'NumTiles', cfg.clahe_num_tiles);

    V2_eq = adapthisteq(datos.V2, ...
        'ClipLimit', cfg.clahe_clip_limit, ...
        'NumTiles', cfg.clahe_num_tiles);

    fprintf('Ecualización adaptativa del canal V calculada para análisis.\n');


    %% ------------------------------------------------------------
    % 6. Definición del canal V procesado para siguientes fases
    % ------------------------------------------------------------

    if cfg.usar_V_ecualizado
        V1_proc = V1_eq;
        V2_proc = V2_eq;
        metodo_V = 'V ecualizado con adapthisteq';
    else
        V1_proc = V1_mediana;
        V2_proc = V2_mediana;
        metodo_V = 'V suavizado con mediana';
    end

    % Para fases posteriores mantenemos H y S originales,
    % y solo usamos V procesado para máscaras o separación de fondo.
    hsv1_proc = cat(3, datos.H1, datos.S1, V1_proc);
    hsv2_proc = cat(3, datos.H2, datos.S2, V2_proc);

    fprintf('Canal V seleccionado para fases posteriores: %s.\n', metodo_V);


    %% ------------------------------------------------------------
    % 7. Visualizaciones de preprocesamiento
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        % Comparación RGB original vs suavizado
        figure('Name','Fase 2 - Suavizado RGB','NumberTitle','off');

        subplot(2,2,1);
        imshow(datos.img1);
        title('Imagen 1 original');

        subplot(2,2,2);
        imshow(img1_gauss);
        title('Imagen 1 con Gauss');

        subplot(2,2,3);
        imshow(datos.img2);
        title('Imagen 2 original');

        subplot(2,2,4);
        imshow(img2_gauss);
        title('Imagen 2 con Gauss');


        % Comparación del canal V - Imagen 1
        figure('Name','Fase 2 - Canal V Imagen 1','NumberTitle','off');

        subplot(2,2,1);
        imshow(datos.V1, []);
        title('V original');

        subplot(2,2,2);
        imshow(V1_mediana, []);
        title('V con mediana');

        subplot(2,2,3);
        imshow(V1_gauss, []);
        title('V desde RGB gaussiano');

        subplot(2,2,4);
        imshow(V1_eq, []);
        title('V ecualizado');


        % Comparación del canal V - Imagen 2
        figure('Name','Fase 2 - Canal V Imagen 2','NumberTitle','off');

        subplot(2,2,1);
        imshow(datos.V2, []);
        title('V original');

        subplot(2,2,2);
        imshow(V2_mediana, []);
        title('V con mediana');

        subplot(2,2,3);
        imshow(V2_gauss, []);
        title('V desde RGB gaussiano');

        subplot(2,2,4);
        imshow(V2_eq, []);
        title('V ecualizado');


        % Histogramas comparativos del canal V
        figure('Name','Fase 2 - Histogramas comparativos V Imagen 1', ...
               'NumberTitle','off');

        subplot(1,3,1);
        histogram(datos.V1(:), cfg.numBins);
        title('V original');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);

        subplot(1,3,2);
        histogram(V1_mediana(:), cfg.numBins);
        title('V mediana');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);

        subplot(1,3,3);
        histogram(V1_eq(:), cfg.numBins);
        title('V ecualizado');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);


        figure('Name','Fase 2 - Histogramas comparativos V Imagen 2', ...
               'NumberTitle','off');

        subplot(1,3,1);
        histogram(datos.V2(:), cfg.numBins);
        title('V original');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);

        subplot(1,3,2);
        histogram(V2_mediana(:), cfg.numBins);
        title('V mediana');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);

        subplot(1,3,3);
        histogram(V2_eq(:), cfg.numBins);
        title('V ecualizado');
        xlabel('V');
        ylabel('Píxeles');
        xlim([0 1]);

    end

    %% ------------------------------------------------------------
    % 8. Guardado de resultados de la Fase 2
    % ------------------------------------------------------------

    datos.img1_double = img1_double;
    datos.img2_double = img2_double;

    datos.img1_gauss = img1_gauss;
    datos.img2_gauss = img2_gauss;

    datos.hsv1_gauss = hsv1_gauss;
    datos.hsv2_gauss = hsv2_gauss;

    datos.H1_gauss = H1_gauss;
    datos.S1_gauss = S1_gauss;
    datos.V1_gauss = V1_gauss;

    datos.H2_gauss = H2_gauss;
    datos.S2_gauss = S2_gauss;
    datos.V2_gauss = V2_gauss;

    datos.V1_mediana = V1_mediana;
    datos.V2_mediana = V2_mediana;

    datos.V1_eq = V1_eq;
    datos.V2_eq = V2_eq;

    datos.V1_proc = V1_proc;
    datos.V2_proc = V2_proc;

    datos.hsv1_proc = hsv1_proc;
    datos.hsv2_proc = hsv2_proc;

    datos.metodo_V = metodo_V;


    %% ------------------------------------------------------------
    % 9. Resumen técnico
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 2 ================\n');
    fprintf('1. Se convirtieron las imágenes RGB a formato double.\n');
    fprintf('2. Se aplicó filtro gaussiano para reducir ruido visual.\n');
    fprintf('3. Se suavizó el canal V mediante filtro de mediana.\n');
    fprintf('4. Se calculó V ecualizado como comparación.\n');
    fprintf('5. Para fases posteriores se seleccionó: %s.\n', metodo_V);
    fprintf('6. H y S se conservan sin alteración para no distorsionar el color.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 2 finalizada correctamente.\n');

end