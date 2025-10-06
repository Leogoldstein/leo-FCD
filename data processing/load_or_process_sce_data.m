function data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups

    % Ajouter dynamiquement les nouveaux champs à gcamp_fields
    new_fields = {'Race_gcamp', 'TRace_gcamp', 'sces_distances_gcamp', ...
                  'RasterRace_gcamp', 'sce_n_cells_threshold'};

    % Vérifier et ajouter les nouveaux champs dans data
    for i = 1:length(new_fields)
        if ~isfield(data, new_fields{i})
            data.(new_fields{i}) = cell(numFolders, 1);  % Créer les nouveaux champs s'ils n'existent pas
            [data.(new_fields{i}){:}] = deal([]);        % Initialiser chaque cellule à []
        end
    end

    % === Boucle principale sur les dossiers ===
    for m = 1:numFolders
        % Chemin complet du fichier .mat contenant les résultats
        filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');
        
        % Si un fichier existe déjà → charger
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            loaded = load(filePath);
            for f = 1:length(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end
        end
                  
        % Si pas encore traité → recalculer les SCEs
        if isempty(data.Race_gcamp{m})
            disp(['Processing SCEs for folder: ', gcamp_output_folders{m}]);

            MinPeakDistancesce = 3;
            WinActive = [];  % Placeholder, peut être remplacé par un masque d'activité
            try
                % Vérifier que les champs requis existent et ne sont pas vides
                if isempty(data.MAct_gcamp{m}) || isempty(data.DF_gcamp{m}) || isempty(data.Raster_gcamp{m})
                    warning('Skipping folder %s — Missing MAct, DF, or Raster data.', gcamp_output_folders{m});
                    continue;
                end

                % --- Appel à select_synchronies ---
                [sce_n_cells_threshold, sce_ratio_threshold, TRace_gcamp, ...
                 Race_gcamp, sces_distances_gcamp, RasterRace_gcamp] = ...
                    select_synchronies(gcamp_output_folders{m}, ...
                                       data.synchronous_frames{m}, WinActive, ...
                                       data.DF_gcamp{m}, data.MAct_gcamp{m}, ...
                                       MinPeakDistancesce, data.Raster_gcamp{m}, ...
                                       current_animal_group, current_dates_group{m});

                % --- Sauvegarde des résultats ---
                data.Race_gcamp{m} = Race_gcamp;
                data.TRace_gcamp{m} = TRace_gcamp;
                data.sces_distances_gcamp{m} = sces_distances_gcamp;
                data.RasterRace_gcamp{m} = RasterRace_gcamp;
                data.sce_n_cells_threshold{m} = sce_n_cells_threshold;

                save(filePath, 'sce_n_cells_threshold', 'TRace_gcamp', ...
                               'Race_gcamp', 'sces_distances_gcamp', 'RasterRace_gcamp');
                disp(['SCEs processed and saved for folder: ', gcamp_output_folders{m}]);

            catch ME
                % Gestion d’erreurs locale
                warning(['Error processing SCEs for folder: ', gcamp_output_folders{m}]);
                warning(['Message: ', ME.message]);
                data.Race_gcamp{m} = [];
                data.TRace_gcamp{m} = [];
                data.sces_distances_gcamp{m} = [];
                data.RasterRace_gcamp{m} = [];
                data.sce_n_cells_threshold{m} = [];
            end
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