function datos = fase8_integracion_cubo(datos, cfg)
% ================================================================
% FASE 8: Integración de las seis caras del cubo
%
% Objetivo:
%   - Tomar las matrices 3x3 obtenidas en Fase 7.
%   - Identificar cada cara por su color central.
%   - Integrar las seis caras en una sola estructura del cubo.
%   - Validar que existan las seis caras esperadas.
%
% Nota:
%   En esta fase no se resuelve el cubo ni se verifica legalidad completa.
%   Se integra la información visible reconstruida desde las dos imágenes.
% ================================================================

    fprintf('\n=================================================\n');
    fprintf('INICIANDO FASE 8: Integración de las seis caras\n');
    fprintf('=================================================\n');

    cfg = completar_cfg_fase8(cfg);

    %% ------------------------------------------------------------
    % 1. Integrar caras de ambas imágenes
    % ------------------------------------------------------------

    [cubo, tabla_integracion] = integrar_caras_desde_imagenes( ...
        datos.matrices_caras1, ...
        datos.matrices_caras2, ...
        cfg);

    %% ------------------------------------------------------------
    % 2. Validar centros
    % ------------------------------------------------------------

    reporte_validacion = validar_cubo_integrado(cubo, cfg);

    %% ------------------------------------------------------------
    % 3. Mostrar resultados en consola
    % ------------------------------------------------------------

    if cfg.mostrar_cubo_integrado_consola

        imprimir_cubo_integrado(cubo, cfg);

        fprintf('\nTabla de integración:\n');
        disp(tabla_integracion);

        fprintf('\nReporte de validación:\n');
        disp(reporte_validacion);

    end

    %% ------------------------------------------------------------
    % 4. Visualización gráfica
    % ------------------------------------------------------------

    if cfg.mostrar_figuras && cfg.mostrar_cubo_integrado_grafico

        visualizar_cubo_integrado(cubo, cfg, ...
            'Fase 8 - Cubo integrado por color central');

    end

    %% ------------------------------------------------------------
    % 5. Guardar resultados
    % ------------------------------------------------------------

    if cfg.guardar_cubo_integrado

        guardar_cubo_integrado(cubo, tabla_integracion, reporte_validacion, cfg);

    end

    %% ------------------------------------------------------------
    % 6. Guardar en estructura datos
    % ------------------------------------------------------------

    datos.cubo_integrado = cubo;
    datos.tabla_integracion_cubo = tabla_integracion;
    datos.reporte_validacion_cubo = reporte_validacion;

    %% ------------------------------------------------------------
    % 7. Resumen
    % ------------------------------------------------------------

    fprintf('\n================ RESUMEN FASE 8 ================\n');
    fprintf('Se integraron las caras visibles de ambas imágenes.\n');
    fprintf('Cada cara fue identificada por su color central.\n');
    fprintf('El cubo integrado queda disponible en datos.cubo_integrado.\n');
    fprintf('=================================================\n');

    fprintf('\nFASE 8 finalizada correctamente.\n');

end


%% ================================================================
% FUNCIÓN LOCAL: Completar configuración
% ================================================================

function cfg = completar_cfg_fase8(cfg)

    if ~isfield(cfg, 'colores_cubo')
        cfg.colores_cubo = {'blanco', 'amarillo', 'rojo', 'naranja', 'verde', 'azul'};
    end

    if ~isfield(cfg, 'validar_centros_unicos')
        cfg.validar_centros_unicos = true;
    end

    if ~isfield(cfg, 'mostrar_cubo_integrado_consola')
        cfg.mostrar_cubo_integrado_consola = true;
    end

    if ~isfield(cfg, 'mostrar_cubo_integrado_grafico')
        cfg.mostrar_cubo_integrado_grafico = true;
    end

    if ~isfield(cfg, 'guardar_cubo_integrado')
        cfg.guardar_cubo_integrado = true;
    end

    if ~isfield(cfg, 'cubo_integrado_dir')
        cfg.cubo_integrado_dir = fullfile(cfg.resultados_dir, 'cubo_integrado');
    end

    if ~exist(cfg.cubo_integrado_dir, 'dir')
        mkdir(cfg.cubo_integrado_dir);
    end

    if ~isfield(cfg, 'aplicar_rotaciones_estandar')
        cfg.aplicar_rotaciones_estandar = false;
    end

end


%% ================================================================
% FUNCIÓN LOCAL: Integrar caras desde Imagen 1 e Imagen 2
% ================================================================

