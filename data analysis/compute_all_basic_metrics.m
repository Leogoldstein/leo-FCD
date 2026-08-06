function metrics = compute_all_basic_metrics( ...
    data, ...
    m, ...
    sampling_rate, ...
    include_blue_cells)

%COMPUTE_ALL_BASIC_METRICS
%
% Calcule les métriques d'activité intrinsèques d'un recording.
%
% Les métriques nécessitant un cache disque :
%   - correlations / coupling
%   - SCEs
%
% sont gérées à l'extérieur.


    %==============================================================%
    % Options
    %==============================================================%
    if nargin < 4 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end

    include_blue_cells = ...
        char(string(include_blue_cells));

    process_blue = ...
        strcmp(include_blue_cells, '1');


    %==============================================================%
    % Initialisation
    %==============================================================%
    metrics = struct();

    metrics.valid = false;

    metrics.gcamp_plane = struct( ...
        'activity', struct());

    metrics.blue_plane = struct( ...
        'activity', struct());


    %==============================================================%
    % GCaMP activity
    %==============================================================%
    gcamp_metrics = ...
        compute_branch_metrics_by_plane( ...
            data, ...
            'gcamp_plane', ...
            m, ...
            sampling_rate, ...
            'DF_gcamp_by_plane', ...
            'Raster_gcamp_by_plane');


    if ~gcamp_metrics.valid
        return;
    end

    metrics.valid = true;

    metrics.gcamp_plane.activity = ...
        gcamp_metrics;


    %==============================================================%
    % Blue/mTOR activity
    %==============================================================%
    if process_blue

        blue_metrics = ...
            compute_branch_metrics_by_plane( ...
                data, ...
                'blue_plane', ...
                m, ...
                sampling_rate, ...
                'DF_blue_by_plane', ...
                'Raster_blue_by_plane');

    else

        blue_metrics = ...
            empty_branch_metrics();
    end

    metrics.blue_plane.activity = ...
        blue_metrics;
end
%% Fonctions auxiliaires

function metrics = compute_branch_metrics_by_plane( ...
    data, branchName, m, sampling_rate, dfField, rasterField)

    metrics = struct( ...
        'valid', false, ...
        'nCells_by_plane', {{}}, ...
        'nFrames_by_plane', {{}}, ...
        'nValidFrames_by_plane', {{}}, ...
        'nBadFrames_by_plane', {{}}, ...
        'duration_min_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}}, ...
        'burst_rate_by_plane', {{}}, ...
        'burst_fraction_by_plane', {{}}, ...
        'burst_size_by_plane', {{}});

    has_data = ...
        has_nonempty_plane_field_nested(data, branchName, dfField, m) && ...
        has_nonempty_plane_field_nested(data, branchName, rasterField, m);

    if ~has_data
        return;
    end

    DF_planes = get_planes_nested(data, branchName, m, dfField);
    Raster_planes = get_planes_nested(data, branchName, m, rasterField);

    nPlanes = max(numel(DF_planes), numel(Raster_planes));

    metrics.nCells_by_plane = cell(1, nPlanes);
    metrics.nFrames_by_plane = cell(1, nPlanes);
    metrics.nValidFrames_by_plane = cell(1, nPlanes);
    metrics.nBadFrames_by_plane = cell(1, nPlanes);
    metrics.duration_min_by_plane = cell(1, nPlanes);
    metrics.freq_by_plane = cell(1, nPlanes);
    metrics.intervals_ms_by_plane = cell(1, nPlanes);
    metrics.burst_rate_by_plane = cell(1, nPlanes);
    metrics.burst_fraction_by_plane = cell(1, nPlanes);
    metrics.burst_size_by_plane = cell(1, nPlanes);

    for p = 1:nPlanes

        DF = [];
        Raster = [];

        if p <= numel(DF_planes)
            DF = DF_planes{p};
        end

        if p <= numel(Raster_planes)
            Raster = Raster_planes{p};
        end

        if isempty(DF) || isempty(Raster)
            continue;
        end

        [DF, Raster] = align_data(DF, Raster);

        if isempty(DF) || isempty(Raster)
            continue;
        end

        metrics.valid = true;

        nFrames = size(Raster, 2);

        bad_frame_mask = get_bad_frame_mask(data, m, nFrames);
        nBadFrames = nnz(bad_frame_mask);
        nValidFrames = nFrames - nBadFrames;

        if isfinite(sampling_rate) && sampling_rate > 0
            duration_min = nValidFrames / sampling_rate / 60;
        else
            duration_min = NaN;
        end

        metrics.nCells_by_plane{p} = size(Raster, 1);
        metrics.nFrames_by_plane{p} = nFrames;
        metrics.nBadFrames_by_plane{p} = nBadFrames;
        metrics.nValidFrames_by_plane{p} = nValidFrames;
        metrics.duration_min_by_plane{p} = duration_min;

        metrics.freq_by_plane{p} = ...
            compute_frequency_from_raster( ...
                Raster, sampling_rate, bad_frame_mask);

        metrics.intervals_ms_by_plane{p} = ...
            compute_inter_event_intervals_from_raster( ...
                Raster, ...
                sampling_rate, ...
                bad_frame_mask);

        [burst_rate, burst_fraction, burst_size] = ...
            compute_burst_metrics_from_raster( ...
                Raster, sampling_rate, bad_frame_mask);

        metrics.burst_rate_by_plane{p} = burst_rate;
        metrics.burst_fraction_by_plane{p} = burst_fraction;
        metrics.burst_size_by_plane{p} = burst_size;
    end
