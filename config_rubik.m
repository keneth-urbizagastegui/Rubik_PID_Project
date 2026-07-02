function cfg = config_rubik()
% ================================================================
% CONFIG_RUBIK
% Configuración general del proyecto:
% Identificación de posición de cubo de Rubik mediante procesamiento
% de imágenes en MATLAB.
%
% Aquí se centralizan:
%   - rutas,
%   - parámetros de visualización,
%   - preprocesamiento,
%   - extracción de ROI,
%   - segmentación por color,
%   - regionprops,
%   - K-means de MATLAB.
% ================================================================


    %% ============================================================
    % 1. RUTAS DEL PROYECTO Y SELECCIÓN DE CASO
    % ============================================================

    % Activar lectura por dataset.
    % true  = lee desde dataset/caso_XXX/
    % false = lee desde imagenes/IMG1_CbRb.png y IMG2_CbRb.png
    cfg.usar_dataset = true;

    % Caso actual que se desea procesar.
    % Para probar otro caso, cambia solo esta línea.
    cfg.caso_actual = 'caso_001';

    if cfg.usar_dataset

        % Carpeta principal del dataset.
        cfg.dataset_dir = 'dataset';

        % Carpeta del caso actual.
        cfg.caso_dir = fullfile(cfg.dataset_dir, cfg.caso_actual);

        % Imágenes del caso actual.
        cfg.img1_path = fullfile(cfg.caso_dir, 'img1.png');
        cfg.img2_path = fullfile(cfg.caso_dir, 'img2.png');

        % Ground truth del caso actual.
        cfg.ground_truth_path = fullfile(cfg.caso_dir, 'ground_truth_cubo.csv');

        % Carpeta base de resultados.
        cfg.resultados_base_dir = 'resultados';

        % Carpeta de resultados específica del caso actual.
        cfg.resultados_dir = fullfile(cfg.resultados_base_dir, cfg.caso_actual);

    else

        % Modo anterior con las imágenes originales.
        cfg.img1_path = fullfile('imagenes', 'IMG1_CbRb.png');
        cfg.img2_path = fullfile('imagenes', 'IMG2_CbRb.png');

        cfg.ground_truth_path = '';

        cfg.resultados_dir = 'resultados';

    end

    % Crear carpeta de resultados si no existe.
    if ~exist(cfg.resultados_dir, 'dir')
        mkdir(cfg.resultados_dir);
    end


    %% ============================================================
    % 2. OPCIONES GENERALES DE VISUALIZACIÓN
    % ============================================================

    cfg.mostrar_figuras = true;
    cfg.guardar_figuras = false;

    % Número de barras para histogramas HSV.
    cfg.numBins = 50;


    %% ============================================================
    % 3. FASE 1: ANÁLISIS INICIAL HSV
    % ============================================================

    % Umbral preliminar para separar fondo oscuro usando canal V.
    % Se usa principalmente para análisis exploratorio.
    cfg.umbral_fondo_V = 0.45;


    %% ============================================================
    % 4. FASE 2: PREPROCESAMIENTO
    % ============================================================

    % Filtro gaussiano suave.
    % Reduce ruido sin borrar demasiado los bordes de los stickers.
    cfg.sigma_gauss = 1.0;

    % Filtro de mediana aplicado al canal V.
    % Ayuda a reducir ruido puntual manteniendo la forma del cubo.
    cfg.mediana_kernel = [3 3];

    % Parámetros de ecualización adaptativa.
    % Se calcula solo como análisis comparativo.
    cfg.clahe_clip_limit = 0.01;
    cfg.clahe_num_tiles = [8 8];

    % Para el pipeline principal usamos V suavizado, no V ecualizado.
    % La ecualización puede alterar blanco/amarillo y reflejos.
    cfg.usar_V_ecualizado = false;

    %% ============================================================
    % 5. FASE 3: EXTRACCIÓN DE ROI DEL CUBO
    % ============================================================

    % Método de extracción de ROI:
    %
    % 'v_simple'
    %     Método anterior basado solo en el canal V.
    %
    % 'hsv_stickers_convexhull'
    %     Método recomendado para el dataset nuevo.
    %     Detecta stickers usando S y V, luego reconstruye la silueta
    %     completa del cubo con morfología y convex hull.
    cfg.metodo_roi = 'hsv_stickers_convexhull';

    % Umbral de respaldo basado en V.
    % Se usa solo si el método HSV no logra una máscara suficiente.
    cfg.umbral_roi_V = 0.45;

    % Área mínima para eliminar manchas pequeñas en la máscara inicial.
    cfg.area_min_roi_component = 120;

    % Área mínima final del cubo.
    cfg.area_min_roi = 1000;

    % Morfología para unir stickers y compactar la silueta.
    cfg.radio_cierre_roi = 8;
    cfg.radio_dilatacion_roi = 6;

    % Activar convex hull para recuperar la silueta completa del cubo.
    cfg.usar_convex_hull_roi = true;

    % Margen alrededor del bounding box del cubo.
    cfg.padding_roi = 8;

    % -------------------------------
    % ROI por stickers coloreados
    % -------------------------------

    % Los stickers coloreados tienen saturación alta y brillo suficiente.
    cfg.roi_S_min_color = 0.35;
    cfg.roi_V_min_color = 0.35;

    % -------------------------------
    % ROI por stickers blancos
    % -------------------------------

    % Los stickers blancos tienen saturación baja, pero brillo alto.
    cfg.roi_S_max_white = 0.35;
    cfg.roi_V_min_white = 0.60;

    %% ============================================================
    % 6. FASE 4: SEGMENTACIÓN PRELIMINAR DE STICKERS
    % ============================================================

    % Stickers coloreados:
    % Se reduce ligeramente S_min porque en el nuevo dataset algunos
    % amarillos, verdes y azules pierden saturación por iluminación.
    cfg.sticker_S_min_color = 0.20;
    cfg.sticker_V_min_color = 0.20;

    % Stickers blancos:
    % El blanco tiene saturación baja y brillo alto.
    % Se mantiene relativamente flexible por reflejos e iluminación.
    cfg.sticker_S_max_white = 0.36;
    cfg.sticker_V_min_white = 0.48;

    % Limpieza general de fragmentos pequeños.
    cfg.area_min_fragmento_sticker = 40;

    % Morfología suave para la máscara general de stickers.
    % El cierre se deja en 0 para evitar unir stickers vecinos.
    cfg.radio_open_sticker = 1;
    cfg.radio_close_sticker = 0;

    %% ============================================================
    % 7. FASE 4: RANGOS HSV APROXIMADOS POR COLOR
    % ============================================================

    % Estos rangos son preliminares y se usan para proponer candidatos.
    % La clasificación final se hará con el color central y K-means.

    % Rojo:
    % Puede aparecer cerca de H = 0 o cerca de H = 1.
    cfg.H_red_1 = [0.00 0.05];
    cfg.H_red_2 = [0.93 1.00];

    % Naranja:
    % Se deja en la zona cálida baja.
    % No debe solaparse demasiado con amarillo.
    cfg.H_orange = [0.03 0.115];

    % Amarillo:
    % Se separa del naranja para evitar que lo absorba.
    % Los amarillos que queden fuera de este rango se recuperan con RGB.
    cfg.H_yellow = [0.115 0.27];

    % Verde:
    % Se mantiene separado del azul.
    cfg.H_green = [0.24 0.47];

    % Azul:
    % Azul/cian del nuevo dataset.
    cfg.H_blue = [0.47 0.72];


    %% ------------------------------------------------------------
    % Regla adicional RGB para amarillo
    % ------------------------------------------------------------

    % El amarillo se caracteriza por R y G altos, y B bajo.
    cfg.usar_regla_rgb_amarillo = true;

    cfg.yellow_R_min = 0.50;
    cfg.yellow_G_min = 0.45;
    cfg.yellow_B_max = 0.45;

    % Diferencia mínima entre canales cálidos y azul.
    cfg.yellow_RB_min = 0.16;
    cfg.yellow_GB_min = 0.16;

    % Para separar amarillo de naranja:
    % en amarillo R y G son relativamente cercanos.
    % Si está muy bajo, pierde amarillos.
    % Si está muy alto, puede capturar naranja.
    cfg.yellow_RG_diff_max = 0.35;

    % Condiciones HSV adicionales para evitar ruido.
    cfg.yellow_S_min = 0.18;
    cfg.yellow_V_min = 0.42;

    % Mantener prioridad, pero ahora con menos solapamiento H.
    cfg.priorizar_amarillo_sobre_naranja = true;

    %% ============================================================
    % 8. FASE 4: LIMPIEZA DE MÁSCARAS POR COLOR
    % ============================================================
    
    % Estos parámetros se conservan para visualización y diagnóstico.
    % La extracción principal de stickers se hará geométricamente en Fase 5.
    
    % Apertura para eliminar líneas delgadas y ruido fino.
    cfg.radio_open_color = 2;
    
    % Cierre pequeño para recuperar continuidad dentro del sticker.
    cfg.radio_close_color = 1;
    
    % Filtro geométrico para componentes por color.
    cfg.area_min_color_component = 300;
    cfg.area_max_color_component = 9000;
    
    cfg.ancho_min_color_component = 12;
    cfg.alto_min_color_component  = 12;
    
    cfg.solidez_min_color_component = 0.40;
    cfg.extent_min_color_component  = 0.20;
    
    cfg.aspect_min_color_component = 0.20;
    cfg.aspect_max_color_component = 4.50;
    
    
    %% ============================================================
    % 9. FASE 5: EXTRACCIÓN GEOMÉTRICA DE CANDIDATOS
    % ============================================================
    
    % Método principal:
    % 'geometrico' genera exactamente 27 candidatos por imagen usando:
    %   - polígonos de caras,
    %   - transformación proyectiva,
    %   - grilla 3x3 por cara.
    cfg.modo_extraccion_candidatos = 'geometrico';
    
    % Para evitar confusión visual durante las pruebas del dataset,
    % desactivamos regionprops como diagnóstico.
    % Si quieres comparar luego, puedes ponerlo en true.
    cfg.usar_regionprops_diagnostico = false;
    
    % Número esperado de stickers por imagen.
    cfg.stickers_por_imagen = 27;
    
    % Grilla 3x3 del cubo Rubik.
    cfg.grid_n = 3;
    
    % Tamaño de cada cara rectificada.
    cfg.face_warp_size = 300;
    
    % Radio del parche central usado para estimar el color.
    cfg.radio_patch_color = 8;
    
    % Margen interno de cada celda.
    % Se sube de 0.25 a 0.30 para evitar bordes, sombras y mezcla
    % con stickers vecinos. Esto ayuda a no confundir blanco con amarillo.
    cfg.margen_interno_celda = 0.30;
    
    % Usar estadística robusta del color central.
    % La mediana es menos sensible a bordes, reflejos y sombras.
    cfg.usar_mediana_color = true;
    
    % Mostrar candidatos generados geométricamente.
    cfg.mostrar_candidatos_geometricos = true;
    
    % Guardar tabla de candidatos por imagen.
    cfg.guardar_candidatos_fase5 = true;
    
    cfg.candidatos_dir = fullfile(cfg.resultados_dir, 'candidatos_fase5');
    
    if ~exist(cfg.candidatos_dir, 'dir')
        mkdir(cfg.candidatos_dir);
    end
    
    
    %% ============================================================
    % 9.1 REGLAS DE COLOR PARA FASE 5
    % ============================================================
    
    % Activar corrección individual del color después de K-means.
    cfg.aplicar_correccion_color_individual = true;
    
    % Dar prioridad al blanco antes que al amarillo.
    cfg.priorizar_blanco_sobre_amarillo = true;
    
    % -------------------------------
    % Regla robusta para BLANCO
    % -------------------------------
    
    cfg.white_S_max = 0.45;
    cfg.white_V_min = 0.30;
    
    cfg.white_R_min = 0.30;
    cfg.white_G_min = 0.30;
    cfg.white_B_min = 0.30;
    
    % En blanco, R, G y B suelen ser parecidos.
    cfg.white_RGB_diff_max = 0.38;
    
    % Regla segura: si los tres canales son muy parecidos, es blanco.
    cfg.white_RGB_diff_seguro = 0.28;
    
    % -------------------------------
    % Regla estricta para AMARILLO
    % -------------------------------
    
    cfg.yellow_S_min = 0.35;
    cfg.yellow_V_min = 0.35;
    
    cfg.yellow_R_min = 0.50;
    cfg.yellow_G_min = 0.45;
    cfg.yellow_B_max = 0.42;
    
    % Para que sea amarillo, B debe ser claramente menor.
    cfg.yellow_RB_min = 0.24;
    cfg.yellow_GB_min = 0.20;
    
    % En amarillo R y G son cercanos.
    cfg.yellow_RG_diff_max = 0.32;
    
    cfg.yellow_B_debe_ser_menor_que_R_y_G = true;
    
    % -------------------------------
    % Regla para NARANJA
    % -------------------------------
    
    cfg.orange_RG_min = 0.06;
    cfg.orange_RB_min = 0.18;
        
    %% ============================================================
    % 9.2 PARÁMETROS ANTIGUOS DE REGIONPROPS
    % ============================================================
    
    % Estos parámetros se conservan solo si:
    % cfg.usar_regionprops_diagnostico = true
    %
    % No son la base principal del pipeline.
    
    cfg.area_min_sticker = 700;
    cfg.area_max_sticker = 7500;
    
    cfg.solidez_min_sticker = 0.55;
    cfg.extent_min_sticker  = 0.30;
    
    cfg.aspect_min_sticker = 0.30;
    cfg.aspect_max_sticker = 2.50;
    
    cfg.eliminar_duplicados = true;
    cfg.distancia_dup_px = 14;
    
    
    %% ============================================================
    % 10. FASE 5: K-MEANS DE MATLAB
    % ============================================================
    
    % Activar agrupamiento adaptativo de colores.
    cfg.usar_kmeans = true;
    
    % Número de grupos: seis colores del cubo.
    cfg.kmeans_K_colores = 6;
    
    % Parámetros para kmeans() de MATLAB.
    cfg.kmeans_replicates = 10;
    cfg.kmeans_max_iter = 200;
    
    % Espacio de color usado por K-means.
    % HSV funciona, pero Lab suele separar mejor blanco/amarillo/azul
    % cuando cambia la iluminación.
    cfg.kmeans_espacio_color = 'lab';
    
    % Aplicar reglas blanco/amarillo antes o después de K-means.
    % Recomendado: aplicar corrección posterior para evitar blancos como amarillos.
    cfg.aplicar_correccion_blanco_amarillo = true;

    %% ============================================================
    % 11. FASE 6: ASIGNACIÓN GEOMÉTRICA POR CARAS
    % ============================================================

    % Cada imagen muestra tres caras visibles del cubo.
    cfg.num_caras_visibles = 3;

    % Cada cara visible debe contener 9 stickers.
    cfg.stickers_por_cara = 9;

    % Tamaño de cada cara luego de la rectificación geométrica.
    % Cada cara será transformada a una vista frontal cuadrada.
    cfg.face_warp_size = 300;


    %% ------------------------------------------------------------
    % 11.1 MODO DE OBTENCIÓN DE ESQUINAS
    % ------------------------------------------------------------

    % Modo para obtener los polígonos de las caras:
    %
    % 'manual'
    %     Siempre pide seleccionar las esquinas con clics.
    %
    % 'hough'
    %     Usa Canny + Hough. Si falla, genera error.
    %
    % 'hough_manual_fallback'
    %     Primero intenta Canny + Hough.
    %     Si no logra esquinas confiables, activa selección manual.
    %
    cfg.modo_poligonos_caras = 'hough';

    % Esta variable queda solo como referencia de compatibilidad.
    % La nueva versión usará cfg.modo_poligonos_caras.
    cfg.usar_seleccion_manual_caras = false;


    %% ------------------------------------------------------------
    % 11.2 GUARDADO Y REUTILIZACIÓN DE POLÍGONOS
    % ------------------------------------------------------------

    % Guardar los polígonos detectados o seleccionados.
    cfg.guardar_poligonos_caras = true;

    % Reutilizar polígonos guardados en ejecuciones posteriores.
    cfg.reutilizar_poligonos_caras = true;

    % IMPORTANTE:
    % Como ya tienes polígonos guardados de la selección manual anterior,
    % para probar Hough por primera vez deja esto en true.
    %
    % Después de verificar que Hough funciona bien, puedes volverlo a false.
    cfg.forzar_nueva_seleccion_caras = false;

    % Carpeta donde se guardarán los puntos seleccionados o detectados.
    cfg.poligonos_dir = fullfile(cfg.resultados_dir, 'poligonos_caras');

    if ~exist(cfg.poligonos_dir, 'dir')
        mkdir(cfg.poligonos_dir);
    end


    %% ------------------------------------------------------------
    % 11.3 K-MEANS ESPACIAL SOLO COMO DIAGNÓSTICO
    % ------------------------------------------------------------

    % K-means espacial se usará solo como diagnóstico visual,
    % no como criterio final de asignación de cara.
    cfg.usar_kmeans_espacial_diagnostico = false;

    % Parámetros de kmeans() para diagnóstico espacial.
    cfg.kmeans_K_caras = 3;
    cfg.kmeans_caras_replicates = 20;
    cfg.kmeans_caras_max_iter = 200;


    %% ------------------------------------------------------------
    % 11.4 RECTIFICACIÓN GEOMÉTRICA
    % ------------------------------------------------------------

    % Mostrar las caras rectificadas mediante transformación proyectiva.
    cfg.mostrar_caras_rectificadas = true;

    % Tolerancia para aceptar puntos transformados cerca del borde
    % de una cara rectificada.
    cfg.tolerancia_cara_px = 10;


    %% ------------------------------------------------------------
    % 11.5 PARÁMETROS CANNY + HOUGH PARA DETECCIÓN DE ESQUINAS
    % ------------------------------------------------------------

    % Mostrar figura de diagnóstico con:
    % - bordes Canny,
    % - líneas Hough,
    % - intersecciones,
    % - polígonos estimados.
    cfg.hough_mostrar_diagnostico = false;

    % Sigma para suavizado antes de Canny.
    % Aumentar si hay mucho ruido.
    % Reducir si se pierden bordes importantes.
    cfg.hough_canny_sigma = 1.4;

    % Resolución angular de Hough en grados.
    % Menor valor = más precisión, mayor costo computacional.
    cfg.hough_theta_step = 0.5;

    % Número máximo de picos buscados en el acumulador de Hough.
    cfg.hough_num_peaks = 45;

    % Factor de umbral para detectar picos de Hough.
    % Se multiplica por max(H(:)).
    % Si detecta pocas líneas, bajar a 0.10.
    % Si detecta demasiadas líneas falsas, subir a 0.20.
    cfg.hough_peak_threshold_factor = 0.20;

    % Distancia máxima para unir segmentos de línea cercanos.
    % Aumentar si los bordes aparecen fragmentados.
    cfg.hough_fill_gap = 30;

    % Longitud mínima de línea aceptada.
    % Aumentar si aparecen muchas líneas pequeñas internas.
    % Reducir si no detecta bordes del cubo.
    cfg.hough_min_length = 35;

    % Margen permitido para aceptar intersecciones cerca del cubo.
    cfg.hough_margen_interseccion = 25;

    % Tolerancia para simplificar el contorno exterior del cubo.
    % Valores pequeños conservan más detalle.
    cfg.hough_reducepoly_tol = 0.015;

    %% ------------------------------------------------------------
    % 11.6 CONTROL DE CALIDAD DE POLIGONOS HOUGH
    % ------------------------------------------------------------

    % Activar validacion geometrica de los poligonos detectados.
    cfg.hough_validar_poligonos = true;

    % Mostrar reporte numerico de validacion de poligonos.
    cfg.hough_mostrar_reporte_validacion = false;

    % Area minima relativa de cada cara respecto al area total del cubo.
    % Si una cara es muy pequena, probablemente Hough fallo.
    cfg.hough_area_min_rel = 0.08;

    % Area maxima relativa de cada cara respecto al area total del cubo.
    % Si una cara es demasiado grande, probablemente el poligono invade otra cara.
    cfg.hough_area_max_rel = 0.45;

    % Solapamiento minimo entre cada poligono y la mascara del cubo.
    % Valor alto exige que el poligono realmente caiga sobre el cubo.
    cfg.hough_overlap_min = 0.55;

    % Cobertura minima de la union de las tres caras sobre la mascara del cubo.
    cfg.hough_union_mask_min = 0.60;

    % Relacion maxima permitida entre el area de la cara mas grande
    % y el area de la cara mas pequena.
    cfg.hough_ratio_area_max = 3.50;

    % Exigir que el punto central C caiga dentro de la mascara del cubo.
    cfg.hough_validar_centro_en_mask = true;

    % Margen permitido para vertices ligeramente fuera de la imagen.
    cfg.hough_margen_vertices_px = 10;

    %% ------------------------------------------------------------
    % 11.7 SALIDA DE AGRUPACIÓN DE FASE 6
    % ------------------------------------------------------------

    % Guardar tabla de agrupación por caras.
    cfg.guardar_agrupacion_caras = true;

    cfg.agrupacion_caras_dir = fullfile(cfg.resultados_dir, 'agrupacion_caras');

    if ~exist(cfg.agrupacion_caras_dir, 'dir')
        mkdir(cfg.agrupacion_caras_dir);
    end

    %% ============================================================
    % 12. FASE 7: MATRICES 3x3 POR CARA
    % ============================================================

    % Color final que se usará para construir las matrices.
    % Se recomienda usar color_kmeans porque es la clasificación adaptativa.
    cfg.campo_color_final = 'color_kmeans';

    % Mostrar matrices 3x3 en consola.
    cfg.mostrar_matrices_consola = true;

    % Mostrar matrices 3x3 como gráfico.
    cfg.mostrar_matrices_graficas = true;

    % Guardar tablas de matrices.
    cfg.guardar_matrices_caras = true;

    cfg.matrices_dir = fullfile(cfg.resultados_dir, 'matrices_caras');

    if ~exist(cfg.matrices_dir, 'dir')
        mkdir(cfg.matrices_dir);
    end

    %% ============================================================
    % 13. FASE 8: INTEGRACIÓN DE LAS SEIS CARAS DEL CUBO
    % ============================================================

    % Colores esperados en un cubo Rubik estándar.
    cfg.colores_cubo = {'blanco', 'amarillo', 'rojo', 'naranja', 'verde', 'azul'};

    % Validar que aparezcan las seis caras una sola vez.
    cfg.validar_centros_unicos = true;

    % Mostrar el cubo integrado en consola.
    cfg.mostrar_cubo_integrado_consola = true;

    % Mostrar visualización gráfica de las seis caras.
    cfg.mostrar_cubo_integrado_grafico = true;

    % Guardar resultados de integración.
    cfg.guardar_cubo_integrado = true;

    cfg.cubo_integrado_dir = fullfile(cfg.resultados_dir, 'cubo_integrado');

    if ~exist(cfg.cubo_integrado_dir, 'dir')
        mkdir(cfg.cubo_integrado_dir);
    end

    % Por ahora no rotamos matrices.
    % Las caras se guardan en la orientación detectada.
    cfg.aplicar_rotaciones_estandar = false;

    %% ============================================================
    % 14. FASE 9: EVALUACION CUANTITATIVA
    % ============================================================

    % Activar evaluacion del cubo reconstruido.
    cfg.evaluar_cubo = true;

    % Mostrar metricas en consola.
    cfg.mostrar_metricas_consola = true;

    % Mostrar matriz de confusion como grafico.
    cfg.mostrar_matriz_confusion = true;

    % Guardar resultados de evaluacion.
    cfg.guardar_evaluacion = true;

    cfg.evaluacion_dir = fullfile(cfg.resultados_dir, 'evaluacion');

    if ~exist(cfg.evaluacion_dir, 'dir')
        mkdir(cfg.evaluacion_dir);
    end

    %% ============================================================
    % 15. FASE 10: REPORTE FINAL DEL PIPELINE
    % ============================================================

    % Mostrar reporte final en consola.
    cfg.mostrar_reporte_final_consola = true;

    % Guardar reporte final en archivos.
    cfg.guardar_reporte_final = true;

    cfg.reporte_final_dir = fullfile(cfg.resultados_dir, 'reporte_final');

    if ~exist(cfg.reporte_final_dir, 'dir')
        mkdir(cfg.reporte_final_dir);
    end

    %% ============================================================
    % 16. FASE 11: PRUEBA MASIVA CON DATASET
    % ============================================================

    % Activar prueba masiva sobre varios casos.
    cfg.ejecutar_prueba_masiva = true;

    % Casos que se evaluarán.
    % Primero puedes probar con 1:3. Cuando funcione, usa 1:20.
    cfg.casos_masivos = arrayfun(@(k) sprintf('caso_%03d', k), ...
        1:20, ...
        'UniformOutput', false);

    % Carpeta donde se guardará el resumen general de la prueba masiva.
    cfg.resultados_masivos_dir = fullfile(cfg.resultados_base_dir, 'prueba_masiva');

    if ~exist(cfg.resultados_masivos_dir, 'dir')
        mkdir(cfg.resultados_masivos_dir);
    end

    % En prueba masiva conviene apagar figuras para no abrir muchas ventanas.
    cfg.mostrar_figuras_masivo = false;

    % Modo recomendado para prueba masiva:
    % 'hough' = automático. Si falla, registra error y pasa al siguiente caso.
    % 'hough_manual_fallback' = puede pedir clics manuales si Hough falla.
    cfg.modo_poligonos_masivo = 'hough';

    % Reutilizar polígonos si ya existen guardados para un caso.
    cfg.reutilizar_poligonos_masivo = true;

    % No forzar nueva selección en prueba masiva.
    cfg.forzar_nueva_seleccion_masivo = false;

    % Guardar reporte individual de cada caso.
    % Para prueba rápida déjalo en false. Para entrega final puedes poner true.
    cfg.generar_reporte_caso_masivo = false;

    % Mostrar gráfico final de accuracy por caso.
    cfg.mostrar_grafico_masivo = true;

    % Continuar aunque un caso falle.
    cfg.continuar_si_falla_caso = true;

    %% ============================================================
    % 17. FASE 12: RESULTADOS GLOBALES DEL DATASET
    % ============================================================

    % Carpeta donde se guardaran los resultados consolidados.
    cfg.fase12_dir = fullfile(cfg.resultados_masivos_dir, 'fase12_resultados');

    if ~exist(cfg.fase12_dir, 'dir')
        mkdir(cfg.fase12_dir);
    end

    % Colores usados para la matriz de confusion global.
    cfg.colores_eval = {'B', 'A', 'R', 'N', 'V', 'Az'};

    % Mostrar graficos de la Fase 12.
    cfg.mostrar_figuras_fase12 = true;

    % Guardar graficos como imagen PNG.
    cfg.guardar_figuras_fase12 = true;

    % Guardar tablas consolidadas.
    cfg.guardar_tablas_fase12 = true;
end