function [cubo, tabla_integracion] = integrar_caras_desde_imagenes(matrices1, matrices2, cfg)

    cubo = crear_cubo_vacio(cfg);

    nombres_caras_visibles = {'superior', 'izquierda', 'derecha'};

    imagenes = {
        matrices1, 'Imagen 1';
        matrices2, 'Imagen 2'
    };

    color_centro_tabla = {};
    codigo_centro_tabla = {};
    imagen_tabla = {};
    cara_visible_tabla = {};
    estado_tabla = {};
    fila1_tabla = {};
    fila2_tabla = {};
    fila3_tabla = {};

    for img_idx = 1:size(imagenes, 1)

        matrices = imagenes{img_idx, 1};
        nombre_imagen = imagenes{img_idx, 2};

        for k = 1:numel(nombres_caras_visibles)

            cara_visible = nombres_caras_visibles{k};

            matriz_cara = matrices.(cara_visible);

            colores = matriz_cara.colores;
            codigos = matriz_cara.codigos;
            ids = matriz_cara.ids;

            color_centro = normalizar_nombre_color(colores{2,2});
            codigo_centro = codigo_color(color_centro);

            if cfg.aplicar_rotaciones_estandar
                % Reservado para una fase posterior.
                colores_final = colores;
                codigos_final = codigos;
                ids_final = ids;
            else
                colores_final = colores;
                codigos_final = codigos;
                ids_final = ids;
            end

            estado = 'integrada';

            if isfield(cubo, color_centro) && cubo.(color_centro).presente
                estado = 'duplicada';
                warning('La cara con centro %s aparece más de una vez.', color_centro);
            end

            if isfield(cubo, color_centro)

                cubo.(color_centro).presente = true;
                cubo.(color_centro).color_centro = color_centro;
                cubo.(color_centro).codigo_centro = codigo_centro;
                cubo.(color_centro).imagen_origen = nombre_imagen;
                cubo.(color_centro).cara_visible_origen = cara_visible;
                cubo.(color_centro).colores = colores_final;
                cubo.(color_centro).codigos = codigos_final;
                cubo.(color_centro).ids = ids_final;

            else

                estado = 'color_no_esperado';
                warning('Color central no esperado: %s', color_centro);

            end

            color_centro_tabla{end+1,1} = color_centro;
            codigo_centro_tabla{end+1,1} = codigo_centro;
            imagen_tabla{end+1,1} = nombre_imagen;
            cara_visible_tabla{end+1,1} = cara_visible;
            estado_tabla{end+1,1} = estado;

            fila1_tabla{end+1,1} = fila_a_texto(codigos_final, 1);
            fila2_tabla{end+1,1} = fila_a_texto(codigos_final, 2);
            fila3_tabla{end+1,1} = fila_a_texto(codigos_final, 3);

        end

    end

    tabla_integracion = table( ...
        imagen_tabla, ...
        cara_visible_tabla, ...
        color_centro_tabla, ...
        codigo_centro_tabla, ...
        estado_tabla, ...
        fila1_tabla, ...
        fila2_tabla, ...
        fila3_tabla, ...
        'VariableNames', { ...
            'imagen_origen', ...
            'cara_visible_origen', ...
            'color_centro', ...
            'codigo_centro', ...
            'estado', ...
            'fila_1', ...
            'fila_2', ...
            'fila_3' ...
        } ...
    );

end


%% ================================================================
% FUNCIÓN LOCAL: Crear estructura vacía del cubo
% ================================================================

function cubo = crear_cubo_vacio(cfg)

    cubo = struct();

    for i = 1:numel(cfg.colores_cubo)

        color = cfg.colores_cubo{i};

        cubo.(color).presente = false;
        cubo.(color).color_centro = color;
        cubo.(color).codigo_centro = codigo_color(color);
        cubo.(color).imagen_origen = '';
        cubo.(color).cara_visible_origen = '';
        cubo.(color).colores = repmat({'vacio'}, 3, 3);
        cubo.(color).codigos = repmat({'-'}, 3, 3);
        cubo.(color).ids = NaN(3, 3);

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Validar cubo integrado
% ================================================================

