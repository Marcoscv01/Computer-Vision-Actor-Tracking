%% Configuración de lectura y Diferencia de Frames
clear; clc; close all;
videoFile = 'LopeVega.mp4';
v = VideoReader(videoFile);

numFrames = 5; 
umbralMovimiento = 25; 

frameA = readFrame(v); 
frameA_gray = rgb2gray(frameA); 

for i = 1:numFrames
    if hasFrame(v), readFrame(v); end
end

frameB = readFrame(v);
frameB_gray = rgb2gray(frameB);

diffFrame = abs(double(frameB_gray) - double(frameA_gray));
movimientoBinario = diffFrame > umbralMovimiento; 

subplot(1,2,1); imshow(frameB); title('Frame Actual');
subplot(1,2,2); imshow(movimientoBinario); title('Detección de Movimiento');

% LIMPIEZA DE RUIDO 
se = strel('disk', 2); 

%Erosion y dilatacion
movimientoLimpio = imopen(movimientoBinario, se);
%Actores compactos
movimientoLimpio = imclose(movimientoLimpio, strel('disk', 5));
% Filtro por tamaño
movimientoLimpio = bwareaopen(movimientoLimpio, 500);

figure('Name', 'Proceso de Limpieza');
subplot(1,2,1); imshow(movimientoBinario); title('Con Ruido');
subplot(1,2,2); imshow(movimientoLimpio); title('Solo Actores');

%% Segmentación por Color
% Convertir a HSV
frameHSV = rgb2hsv(frameB);
% Definir los umbrales para el color AZUL
hueMin = 0.45; 
hueMax = 0.80; 
satMin = 0.05; 
satMax = 1.00; 
brillMin = 0.05; 
brillMax = 1.00; 

% Crear la máscara de color
mascaraColor = (frameHSV(:,:,1) >= hueMin & frameHSV(:,:,1) <= hueMax) & (frameHSV(:,:,2) >= satMin & frameHSV(:,:,2) <= satMax) & (frameHSV(:,:,3) >= brillMin & frameHSV(:,:,3) <= brillMax);

% FUSIÓN: Movimiento + Color
mascaraFinal = movimientoLimpio & mascaraColor;
mascaraFinal = bwareaopen(mascaraFinal, 500); 
mascaraFinal = imclose(mascaraFinal, strel('disk', 10));

figure('Name', 'Refinamiento por Color');
subplot(1,2,1); imshow(mascaraColor); title('Máscara Azul');
subplot(1,2,2); imshow(mascaraFinal); title('Resultado Final');


%% Detección de Regiones
stats = regionprops(mascaraFinal, 'BoundingBox', 'Area');

% Lógica de selección del actor
if ~isempty(stats)
    % Si hay varias manchas, se escoge la de mayor area
    [~, indiceMaxArea] = max([stats.Area]);
    rectanguloActor = stats(indiceMaxArea).BoundingBox;

    % Visualizacion
    frameResultado = insertObjectAnnotation(frameB, 'rectangle', rectanguloActor, 'Actor Detectado','LineWidth', 3, 'Color', 'yellow', 'TextColor', 'black');


    figure('Name', 'Actor Localizado');
    imshow(frameResultado);
    title('Actor detectado mediante Movimiento + Color');
else
    disp('No se ha detectado ninguna región que cumpla los filtros.');
end

%% Definición y Visualización de la ROI 

margenDeBusqueda = 100; 
if ~isempty(stats)
    % Calcular las coordenadas de la nueva ROI
    roi_x = max(1, rectanguloActor(1) - margenDeBusqueda);
    roi_y = max(1, rectanguloActor(2) - margenDeBusqueda);
    roi_ancho = rectanguloActor(3) + 2 * margenDeBusqueda;
    roi_alto = rectanguloActor(4) + 2 * margenDeBusqueda;

    % Limites de la imagen
    roi_ancho = min(roi_ancho, size(frameB, 2) - roi_x);
    roi_alto = min(roi_alto, size(frameB, 1) - roi_y);
    roiProyectada = [roi_x, roi_y, roi_ancho, roi_alto];

    % Dibujar la ROI en ROJO
    frameConROI = insertShape(frameResultado, 'rectangle', roiProyectada,'Color', 'red', 'LineWidth', 2, 'Opacity', 0.8);
    figure('Name', 'Ventana de Búsqueda Proyectada');
    imshow(frameConROI);
    title('Amarillo: Detección Actual | Rojo: Zona de búsqueda siguiente');

else
    disp('No hay actor detectado sobre el que proyectar la ROI.');
end

%% Filtrado Mixto dentro del ROI

for i = 1:numFrames
    if hasFrame(v), frameSiguiente = readFrame(v); end
end
% RECORTAR el frame usando la ROI
frameRecortado = imcrop(frameSiguiente, roiProyectada);
frameHSV_ROI = rgb2hsv(frameRecortado);

