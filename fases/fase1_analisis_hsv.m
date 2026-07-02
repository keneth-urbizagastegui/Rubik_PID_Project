function datos = fase1_analisis_hsv(cfg)
% ================================================================
% FASE 1: Lectura y análisis inicial RGB / HSV / Histogramas
%
% Objetivo:
%   - Leer las dos imágenes del cubo de Rubik.
%   - Verificar dimensiones.
%   - Convertir de RGB a HSV.
%   - Visualizar canales H, S y V.
%   - Analizar histogramas completos.
%   - Generar una máscara preliminar para excluir fondo oscuro.
%   - Analizar histogramas sin fondo.
%
% Salida:
%   datos: estructura con imágenes, canales HSV, máscaras preliminares
%          y estadísticas básicas de la fase.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 1: Análisis inicial RGB / HSV\n');
    fprintf('=================================================\n');

    %% ------------------------------------------------------------
    % 1. Verificación de archivos
    % ------------------------------------------------------------

    if ~isfile(cfg.img1_path)
        error('No se encontró la Imagen 1 en la ruta: %s', cfg.img1_path);
    end

    if ~isfile(cfg.img2_path)
        error('No se encontró la Imagen 2 en la ruta: %s', cfg.img2_path);
    end

    fprintf('Imagen 1 encontrada: %s\n', cfg.img1_path);
    fprintf('Imagen 2 encontrada: %s\n', cfg.img2_path);


    %% ------------------------------------------------------------
    % 2. Lectura de imágenes RGB
    % ------------------------------------------------------------

    img1 = imread(cfg.img1_path);
    img2 = imread(cfg.img2_path);

    tam_img1 = size(img1);
    tam_img2 = size(img2);

    fprintf('\nTamaño Imagen 1: %d x %d x %d\n', ...
        tam_img1(1), tam_img1(2), tam_img1(3));

    fprintf('Tamaño Imagen 2: %d x %d x %d\n', ...
        tam_img2(1), tam_img2(2), tam_img2(3));


    %% ------------------------------------------------------------
    % 3. Conversión RGB a HSV
    % ------------------------------------------------------------

    hsv1 = rgb2hsv(img1);
    hsv2 = rgb2hsv(img2);

    % Canales HSV - Imagen 1
    H1 = hsv1(:,:,1);
    S1 = hsv1(:,:,2);
    V1 = hsv1(:,:,3);

    % Canales HSV - Imagen 2
    H2 = hsv2(:,:,1);
    S2 = hsv2(:,:,2);
    V2 = hsv2(:,:,3);

    fprintf('Conversión RGB a HSV realizada correctamente.\n');


    %% ------------------------------------------------------------
    % 4. Máscara preliminar para excluir fondo oscuro
    % ------------------------------------------------------------

    mask_util1 = V1 > cfg.umbral_fondo_V;
    mask_util2 = V2 > cfg.umbral_fondo_V;

    porcentaje_util_img1 = 100 * nnz(mask_util1) / numel(mask_util1);
    porcentaje_util_img2 = 100 * nnz(mask_util2) / numel(mask_util2);

    fprintf('\nPorcentaje preliminar de zona útil:\n');
    fprintf('Imagen 1: %.2f %%\n', porcentaje_util_img1);
    fprintf('Imagen 2: %.2f %%\n', porcentaje_util_img2);


    %% ------------------------------------------------------------
    % 5. Visualizaciones principales de la Fase 1
    % ------------------------------------------------------------

    if cfg.mostrar_figuras

        % Imágenes originales
        figure('Name','Fase 1 - Imágenes originales RGB', ...
               'NumberTitle','off');

        subplot(1,2,1);
        imshow(img1);
        title('Imagen 1 - RGB');

        subplot(1,2,2);
        imshow(img2);
        title('Imagen 2 - RGB');


        % Canales HSV
        mostrar_canales_hsv(img1, H1, S1, V1, 'Imagen 1');
        mostrar_canales_hsv(img2, H2, S2, V2, 'Imagen 2');


        % Histogramas completos
        graficar_histogramas_hsv(H1, S1, V1, cfg.numBins, ...
            'Histogramas HSV completos - Imagen 1');

        graficar_histogramas_hsv(H2, S2, V2, cfg.numBins, ...
            'Histogramas HSV completos - Imagen 2');


        % Máscaras preliminares
        figure('Name','Fase 1 - Máscara preliminar de zona útil', ...
               'NumberTitle','off');

        subplot(2,2,1);
        imshow(img1);
        title('Imagen 1 - RGB');

        subplot(2,2,2);
        imshow(mask_util1);
        title('Máscara útil Imagen 1');

        subplot(2,2,3);
        imshow(img2);
        title('Imagen 2 - RGB');

        subplot(2,2,4);
        imshow(mask_util2);
        title('Máscara útil Imagen 2');


        % Histogramas sin fondo
        graficar_histogramas_hsv_sin_fondo(H1, S1, V1, mask_util1, ...
            cfg.numBins, 'Histogramas HSV sin fondo - Imagen 1');

        graficar_histogramas_hsv_sin_fondo(H2, S2, V2, mask_util2, ...
            cfg.numBins, 'Histogramas HSV sin fondo - Imagen 2');

    end


    %% ------------------------------------------------------------
    % 6. Guardado de resultados en estructura datos
    % ------------------------------------------------------------

    datos = struct();

    % Imágenes RGB
    datos.img1 = img1;
    datos.img2 = img2;

    % Imágenes HSV
    datos.hsv1 = hsv1;
    datos.hsv2 = hsv2;

    % Canales HSV - Imagen 1
    datos.H1 = H1;
    datos.S1 = S1;
    datos.V1 = V1;

    % Canales HSV - Imagen 2
    datos.H2 = H2;
    datos.S2 = S2;
    datos.V2 = V2;

    % Máscaras preliminares
    datos.mask_util1 = mask_util1;
    datos.mask_util2 = mask_util2;

    % Tamaños
    datos.tam_img1 = tam_img1;
    datos.tam_img2 = tam_img2;

    % Estadísticas preliminares
    datos.porcentaje_util_img1 = porcentaje_util_img1;
    datos.porcentaje_util_img2 = porcentaje_util_img2;

    % Parámetros usados en la fase
    datos.umbral_fondo_V = cfg.umbral_fondo_V;
    datos.numBins = cfg.numBins;


    %% ------------------------------------------------------------
    % 7. Resumen técnico de la Fase 1
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 1 ================\n');
    fprintf('1. Se leyeron correctamente las dos imágenes RGB.\n');
    fprintf('2. Se verificaron sus dimensiones.\n');
    fprintf('3. Se realizó la conversión RGB a HSV.\n');
    fprintf('4. El canal V permitió generar una máscara preliminar del cubo.\n');
    fprintf('5. El canal S permite distinguir stickers blancos de stickers coloreados.\n');
    fprintf('6. El canal H permite analizar los tonos, pero debe usarse junto con S y V.\n');
    fprintf('7. Los histogramas sin fondo serán útiles para definir umbrales posteriores.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 1 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Mostrar canales HSV
% ================================================================

function mostrar_canales_hsv(img_rgb, H, S, V, nombre_img)

    figure('Name',['Fase 1 - Análisis HSV - ', nombre_img], ...
           'NumberTitle','off');

    subplot(2,2,1);
    imshow(img_rgb);
    title([nombre_img, ' - RGB']);

    subplot(2,2,2);
    imshow(H, []);
    title('Canal H - Tono');

    subplot(2,2,3);
    imshow(S, []);
    title('Canal S - Saturación');

    subplot(2,2,4);
    imshow(V, []);
    title('Canal V - Brillo');

end


%% ================================================================
% FUNCIÓN LOCAL: Histogramas HSV completos
% ================================================================

function graficar_histogramas_hsv(H, S, V, numBins, titulo_figura)

    figure('Name',titulo_figura, 'NumberTitle','off');

    subplot(1,3,1);
    histogram(H(:), numBins);
    title('Histograma H - Tono');
    xlabel('H');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

    subplot(1,3,2);
    histogram(S(:), numBins);
    title('Histograma S - Saturación');
    xlabel('S');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

    subplot(1,3,3);
    histogram(V(:), numBins);
    title('Histograma V - Brillo');
    xlabel('V');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

end


%% ================================================================
% FUNCIÓN LOCAL: Histogramas HSV sin fondo
% ================================================================

function graficar_histogramas_hsv_sin_fondo(H, S, V, mask_util, numBins, titulo_figura)

    figure('Name',titulo_figura, 'NumberTitle','off');

    subplot(1,3,1);
    histogram(H(mask_util), numBins);
    title('H sin fondo');
    xlabel('H');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

    subplot(1,3,2);
    histogram(S(mask_util), numBins);
    title('S sin fondo');
    xlabel('S');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

    subplot(1,3,3);
    histogram(V(mask_util), numBins);
    title('V sin fondo');
    xlabel('V');
    ylabel('Cantidad de píxeles');
    xlim([0 1]);

end