end

function freq_per_cell_per_min = compute_frequency_from_raster( ...
    Raster, sampling_rate, bad_frame_mask)

    if isempty(Raster) || ...
       ~isfinite(sampling_rate) || ...
       sampling_rate <= 0

        freq_per_cell_per_min = [];
        return;
    end

    Raster = Raster ~= 0;

    [nCells, nFrames] = size(Raster);

    if nargin < 3 || isempty(bad_frame_mask)

        bad_frame_mask = ...
            false(1, nFrames);

    else

        bad_frame_mask = ...
            logical(bad_frame_mask(:).');

        if numel(bad_frame_mask) < nFrames

            bad_frame_mask(end + 1:nFrames) = ...
                false;

        elseif numel(bad_frame_mask) > nFrames

            bad_frame_mask = ...
                bad_frame_mask(1:nFrames);
        end
    end

    nValidFrames = ...
        nFrames - nnz(bad_frame_mask);

    duration_min = ...
        nValidFrames / sampling_rate / 60;

    if duration_min <= 0

        freq_per_cell_per_min = ...
            nan(nCells, 1);

        return;
    end

    valid_frames = ...
        ~bad_frame_mask;

    nEvents = ...
        sum( ...
            Raster(:, valid_frames), ...
            2);

    freq_per_cell_per_min = ...
        nEvents ./ duration_min;
end

function intervals_ms = ...
    compute_inter_event_intervals_from_raster( ...
        Raster, ...
        sampling_rate, ...
        bad_frame_mask)
%COMPUTE_INTER_EVENT_INTERVALS_FROM_RASTER
%
% Calcule les intervalles inter-événements en excluant les bad frames.
%
% Important :
%   - les événements situés dans les bad frames sont ignorés ;
%   - aucun IEI n'est calculé à travers une zone de bad frames.
%
% Les IEI sont donc calculés indépendamment dans chaque segment
% temporel continu de frames valides.


    %==============================================================%
    % Initialisation
    %==============================================================%
    intervals_ms = [];


    if isempty(Raster) || ...
            ~isfinite(sampling_rate) || ...
            sampling_rate <= 0

        return;
    end


    Raster = ...
        Raster ~= 0;


    [nCells, nFrames] = ...
        size(Raster);


    %==============================================================%
    % Bad frames
    %==============================================================%
    if nargin < 3 || ...
            isempty(bad_frame_mask)

        bad_frame_mask = ...
            false(1, nFrames);

    else

        bad_frame_mask = ...
            logical( ...
                bad_frame_mask(:).');


        if numel(bad_frame_mask) < nFrames

            bad_frame_mask( ...
                end + 1:nFrames) = ...
                false;

        elseif numel(bad_frame_mask) > nFrames

            bad_frame_mask = ...
                bad_frame_mask(1:nFrames);
        end
    end


    valid_frame_mask = ...
        ~bad_frame_mask;


    %==============================================================%
    % Déterminer les segments continus de frames valides
    %==============================================================%
    valid_transition = ...
        diff( ...
            [ ...
                false, ...
                valid_frame_mask, ...
                false ...
            ]);


    segment_starts = ...
        find(valid_transition == 1);

    segment_ends = ...
        find(valid_transition == -1) - 1;


    %==============================================================%
    % Boucle cellules
    %==============================================================%
    for c = 1:nCells


        %----------------------------------------------------------%
        % Chaque segment valide est traité indépendamment
        %----------------------------------------------------------%
        for s = 1:numel(segment_starts)

            first_frame = ...
                segment_starts(s);

            last_frame = ...
                segment_ends(s);


            event_frames = ...
                find( ...
                    Raster( ...
                        c, ...
                        first_frame:last_frame));


            if numel(event_frames) < 2
                continue;
            end


            % Revenir aux indices du recording complet
            event_frames = ...
                event_frames + ...
                first_frame - 1;


            cell_intervals = ...
                diff(event_frames) ./ ...
                sampling_rate .* ...
                1000;


            intervals_ms = ...
                [ ...
                    intervals_ms; ...
                    cell_intervals(:) ...
                ]; %#ok<AGROW>
        end
    end


    %==============================================================%
    % Nettoyage
    %==============================================================%
    intervals_ms = ...
        intervals_ms( ...
            isfinite(intervals_ms));
end

function [ ...
    burst_rate_per_cell_per_min, ...
    burst_fraction_per_cell, ...
    burst_size_all] = ...
    compute_burst_metrics_from_raster( ...
        Raster, ...
        sampling_rate, ...
        bad_frame_mask)
%COMPUTE_BURST_METRICS_FROM_RASTER
%
% Calcule :
%   - burst rate par cellule ;
%   - fraction des événements appartenant à des bursts ;
%   - taille des bursts.
%
% Gestion des bad frames :
%   - les événements dans les bad frames sont exclus ;
%   - un burst ne peut jamais traverser une zone de bad frames ;
%   - la durée utilisée pour le burst rate correspond uniquement
%     aux frames valides.


    %==============================================================%
    % Initialisation
    %==============================================================%
    burst_rate_per_cell_per_min = [];
    burst_fraction_per_cell = [];
    burst_size_all = [];


    if isempty(Raster) || ...
            ~isfinite(sampling_rate) || ...
            sampling_rate <= 0

        return;
    end


    Raster = ...
        Raster ~= 0;


    %==============================================================%
    % Paramètres bursts
    %==============================================================%
    max_iei_ms = ...
        1000;

    min_events_per_burst = ...
        3;


    max_iei_frames = ...
        max( ...
            1, ...
            round( ...
                (max_iei_ms / 1000) * ...
                sampling_rate));


    [nCells, nFrames] = ...
        size(Raster);


    %==============================================================%
    % Bad frames
    %==============================================================%
    if nargin < 3 || ...
            isempty(bad_frame_mask)

        bad_frame_mask = ...
            false(1, nFrames);

    else

        bad_frame_mask = ...
            logical( ...
                bad_frame_mask(:).');


        if numel(bad_frame_mask) < nFrames

            bad_frame_mask( ...
                end + 1:nFrames) = ...
                false;

        elseif numel(bad_frame_mask) > nFrames

            bad_frame_mask = ...
                bad_frame_mask(1:nFrames);
        end
    end


    valid_frame_mask = ...
        ~bad_frame_mask;


    %==============================================================%
    % Durée utile
    %==============================================================%
    nValidFrames = ...
        nnz(valid_frame_mask);


    duration_min = ...
        nValidFrames / ...
        sampling_rate / ...
        60;


    burst_rate_per_cell_per_min = ...
        nan(nCells, 1);

    burst_fraction_per_cell = ...
        nan(nCells, 1);


    if duration_min <= 0
        return;
    end


    %==============================================================%
    % Segments temporels valides
    %==============================================================%
    valid_transition = ...
        diff( ...
            [ ...
                false, ...
                valid_frame_mask, ...
                false ...
            ]);


    segment_starts = ...
        find(valid_transition == 1);

    segment_ends = ...
        find(valid_transition == -1) - 1;


    %==============================================================%
    % Boucle cellules
    %==============================================================%
    for c = 1:nCells

        all_burst_sizes = [];

        n_valid_events = 0;


        %==========================================================%
        % Chaque segment valide est indépendant
        %==========================================================%
        for s = 1:numel(segment_starts)

            first_frame = ...
                segment_starts(s);

            last_frame = ...
                segment_ends(s);


            event_frames = ...
                find( ...
                    Raster( ...
                        c, ...
                        first_frame:last_frame));


            n_valid_events = ...
                n_valid_events + ...
                numel(event_frames);


            if numel(event_frames) < ...
                    min_events_per_burst

                continue;
            end


            %------------------------------------------------------%
            % Différences entre événements du même segment valide
            %------------------------------------------------------%
            d = ...
                diff(event_frames);


            current_size = ...
                1;


            for i = 1:numel(d)

                if d(i) <= ...
                        max_iei_frames

                    current_size = ...
                        current_size + 1;

                else

                    if current_size >= ...
                            min_events_per_burst

                        all_burst_sizes( ...
                            end + 1, ...
                            1) = ...
                            current_size; %#ok<AGROW>
                    end


                    current_size = ...
                        1;
                end
            end


            %------------------------------------------------------%
            % Dernier burst potentiel du segment
            %------------------------------------------------------%
            if current_size >= ...
                    min_events_per_burst

                all_burst_sizes( ...
                    end + 1, ...
                    1) = ...
                    current_size; %#ok<AGROW>
            end
        end


        %==========================================================%
        % Nombre de bursts
        %==========================================================%
        nBursts = ...
            numel(all_burst_sizes);


        burst_rate_per_cell_per_min(c) = ...
            nBursts / ...
            duration_min;


        %==========================================================%
        % Fraction des événements inclus dans des bursts
        %==========================================================%
        if n_valid_events > 0

            burst_fraction_per_cell(c) = ...
                sum(all_burst_sizes) / ...
                n_valid_events;

        else

            burst_fraction_per_cell(c) = ...
                NaN;
        end


        %==========================================================%
        % Tailles de tous les bursts
        %==========================================================%
        burst_size_all = ...
            [ ...
                burst_size_all; ...
                all_burst_sizes(:) ...
            ]; %#ok<AGROW>
    end


    %==============================================================%
    % Nettoyage
    %==============================================================%
    burst_size_all = ...
        burst_size_all( ...
            isfinite(burst_size_all));
end

function metrics = empty_branch_metrics()

    metrics = struct( ...
        'valid', false, ...
        'nCells_by_plane', {{}}, ...
        'nFrames_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}}, ...
        'burst_rate_by_plane', {{}}, ...
        'burst_fraction_by_plane', {{}}, ...
        'burst_size_by_plane', {{}});
end

function [DF, Raster] = align_data(DF, Raster)

    min_cells = min(size(DF, 1), size(Raster, 1));
    min_frames = min(size(DF, 2), size(Raster, 2));

    DF = DF(1:min_cells, 1:min_frames);
    Raster = Raster(1:min_cells, 1:min_frames);
end


function planes = get_planes_nested(data, branchName, m, fieldName)

    planes = {};

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        planes = {planes};
    end
end

function tf = has_nonempty_plane_field_nested(data, branchName, fieldName, m)

    tf = false;

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName)
        return;
    end

    if numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        tf = ~isempty(planes);
        return;
    end

    for p = 1:numel(planes)
        if ~isempty(planes{p})
            tf = true;
            return;
        end
    end
end


function bad_frame_mask = get_bad_frame_mask(data, m, nFrames)
%GET_BAD_FRAME_MASK
% Retourne un masque logique 1 x nFrames.
%
% Formats acceptés dans data.motion.bad_frames_group{m} :
%   - masque logique ;
%   - vecteur numérique de 0 et 1 ;
%   - liste d'indices de frames ;
%   - cellule contenant un ou plusieurs de ces formats.

    bad_frame_mask = false(1, nFrames);

    if nargin < 3 || isempty(nFrames) || nFrames <= 0
        return;
    end

    if ~isstruct(data) || ...
       ~isfield(data, 'motion') || ...
       ~isstruct(data.motion) || ...
       ~isfield(data.motion, 'bad_frames_group') || ...
       isempty(data.motion.bad_frames_group) || ...
       numel(data.motion.bad_frames_group) < m

        return;
    end

    bad_frames = data.motion.bad_frames_group{m};

    if isempty(bad_frames)
        return;
    end

    bad_frame_mask = convert_bad_frames_to_mask( ...
        bad_frames, nFrames);
end

function bad_frame_mask = convert_bad_frames_to_mask( ...
    bad_frames, nFrames)

    bad_frame_mask = false(1, nFrames);

    if isempty(bad_frames)
        return;
    end

    if iscell(bad_frames)

        for i = 1:numel(bad_frames)
            current_mask = convert_bad_frames_to_mask( ...
                bad_frames{i}, nFrames);

            bad_frame_mask = ...
                bad_frame_mask | current_mask;
        end

        return;
    end

    if islogical(bad_frames)

        bad_frames = bad_frames(:).';

        nCopy = min(numel(bad_frames), nFrames);

        bad_frame_mask(1:nCopy) = ...
            bad_frames(1:nCopy);

        return;
    end

    if ~isnumeric(bad_frames)
        return;
    end

    bad_frames = double(bad_frames(:).');
    bad_frames = bad_frames(isfinite(bad_frames));

    if isempty(bad_frames)
        return;
    end

    % Un vecteur de même longueur constitué uniquement de 0 et 1
    % est interprété comme un masque.
    is_binary_mask = ...
        numel(bad_frames) == nFrames && ...
        all(bad_frames == 0 | bad_frames == 1);

    if is_binary_mask
        bad_frame_mask = logical(bad_frames);
        return;
    end

    % Sinon, les valeurs sont interprétées comme des indices MATLAB.
    bad_indices = unique(round(bad_frames));
    bad_indices = bad_indices( ...
        bad_indices >= 1 & ...
        bad_indices <= nFrames);

    bad_frame_mask(bad_indices) = true;
end