function reporte = validar_cubo_integrado(cubo, cfg)

    colores = cfg.colores_cubo;

    color_tabla = {};
    presente_tabla = [];
    centro_correcto_tabla = [];
    observacion_tabla = {};

    for i = 1:numel(colores)

        color = colores{i};

        presente = cubo.(color).presente;

        centro_detectado = normalizar_nombre_color(cubo.(color).colores{2,2});
        centro_correcto = presente && strcmp(centro_detectado, color);

        if ~presente
            observacion = 'cara faltante';
        elseif centro_correcto
            observacion = 'correcto';
        else
            observacion = 'centro no coincide';
        end

        color_tabla{end+1,1} = color;
        presente_tabla(end+1,1) = presente;
        centro_correcto_tabla(end+1,1) = centro_correcto;
        observacion_tabla{end+1,1} = observacion;

    end

    reporte = table( ...
        color_tabla, ...
        presente_tabla, ...
        centro_correcto_tabla, ...
        observacion_tabla, ...
        'VariableNames', { ...
            'cara', ...
            'presente', ...
            'centro_correcto', ...
            'observacion' ...
        } ...
    );

end


%% ================================================================
% FUNCIÓN LOCAL: Imprimir cubo integrado en consola
% ================================================================

function imprimir_cubo_integrado(cubo, cfg)

    fprintf('\n================ CUBO INTEGRADO ================\n');

    colores = cfg.colores_cubo;

    for i = 1:numel(colores)

        color = colores{i};

        fprintf('\nCara %s (%s):\n', upper(color), cubo.(color).codigo_centro);

        if ~cubo.(color).presente

            fprintf('Cara no detectada.\n');
            continue;

        end

        fprintf('Origen: %s - cara visible %s\n', ...
            cubo.(color).imagen_origen, ...
            cubo.(color).cara_visible_origen);

        codigos = cubo.(color).codigos;

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
% FUNCIÓN LOCAL: Visualizar cubo integrado
% ================================================================

function visualizar_cubo_integrado(cubo, cfg, titulo_figura)

    colores = cfg.colores_cubo;

    figure('Name', titulo_figura, 'NumberTitle', 'off');

    for i = 1:numel(colores)

        color = colores{i};

        subplot(2, 3, i);
        hold on;
        axis equal;
        axis ij;
        axis off;

        title(sprintf('Cara %s', upper(color)));

        xlim([0 3]);
        ylim([0 3]);

        colores_matriz = cubo.(color).colores;
        codigos_matriz = cubo.(color).codigos;

        for fila = 1:3
            for columna = 1:3

                color_nombre = colores_matriz{fila, columna};
                rgb = rgb_color(color_nombre);

                rectangle('Position', [columna-1, fila-1, 1, 1], ...
                    'FaceColor', rgb, ...
                    'EdgeColor', 'black', ...
                    'LineWidth', 2);

                texto = codigos_matriz{fila, columna};

                text(columna - 0.5, fila - 0.5, texto, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 12, ...
                    'Color', color_texto(rgb));

            end
        end

        hold off;

    end

end


%% ================================================================
% FUNCIÓN LOCAL: Guardar resultados
% ================================================================

function guardar_cubo_integrado(cubo, tabla_integracion, reporte_validacion, cfg)

    ruta_tabla = fullfile(cfg.cubo_integrado_dir, 'tabla_integracion_cubo.csv');
    ruta_validacion = fullfile(cfg.cubo_integrado_dir, 'reporte_validacion_cubo.csv');
    ruta_mat = fullfile(cfg.cubo_integrado_dir, 'cubo_integrado.mat');

    writetable(tabla_integracion, ruta_tabla);
    writetable(reporte_validacion, ruta_validacion);

    save(ruta_mat, 'cubo');

    fprintf('\nResultados del cubo integrado guardados en:\n');
    fprintf('%s\n', ruta_tabla);
    fprintf('%s\n', ruta_validacion);
    fprintf('%s\n', ruta_mat);

end


%% ================================================================
% FUNCIONES AUXILIARES DE COLOR Y TEXTO
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


function codigo = codigo_color(color)

    color = normalizar_nombre_color(color);

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


function texto = fila_a_texto(codigos, fila)

    texto = sprintf('[ %s %s %s ]', ...
        codigos{fila,1}, ...
        codigos{fila,2}, ...
        codigos{fila,3});

end


function rgb = rgb_color(color)

    color = normalizar_nombre_color(color);

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


function c = color_texto(rgb)

    brillo = 0.299 * rgb(1) + 0.587 * rgb(2) + 0.114 * rgb(3);

    if brillo > 0.60
        c = 'black';
    else
        c = 'white';
    end

end