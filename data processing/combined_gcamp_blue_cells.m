function [data, fields] = combined_gcamp_blue_cells( ...
    gcamp_output_folders, current_gcamp_folders_group, ...
    data, fields)

    numFolders = numel(gcamp_output_folders);

    %--------------------------------------------------
    % 1) Définir les champs combinés (PAR PLAN)
    %--------------------------------------------------
    fields_combined = { ...
        'F_combined_by_plane', 'DF_combined_by_plane', ...
        'blue_indices_combined_by_plane', ...
        'isort1_combined_by_plane', 'isort2_combined_by_plane', ...
        'Sm_combined_by_plane', ...
        'thresholds_combined_by_plane', 'Acttmp2_combined_by_plane', ...
        'StartEnd_combined_by_plane', 'MAct_combined_by_plane', ...
        'Raster_combined_by_plane' ...
    };

    % Compléter la liste globale "fields"
    if isempty(fields)
        fields = fields_combined;
    else
        fields = unique([fields(:); fields_combined(:)]);
    end

    % Initialiser dans data les nouveaux champs si nécessaire
    for f = 1:numel(fields_combined)
        fieldName = fields_combined{f};
        if ~isfield(data, fieldName) || numel(data.(fieldName)) ~= numFolders
            tmp = cell(numFolders, 1);
            [tmp{:}] = deal([]);
            data.(fieldName) = tmp;
        end
    end

    %--------------------------------------------------
    % 2) Boucle sur les groupes m
    %--------------------------------------------------
    for m = 1:numFolders

        filePath = fullfile(gcamp_output_folders{m}, 'results.mat');

        % Charger d'éventuelles données combinées déjà présentes
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:numel(fields_combined)
                fn = fields_combined{f};
                if isfield(loaded, fn) && isempty(data.(fn){m})
                    data.(fn){m} = loaded.(fn);
                end
            end
        end

        % On a besoin de GCaMP ET des bleus PAR PLAN
        if ~isfield(data, 'F_gcamp_by_plane') || numel(data.F_gcamp_by_plane) < m ...
           || isempty(data.F_gcamp_by_plane{m})
            fprintf('Group %d: no F_gcamp_by_plane, skipping combination.\n', m);
            continue;
        end
        if ~isfield(data, 'F_blue_by_plane') || numel(data.F_blue_by_plane) < m ...
           || isempty(data.F_blue_by_plane{m})
            fprintf('Group %d: no F_blue_by_plane, skipping combination.\n', m);
            continue;
        end

        F_gcamp_by_plane   = data.F_gcamp_by_plane{m};
        DF_gcamp_by_plane  = getFieldOrEmpty(data, 'DF_gcamp_by_plane', m);
        Raster_gcamp_by_plane    = getFieldOrEmpty(data, 'Raster_gcamp_by_plane', m);
        thresholds_gcamp_by_plane= getFieldOrEmpty(data, 'thresholds_gcamp_by_plane', m);
        Acttmp2_gcamp_by_plane   = getFieldOrEmpty(data, 'Acttmp2_gcamp_by_plane', m);
        StartEnd_gcamp_by_plane  = getFieldOrEmpty(data, 'StartEnd_gcamp_by_plane', m);
        MAct_gcamp_by_plane      = getFieldOrEmpty(data, 'MAct_gcamp_by_plane', m);

        F_blue_by_plane    = data.F_blue_by_plane{m};
        DF_blue_by_plane   = getFieldOrEmpty(data, 'DF_blue_by_plane', m);
        Raster_blue_by_plane     = getFieldOrEmpty(data, 'Raster_blue_by_plane', m);
        thresholds_blue_by_plane = getFieldOrEmpty(data, 'thresholds_blue_by_plane', m);
        Acttmp2_blue_by_plane    = getFieldOrEmpty(data, 'Acttmp2_blue_by_plane', m);
        StartEnd_blue_by_plane   = getFieldOrEmpty(data, 'StartEnd_blue_by_plane', m);
        MAct_blue_by_plane       = getFieldOrEmpty(data, 'MAct_blue_by_plane', m);

        nPlanes = numel(F_gcamp_by_plane);

        % Si déjà combiné pour ce groupe (par ex. non vide), on ne refait pas
        if ~isempty(data.F_combined_by_plane{m})
            continue;
        end

        % Pré-allouer
        data.F_combined_by_plane{m}              = cell(nPlanes,1);
        data.DF_combined_by_plane{m}             = cell(nPlanes,1);
        data.blue_indices_combined_by_plane{m}   = cell(nPlanes,1);
        data.isort1_combined_by_plane{m}         = cell(nPlanes,1);
        data.isort2_combined_by_plane{m}         = cell(nPlanes,1);
        data.Sm_combined_by_plane{m}             = cell(nPlanes,1);
        data.thresholds_combined_by_plane{m}     = cell(nPlanes,1);
        data.Acttmp2_combined_by_plane{m}        = cell(nPlanes,1);
        data.StartEnd_combined_by_plane{m}       = cell(nPlanes,1);
        data.MAct_combined_by_plane{m}           = cell(nPlanes,1);
        data.Raster_combined_by_plane{m}         = cell(nPlanes,1);

        % chemins suite2p pour ce groupe (pour raster_processing)
        if m <= numel(current_gcamp_folders_group)
            gcamp_planes_for_session_m = current_gcamp_folders_group{m};
        else
            gcamp_planes_for_session_m = {};
        end

        %--------------------------------------------------
        % 2.a) Boucle sur les plans p
        %--------------------------------------------------
        for p = 1:nPlanes

            Fg = F_gcamp_by_plane{p};
            Fb = F_blue_by_plane{p};

            % si rien sur ce plan → skip
            if isempty(Fg) && isempty(Fb)
                continue;
            end

            %-------------------------%
            % Combinaison des traces
            %-------------------------%
            if isempty(Fg)
                F_combined_p = Fb;
                n_gcamp = 0;
            elseif isempty(Fb)
                F_combined_p = Fg;
                n_gcamp = size(Fg,1);
            else
                F_combined_p = [Fg; Fb];
                n_gcamp = size(Fg,1);
            end
            n_blue = size(Fb,1);
            blue_indices_combined_p = (n_gcamp + 1) : (n_gcamp + n_blue);

            % DF
            DFg = DF_gcamp_by_plane{p};
            DFb = DF_blue_by_plane{p};
            DF_combined_p = combine_mats(DFg, DFb);

            % Raster
            Rg = Raster_gcamp_by_plane{p};
            Rb = Raster_blue_by_plane{p};
            Raster_combined_p = combine_mats(Rg, Rb);

            % thresholds
            Tg = thresholds_gcamp_by_plane{p};
            Tb = thresholds_blue_by_plane{p};
            thresholds_combined_p = combine_vecs(Tg, Tb);

            % Acttmp2
            Ag = Acttmp2_gcamp_by_plane{p};
            Ab = Acttmp2_blue_by_plane{p};
            Acttmp2_combined_p = combine_vecs(Ag, Ab);

            % StartEnd
            SG = StartEnd_gcamp_by_plane{p};
            SB = StartEnd_blue_by_plane{p};
            StartEnd_combined_p = combine_vecs(SG, SB);

            % MAct : recalculé à partir du Raster combiné
            synchronous_frames = data.synchronous_frames{m};
            if ~isempty(Raster_combined_p)
                Nz = size(Raster_combined_p, 2);
                if Nz > synchronous_frames
                    MAct_combined_p = zeros(1, Nz - synchronous_frames);
                    for i = 1:(Nz - synchronous_frames)
                        MAct_combined_p(i) = sum(max(Raster_combined_p(:, i:i+synchronous_frames), [], 2));
                    end
                else
                    MAct_combined_p = [];
                end
            else
                MAct_combined_p = [];
            end

            %-------------------------%
            % isort / raster_processing
            %-------------------------%
            isort1_combined_p = [];
            isort2_combined_p = [];
            Sm_combined_p     = [];

            if ~isempty(DF_combined_p) && ~isempty(gcamp_planes_for_session_m) ...
               && p <= numel(gcamp_planes_for_session_m) && ~isempty(gcamp_planes_for_session_m{p})

                fall_path = gcamp_planes_for_session_m{p};
                if isfolder(fall_path)
                    % charger ops pour ce plan
                    [~, ~, ~, ops, ~, ~, ~, ~] = load_data(fall_path);
                    [isort1_combined_p, isort2_combined_p, Sm_combined_p] = ...
                        raster_processing(DF_combined_p, fall_path, ops);
                end
            end

            %-------------------------%
            % Stockage par plan
            %-------------------------%
            data.F_combined_by_plane{m}{p}            = F_combined_p;
            data.DF_combined_by_plane{m}{p}           = DF_combined_p;
            data.blue_indices_combined_by_plane{m}{p} = blue_indices_combined_p(:);
            data.Raster_combined_by_plane{m}{p}       = Raster_combined_p;
            data.thresholds_combined_by_plane{m}{p}   = thresholds_combined_p;
            data.Acttmp2_combined_by_plane{m}{p}      = Acttmp2_combined_p;
            data.StartEnd_combined_by_plane{m}{p}     = StartEnd_combined_p;
            data.MAct_combined_by_plane{m}{p}         = MAct_combined_p;
            data.isort1_combined_by_plane{m}{p}       = isort1_combined_p;
            data.isort2_combined_by_plane{m}{p}       = isort2_combined_p;
            data.Sm_combined_by_plane{m}{p}           = Sm_combined_p;

        end % for p

        %--------------------------------------------------
        % 2.b) Sauvegarde dans results.mat (par groupe)
        %--------------------------------------------------
        saveStruct = struct();
        for f = 1:numel(fields_combined)
            fn = fields_combined{f};
            if isfield(data, fn)
                saveStruct.(fn) = data.(fn){m};
            end
        end

        outdir = fileparts(filePath);
        if ~exist(outdir, 'dir')
            mkdir(outdir);
        end

        if exist(filePath, 'file') == 2
            save(filePath, '-struct', 'saveStruct', '-append');
        else
            save(filePath, '-struct', 'saveStruct');
        end

    end % for m

end

function C = getFieldOrEmpty(data, fieldName, m)
    if isfield(data, fieldName) && numel(data.(fieldName)) >= m ...
            && ~isempty(data.(fieldName){m})
        C = data.(fieldName){m};
    else
        C = {};
    end
end

function M = combine_mats(A, B)
    if isempty(A)
        M = B;
    elseif isempty(B)
        M = A;
    else
        M = [A; B];
    end
end

function v = combine_vecs(a, b)
    if isempty(a)
        v = b;
    elseif isempty(b)
        v = a;
    else
        v = [a(:); b(:)];
    end
end
