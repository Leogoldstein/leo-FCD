function [recording_time, sampling_rate, optical_zoom, position, time_minutes, pixel_size] = find_key_value(path)
    % Fonction pour extraire les métadonnées d'un fichier XML Prairie View :
    %   - Heure d'enregistrement
    %   - Framerate (Hz)
    %   - Optical zoom
    %   - Position Z
    %   - Durée totale (en minutes)
    %   - Taille d’un pixel (µm/pixel)
    %
    % Entrée :
    %   path : chemin complet vers le fichier XML Prairie View (.xml)
    %
    % Sorties :
    %   recording_time : heure d’enregistrement (ex: "11:33:38 AM")
    %   sampling_rate  : fréquence d’échantillonnage (Hz)
    %   optical_zoom   : zoom optique appliqué
    %   position       : position Z (µm)
    %   time_minutes   : durée de la séquence en minutes
    %   pixel_size     : taille d’un pixel (µm/pixel)
    
    % Valeurs par défaut
    recording_time = '';
    sampling_rate  = NaN;
    optical_zoom   = NaN;
    position       = NaN;
    time_minutes   = NaN;
    pixel_size     = NaN;

    try
        % Lire le fichier XML
        xmlDoc = xmlread(path);

        % === Heure d'enregistrement ===
        envNode = xmlDoc.getElementsByTagName('Environment').item(0);
        if ~isempty(envNode) && envNode.hasAttribute('date')
            full_date = char(envNode.getAttribute('date')); % ex: "5/6/2024 11:33:38 AM"
            split_date = split(full_date);
            if numel(split_date) > 1
                recording_time = split_date{2};
                if numel(split_date) > 2
                    recording_time = [recording_time ' ' split_date{3}];
                end
            end
        end

        % === Extraction PVStateValue ===
        pvNodes = xmlDoc.getElementsByTagName('PVStateValue');
        for i = 0:pvNodes.getLength-1
            currentNode = pvNodes.item(i);

            % Sampling rate
            if strcmp(currentNode.getAttribute('key'), 'framerate')
                sampling_rate = str2double(char(currentNode.getAttribute('value')));
            end

            % Optical zoom
            if strcmp(currentNode.getAttribute('key'), 'opticalZoom')
                optical_zoom = str2double(char(currentNode.getAttribute('value')));
            end

            % Position (Z)
            if strcmp(currentNode.getAttribute('key'), 'positionCurrent')
                subindexedValuesNodes = currentNode.getElementsByTagName('SubindexedValues');
                for j = 0:subindexedValuesNodes.getLength-1
                    subindexedNode = subindexedValuesNodes.item(j);
                    if strcmp(subindexedNode.getAttribute('index'), 'ZAxis')
                        subindexedValueNode = subindexedNode.getElementsByTagName('SubindexedValue').item(0);
                        if ~isempty(subindexedValueNode)
                            position = str2double(char(subindexedValueNode.getAttribute('value')));
                            break;
                        end
                    end
                end
            end
        end

        % === Durée d’enregistrement ===
        segmentsNode = xmlDoc.getElementsByTagName('Segments').item(0);
        if ~isempty(segmentsNode) && segmentsNode.hasAttribute('Time')
            time = str2double(char(segmentsNode.getAttribute('Time')));
            time_minutes = time / 60;
        end

        % === Taille d’un pixel (µm/pixel) ===
        % On lit les informations de l’objectif et du champ de vue (FOV)
        objNodes = xmlDoc.getElementsByTagName('PVObjectiveLensController');
        if objNodes.getLength > 0
            objNode = objNodes.item(0);
            calibNodes = objNode.getElementsByTagName('Calibration');
            if calibNodes.getLength > 0
                calibNode = calibNodes.item(0);
                if calibNode.hasAttribute('fovWidth') && calibNode.hasAttribute('fovHeight')
                    fovWidth_um = str2double(char(calibNode.getAttribute('fovWidth')));
                    % Récupérer la taille d’image (512, 1024, etc.)
                    frameNode = xmlDoc.getElementsByTagName('FrameSize').item(0);
                    if ~isempty(frameNode)
                        width_px = str2double(char(frameNode.getAttribute('Width')));
                        % Appliquer le zoom optique si dispo
                        if isnan(optical_zoom)
                            optical_zoom = 1;
                        end
                        % FOV réel corrigé par le zoom
                        fov_real_um = fovWidth_um / optical_zoom;
                        % Taille d’un pixel
                        pixel_size = fov_real_um / width_px; % µm/pixel
                    end
                end
            end
        end

    catch ME
        fprintf('Erreur lors de la lecture du fichier : %s\n', ME.message);
    end
end
