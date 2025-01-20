function export_data(identifier, tseries_folders, ages, analysis_choice, pathexcel, current_animal_type, varargin)
    % Extraire le nom de l'animal type de la cellule
    animal_type = current_animal_type{1}; % Par exemple, 'FCD'

    % Charger ou créer les en-têtes nécessaires
    headers_general = {'Identifier', 'TseriesFolder', 'Age', 'RecordingTime', 'OpticalZoom','Depth(μm)', 'RecordingDuration(minutes)'};
    headers_case_3 = {'SamplingRate', 'SynchronousFrames', 'ActiveCellsNumber', 'MeanFrequencyMinutes', 'StdFrequencyMinutes', 'ActiveCellsDensity(/μm2)', 'MeanMaxPairwiseCorr'};
    headers_case_4 = {'SCEsThreshold', 'SCEsNumber', 'SCEsFrequency(Hz)', 'MeanActiveCellsSCEsNumber', 'PercentageActiveCellsSCEs', 'MeanSCEsduration(ms)'};
    all_headers = [headers_general, headers_case_3, headers_case_4];

    % Vérifier si le fichier Excel existe
    if isfile(pathexcel)
        [~, sheet_names] = xlsfinfo(pathexcel); % Liste des feuilles Excel existantes
    else
        % Si le fichier n'existe pas, initialiser une liste vide de feuilles
        sheet_names = {};
    end

    % Vérifier si la feuille correspondant à 'animal_type' existe
    if ~any(strcmp(sheet_names, animal_type))
        % Si la feuille n'existe pas, écrire les en-têtes dans une nouvelle feuille
        writecell(all_headers, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
        existing_data = [all_headers; cell(0, numel(all_headers))]; % Ajouter en-têtes
    else
        % Charger les données existantes depuis la feuille correspondante
        existing_data = readcell(pathexcel, 'Sheet', animal_type);
    end

    % Parcourir toutes les dates et âges fournis
    for m = 1:length(tseries_folders)
        try
            % Chercher une ligne correspondante (même Identifier, Date et Age)
            row_to_update = find_row_for_update(identifier, tseries_folders{m}, ages{m}, existing_data);

            % Si une ligne existe déjà, mettre à jour uniquement les colonnes nécessaires
            if row_to_update ~= -1
                switch analysis_choice
                    case 3
                        existing_data(row_to_update, 4:14) = {varargin{1}{m}, varargin{2}{m}, varargin{3}{m}, varargin{4}{m}, varargin{5}{m}, varargin{6}{m}, varargin{7}(m), varargin{8}(m), varargin{9}(m), varargin{10}(m), varargin{11}(m)};
                    case 4
                        existing_data(row_to_update, 15:20) = {varargin{1}{m}, varargin{2}(m), varargin{3}(m), varargin{4}(m), varargin{5}(m), varargin{6}(m)};
                end
            else
                % Si aucune ligne correspondante n'existe, ajouter une nouvelle ligne complète
                new_row = cell(1, numel(all_headers));
                new_row(1:3) = {identifier, tseries_folders{m}, ages{m}}; % Identifier, Date, Age
                switch analysis_choice
                    case 3
                        new_row(4:14) = {varargin{1}{m}, varargin{2}{m}, varargin{3}{m}, varargin{4}{m}, varargin{5}{m}, varargin{6}{m}, varargin{7}(m), varargin{8}(m), varargin{9}(m), varargin{10}(m), varargin{11}(m)};
                    case 4
                        new_row(15:20) = {varargin{1}{m}, varargin{2}(m), varargin{3}(m), varargin{4}(m), varargin{5}(m), varargin{6}(m)};
                end
                existing_data = [existing_data; new_row];
            end
        catch ME
            % En cas d'erreur, afficher l'erreur et continuer
            disp(['Error processing group at index ', num2str(m), ': ', ME.message]);
        end
    end

    % Nettoyer les données pour remplacer les valeurs 'missing' par une chaîne vide
    existing_data = clean_data(existing_data);

    % Écrire les données mises à jour dans la feuille correspondant à 'animal_type'
    writecell(existing_data, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
end

% Fonction pour trouver une ligne existante correspondant à Identifier, Date et Age
function row = find_row_for_update(identifier, tseries_folder, age, existing_data)
    row = -1; % Valeur par défaut si aucune ligne n'est trouvée

    % Parcourir les lignes pour Identifier, Date et Age correspondants
    for i = 2:size(existing_data, 1) % Ignorer les en-têtes
        if isequal(existing_data{i, 1}, identifier) && isequal(existing_data{i, 2}, tseries_folder) && isequal(existing_data{i, 3}, age)
            row = i;
            return;
        end
    end
end

% Fonction pour nettoyer les données en remplaçant les valeurs 'missing'
function cleaned_data = clean_data(data)
    for i = 1:size(data, 1)
        for j = 1:size(data, 2)
            if ismissing(data{i, j})
                data{i, j} = ''; % Remplacer par une chaîne vide
            end
        end
    end
    cleaned_data = data;
end
