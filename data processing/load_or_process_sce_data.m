function data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups

    % Ajouter dynamiquement les nouveaux champs à gcamp_fields
    new_fields = {'Race_gcamp', 'TRace_gcamp', 'sces_distances_gcamp', 'RasterRace_gcamp', 'sce_n_cells_threshold'};

    % Vérifier et ajouter les nouveaux champs dans data
    for i = 1:length(new_fields)
        if ~isfield(data, new_fields{i})
            data.(new_fields{i}) = cell(numFolders, 1);  % Créer les nouveaux champs s'ils n'existent pas
            [data.(new_fields{i}){:}] = deal([]);  % Initialiser chaque cellule à []
        end
    end

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');
        
         % Option : supprimer un champs pour le recharger
        removeFieldsByIndex(filePath, new_fields, 1:5);

        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            loaded = load(filePath);
            for f = 1:length(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end
        end

        % If processing is needed, handle it outside the loop
        if isempty(data.Race_gcamp{m})
            disp('Processing SCEs...');
    
            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            [sce_n_cells_threshold, TRace_gcamp, Race_gcamp, sces_distances_gcamp, RasterRace_gcamp] = ...
                select_synchronies(gcamp_output_folders{m}, data.synchronous_frames{m}, WinActive, data.DF_gcamp{m}, data.MAct_gcamp{m}, MinPeakDistancesce, data.Raster_gcamp{m}, current_animal_group, current_dates_group{m});
            
            data.Race_gcamp{m} = Race_gcamp;
            data.TRace_gcamp{m} = TRace_gcamp;
            data.sces_distances_gcamp{m} = sces_distances_gcamp;
            data.RasterRace_gcamp{m} = RasterRace_gcamp;
            data.sce_n_cells_threshold{m} = sce_n_cells_threshold;

            save(filePath, 'sce_n_cells_threshold', 'TRace_gcamp', 'Race_gcamp', 'sces_distances_gcamp', 'RasterRace_gcamp');
        end
    end
end


function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end

function removeFieldsByIndex(filePath, fields, indicesToRemove)
    % Vérifie si le fichier existe
    if exist(filePath, 'file') ~= 2
        error('Le fichier %s n''existe pas.', filePath);
    end

    % Charger les données
    loaded = load(filePath);

    % Vérifier que les indices sont valides
    if any(indicesToRemove < 1) || any(indicesToRemove > numel(fields))
        error('Indices invalides. Ils doivent être compris entre 1 et %d.', numel(fields));
    end

    % Boucle sur les indices
    for i = 1:numel(indicesToRemove)
        fieldName = fields{indicesToRemove(i)};
        if isfield(loaded, fieldName)
            loaded = rmfield(loaded, fieldName);
            fprintf('Champ "%s" supprimé.\n', fieldName);
        else
            warning('Champ "%s" absent du fichier.\n', fieldName);
        end
    end

    % Sauvegarder les données mises à jour
    save(filePath, '-struct', 'loaded');
    fprintf('Mise à jour terminée.\n');
end
