function data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_root_folders, synchronous_frames_group, data)
% CONCAT TOUS LES PLANS (1 seul calcul SCE par session)
% - DF_global     = concat vertical des DF_gcamp_by_plane
% - Raster_global = concat vertical des Raster_gcamp_by_plane
% - MAct_global   = somme des MAct_gcamp_by_plane sur l'axe temps
% - Sorties: format global historique (Race_gcamp{m}, TRace_gcamp{m}, ...)

    numFolders = numel(gcamp_root_folders);

    new_fields = {'Race_gcamp', 'TRace_gcamp', 'sces_distances_gcamp', ...
                  'RasterRace_gcamp', 'sce_n_cells_threshold'};

    % Init champs si manquants
    for i = 1:numel(new_fields)
        if ~isfield(data, new_fields{i})
            data.(new_fields{i}) = cell(numFolders, 1);
            [data.(new_fields{i}){:}] = deal([]);
        elseif numel(data.(new_fields{i})) < numFolders
            data.(new_fields{i})(end+1:numFolders,1) = {[]};
        end
    end

    for m = 1:numFolders

        synchronous_frames = synchronous_frames_group{m};
        filePath = fullfile(gcamp_root_folders{m}, 'results_SCEs.mat');

        % =========================================================
        % 1) Si le fichier existe déjà : charger dans data et passer
        % =========================================================
        if exist(filePath, 'file') == 2
            disp(['Loading existing SCE file: ', filePath]);

            loaded = load(filePath);
            for f = 1:numel(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end

            % important : on ne recalcule pas
            continue;
        end

        % =========================================================
        % 2) Construire les entrées globales en concaténant les plans
        % =========================================================
        DF_global     = concat_planes_local(data, m, 'DF_gcamp_by_plane', 'numeric');
        Raster_global = concat_planes_local(data, m, 'Raster_gcamp_by_plane', 'logical');

        if isempty(DF_global) || isempty(Raster_global)
            warning('Skipping folder %s — DF/Raster global vide après concat.', gcamp_root_folders{m});
            continue;
        end

        % Sécurité alignement
        minFrames = min(size(DF_global,2), size(Raster_global,2));
        if minFrames == 0
            warning('Skipping folder %s — DF/Raster sans frames.', gcamp_root_folders{m});
            continue;
        end
        DF_global     = DF_global(:, 1:minFrames);
        Raster_global = Raster_global(:, 1:minFrames);

        Nz = size(DF_global, 2);

        % MAct : somme par plan (pas concat)
        if ~isfield(data,'MAct_gcamp_by_plane') || numel(data.MAct_gcamp_by_plane) < m || isempty(data.MAct_gcamp_by_plane{m})
            warning('Skipping folder %s — MAct_gcamp_by_plane manquant.', gcamp_root_folders{m});
            continue;
        end
        MAct_global = merge_MAct_planes(data.MAct_gcamp_by_plane{m}, Nz);

        % =========================================================
        % 3) Calcul SCE
        % =========================================================
        disp(['Processing SCEs (CONCAT ALL PLANES) for folder: ', gcamp_root_folders{m}]);

        MinPeakDistancesce = 5;
        WinActive = [];

        try
            [sce_n_cells_threshold, TRace_gcamp, Race_gcamp, sces_distances_gcamp, RasterRace_gcamp] = ...
                select_synchronies(gcamp_root_folders{m}, ...
                                   synchronous_frames, WinActive, ...
                                   DF_global, MAct_global, ...
                                   MinPeakDistancesce, Raster_global, ...
                                   current_animal_group, current_dates_group{m});

            % Stocker dans data
            data.Race_gcamp{m}            = Race_gcamp;
            data.TRace_gcamp{m}           = TRace_gcamp;
            data.sces_distances_gcamp{m}  = sces_distances_gcamp;
            data.RasterRace_gcamp{m}      = RasterRace_gcamp;
            data.sce_n_cells_threshold{m} = sce_n_cells_threshold;

            % Sauver
            save(filePath, 'sce_n_cells_threshold', 'TRace_gcamp', ...
                           'Race_gcamp', 'sces_distances_gcamp', 'RasterRace_gcamp');

            disp(['SCEs processed and saved for folder: ', gcamp_root_folders{m}]);

        catch ME
            warning(['Error processing SCEs for folder: ', gcamp_root_folders{m}]);
            warning(['Message: ', ME.message]);

            data.Race_gcamp{m}            = [];
            data.TRace_gcamp{m}           = [];
            data.sces_distances_gcamp{m}  = [];
            data.RasterRace_gcamp{m}      = [];
            data.sce_n_cells_threshold{m} = [];
        end
    end
end

% ---------------- utilities ----------------

function out = concat_planes_local(data, m, fieldName, mode)
% mode = 'numeric' ou 'logical'

    out = [];

    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        return;
    end

    planes = data.(fieldName){m};
    if ~iscell(planes)
        return;
    end

    for p = 1:numel(planes)
        X = planes{p};

        if isempty(X)
            continue;
        end

        switch lower(mode)
            case 'numeric'
                if ~(isnumeric(X) || islogical(X))
                    warning('concat_planes_local: type non supporté pour %s au plan %d (%s).', ...
                        fieldName, p, class(X));
                    continue;
                end
                X = double(X);

            case 'logical'
                if ~(islogical(X) || isnumeric(X))
                    warning('concat_planes_local: type non supporté pour %s au plan %d (%s).', ...
                        fieldName, p, class(X));
                    continue;
                end
                X = X ~= 0;

            otherwise
                error('concat_planes_local: mode inconnu "%s".', mode);
        end

        if isempty(out)
            out = X;
        else
            % aligner sur le nb minimal de frames
            minFrames = min(size(out,2), size(X,2));
            out = out(:,1:minFrames);
            X   = X(:,1:minFrames);
            out = [out; X]; %#ok<AGROW>
        end
    end
end

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