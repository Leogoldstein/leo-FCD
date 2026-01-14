function data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data)
% CONCAT TOUS LES PLANS (1 seul calcul SCE par session) en utilisant concat_planes(data,m,fieldName)
% - DF_global     = concat_planes(data,m,'DF_gcamp_by_plane')       (concat vertical cellules)
% - Raster_global = concat_planes(data,m,'Raster_gcamp_by_plane')   (concat vertical cellules)
% - MAct_global   = SOMME des MAct_by_plane{m}{p} sur l'axe temps (pas concat)
% - Sorties: format global historique (Race_gcamp{m}, TRace_gcamp{m}, ...)

    numFolders = numel(gcamp_output_folders);

    new_fields = {'Race_gcamp', 'TRace_gcamp', 'sces_distances_gcamp', ...
                  'RasterRace_gcamp', 'sce_n_cells_threshold'};

    % Init champs si manquants
    for i = 1:numel(new_fields)
        if ~isfield(data, new_fields{i})
            data.(new_fields{i}) = cell(numFolders, 1);
            [data.(new_fields{i}){:}] = deal([]);
        end
    end

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');

        % 1) Charger si existe
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            loaded = load(filePath);
            for f = 1:numel(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end
        end

        % Déjà calculé ?
        if ~isempty(data.Race_gcamp{m})
            continue;
        end

        % 2) Construire les entrées globales en concaténant les plans
        DF_global     = concat_planes(data, m, 'DF_gcamp_by_plane');
        Raster_global = concat_planes(data, m, 'Raster_gcamp_by_plane');

        if isempty(DF_global) || isempty(Raster_global)
            warning('Skipping folder %s — DF/Raster global vide après concat_planes.', gcamp_output_folders{m});
            continue;
        end

        Nz = size(DF_global, 2);

        % MAct : somme par plan (pas concat)
        if ~isfield(data,'MAct_gcamp_by_plane') || numel(data.MAct_gcamp_by_plane) < m || isempty(data.MAct_gcamp_by_plane{m})
            warning('Skipping folder %s — MAct_gcamp_by_plane manquant.', gcamp_output_folders{m});
            continue;
        end
        MAct_global = merge_MAct_planes(data.MAct_gcamp_by_plane{m}, Nz);

        % synchronous_frames : global (comme avant)
        if ~isfield(data,'synchronous_frames') || numel(data.synchronous_frames) < m || isempty(data.synchronous_frames{m})
            warning('Skipping folder %s — synchronous_frames manquant.', gcamp_output_folders{m});
            continue;
        end
        synchronous_frames = data.synchronous_frames{m};

        % 3) Calcul SCE (1 seul appel)
        disp(['Processing SCEs (CONCAT ALL PLANES) for folder: ', gcamp_output_folders{m}]);

        MinPeakDistancesce = 5;
        WinActive = [];

        try
            [sce_n_cells_threshold, TRace_gcamp, Race_gcamp, sces_distances_gcamp, RasterRace_gcamp] = ...
                select_synchronies(gcamp_output_folders{m}, ...
                                   synchronous_frames, WinActive, ...
                                   DF_global, MAct_global, ...
                                   MinPeakDistancesce, Raster_global, ...
                                   current_animal_group, current_dates_group{m});

            % Stocker
            data.Race_gcamp{m} = Race_gcamp;
            data.TRace_gcamp{m} = TRace_gcamp;
            data.sces_distances_gcamp{m} = sces_distances_gcamp;
            data.RasterRace_gcamp{m} = RasterRace_gcamp;
            data.sce_n_cells_threshold{m} = sce_n_cells_threshold;

            % Sauver (global uniquement)
            save(filePath, 'sce_n_cells_threshold', 'TRace_gcamp', ...
                           'Race_gcamp', 'sces_distances_gcamp', 'RasterRace_gcamp');

            disp(['SCEs processed and saved for folder: ', gcamp_output_folders{m}]);

        catch ME
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

% ---------------- utilities ----------------

function MAct_sum = merge_MAct_planes(MAct_cell, Nz)
    % SOMME des MAct_by_plane{m}{p} sur le même axe temps (crop/pad à Nz)
    MAct_sum = zeros(1, Nz);

    if isempty(MAct_cell)
        return;
    end

    for p = 1:numel(MAct_cell)
        M = MAct_cell{p};
        if isempty(M)
            continue;
        end
        M = resize_MAct(M, Nz);
        MAct_sum = MAct_sum + M;
    end
end

function MAct_out = resize_MAct(MAct_in, Nz)
    if isempty(MAct_in)
        MAct_out = zeros(1, Nz);
        return;
    end
    MAct_in = MAct_in(:)'; % row
    if numel(MAct_in) > Nz
        MAct_out = MAct_in(1:Nz);
    elseif numel(MAct_in) < Nz
        MAct_out = [MAct_in, zeros(1, Nz - numel(MAct_in))];
    else
        MAct_out = MAct_in;
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end