% APLICAR FILTRO DE COLOR
maskCol_ROI = (frameHSV_ROI(:,:,1) >= hueMin & frameHSV_ROI(:,:,1) <= hueMax) &  (frameHSV_ROI(:,:,2) >= 0.10); 
% DIFERENCIA DE IMÁGENES en el recorte
frameAnterior_ROI = imcrop(frameB, roiProyectada); 
diff_ROI = abs(double(rgb2gray(frameRecortado)) - double(rgb2gray(frameAnterior_ROI)));
maskMov_ROI = diff_ROI > umbralMovimiento;
% FUSIÓN MIXTA (Color + Movimiento) 
maskFinal_ROI = maskMov_ROI & maskCol_ROI;
maskFinal_ROI = bwareaopen(maskFinal_ROI, 100); 
% Visualización
figure('Name', 'Lo que el algoritmo ve dentro del ROI');
subplot(1,2,1); imshow(frameRecortado); title('Siguiente Frame (Recortado)');
subplot(1,2,2); imshow(maskFinal_ROI); title('Filtro Mixto Local');


%% Seguimiento en bucle
v.CurrentTime = 0;
frameAnterior = readFrame(v);

roiBaseAncho = 150; 
roiBaseAlto = 100;
multiplicadorExpansion = 1.2; 
roiMaxAncho = 800; 


if exist('rectanguloActor', 'var')
   
    centroX = rectanguloActor(1) + rectanguloActor(3)/2;
    centroY = rectanguloActor(2) + rectanguloActor(4)/2;
    lastBbox = rectanguloActor;
else

    centroX = size(frameAnterior, 2) / 2;
    centroY = size(frameAnterior, 1) / 2;
    lastBbox = [];
end

currentROIWidth = roiBaseAncho;
currentROIHeight = roiBaseAlto;

hFig = figure('Name', 'Seguimiento por Expansión Controlada', 'Position', [50, 100, 1400, 450]);

outputVideo = VideoWriter('Resultado_Seguimiento.avi');
open(outputVideo);


while hasFrame(v)
    for i = 1:numFrames
        if hasFrame(v), frameActual = readFrame(v); end
    end
    

    x1 = max(1, centroX - currentROIWidth/2);
    y1 = max(1, centroY - currentROIHeight/2);
    w = min(size(frameActual, 2) - x1, currentROIWidth);
    h = min(size(frameActual, 1) - y1, currentROIHeight);
    roiSearch = [x1, y1, w, h];
    

    frameCrop = imcrop(frameActual, roiSearch);
    framePrevCrop = imcrop(frameAnterior, roiSearch);
    
    if isempty(frameCrop), continue; end 
    
    hsvCrop = rgb2hsv(frameCrop);
    maskCol = (hsvCrop(:,:,1) >= hueMin & hsvCrop(:,:,1) <= hueMax) & (hsvCrop(:,:,2) >= satMin);
    
    frameCropGray = rgb2gray(frameCrop);
    framePrevCropGray = rgb2gray(framePrevCrop);
    diff = abs(double(frameCropGray) - double(framePrevCropGray));
    maskMov = diff > umbralMovimiento;
    
    maskMix = maskMov & maskCol;
    maskMix = bwareaopen(maskMix, 150); 
    

    stats = regionprops(maskMix, 'BoundingBox', 'Area');
    
    if ~isempty(stats)
        [~, idx] = max([stats.Area]);
        bboxLocal = stats(idx).BoundingBox;
        
        lastBbox = [bboxLocal(1) + roiSearch(1), bboxLocal(2) + roiSearch(2), ...
                    bboxLocal(3), bboxLocal(4)];
        
        centroX = lastBbox(1) + lastBbox(3)/2;
        centroY = lastBbox(2) + lastBbox(4)/2;
        
        currentROIWidth = roiBaseAncho;
        currentROIHeight = roiBaseAlto;
        colorEstado = 'yellow';
    else
        currentROIWidth = min(currentROIWidth * multiplicadorExpansion, roiMaxAncho);
        currentROIHeight = min(currentROIHeight * multiplicadorExpansion, roiMaxAncho);
        colorEstado = 'red'; 
    end
    

    frameDisplay = insertShape(frameActual, 'rectangle', roiSearch, 'Color', 'cyan');
    if strcmp(colorEstado, 'yellow')
        frameDisplay = insertObjectAnnotation(frameDisplay, 'rectangle', lastBbox, 'Actor');
    end
    
    subplot(1,4,1); imshow(maskMov); title('1. Movimiento');
    subplot(1,4,2); imshow(maskCol); title('2. Color');
    subplot(1,4,3); imshow(maskMix); title('3. MIX');
    subplot(1,4,4); imshow(frameDisplay); 
    title(['Estado: ' colorEstado ' | ROI: ' num2str(round(currentROIWidth))]);
    
    drawnow;
    writeVideo(outputVideo, frameDisplay);



    frameAnterior = frameActual;
    if ~ishandle(hFig), break; end
end

close(outputVideo);
